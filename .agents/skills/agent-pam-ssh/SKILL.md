---
name: agent-pam-ssh
description: Diagnose problems on NixOS machines. SSH as agent_pam_access with short-lived Kanidm credentials, escalate to root via TOTP, and read metrics/logs from Grafana by completing Grafana's own OIDC login as agent_pam_access. Use when an agent needs to inspect, debug, or monitor agate or another configured host.
---

# agent-pam-ssh

Diagnostic access to repo-managed hosts. Three channels, all authenticated as the Kanidm account `agent_pam_access`:

1. **SSH** (`scripts/ssh.py`) — run commands as `agent_pam_access` via opkssh certificates.
2. **Root** (`scripts/root-run.sh`) — sudo with a TOTP code fetched from rbw.
3. **Grafana** (`scripts/grafana.py`) — query Prometheus metrics and Loki logs through Grafana, no SSH needed.

Use the bundled scripts rather than manually driving Kanidm, opkssh, or Grafana. They reuse valid cached credentials and never open a browser or print API tokens.

## Prerequisites

- `kanidm`, `opkssh`, `python3` (with `requests`, `grafana-client` from the repo devShell), `ssh`, and `rbw` are available.
- `xin` is an entry manager for `agent_pam_access`.
- Targets deploy the `services.opkssh.authorizations` entry from `modules/nixos/common-settings/auth.nix`.
- Grafana access requires `agent_pam_access` in the `grafana-users` and `grafana-editors` Kanidm groups (`machines/biotite/services/kanidm-provision.nix`), and Grafana at `https://grafana.xiny.li` with OAuth2 client `grafana`.

If xin's Kanidm session has expired, ask the user to run:

```sh
kanidm login -D xin
```

If the session is valid but its privileges have expired (`kanidm session list` shows `purpose: read write (expiry: none)`), ask the user to reauthenticate instead:

```sh
kanidm reauth -D xin
```

Do not ask for the account password or an API token in chat.

## SSH

Run a remote command on agate:

```sh
python3 .agents/skills/agent-pam-ssh/scripts/ssh.py agate 'id -un; hostname'
```

Use another configured short hostname or an FQDN when needed:

```sh
python3 .agents/skills/agent-pam-ssh/scripts/ssh.py biotite 'hostname'
```

Omit the remote command for an interactive SSH session:

```sh
python3 .agents/skills/agent-pam-ssh/scripts/ssh.py agate
```

## Acquiring root permission

Root/sudo is gated by TOTP (OATH). Direct `ssh root@…` is not authorized — log in as your SSO user, then `sudo`. The prompt comes via polkit on the SSH TTY (`One-time password (OATH) for 'xin@auth.xiny.li':`). Use the helper, which fetches a fresh code from rbw and answers the prompt:

```sh
./scripts/root-run.sh <host> [cmd...]   # default cmd: whoami
```

## Grafana: metrics and logs

Grafana is the OIDC client, so the agent never sees the client secret: `grafana.py` follows Grafana's own login redirect, authenticates to Kanidm with the `agent_pam_access` API token, answers the consent prompt, and lets Grafana finish the code exchange. The resulting `grafana_session` cookie is cached in `.cache/agent-pam-ssh/` and reused until it expires.

```sh
# who the session is, and with what org
python3 .agents/skills/agent-pam-ssh/scripts/grafana.py user

# list datasources (uid, type, name)
python3 .agents/skills/agent-pam-ssh/scripts/grafana.py datasources

# instant PromQL query against a Prometheus datasource uid
python3 .agents/skills/agent-pam-ssh/scripts/grafana.py query <uid> 'up{instance=~"agate.*"}'

# LogQL query against a Loki datasource uid (last 15 minutes)
python3 .agents/skills/agent-pam-ssh/scripts/grafana.py logs <uid> '{unit="comin.service"}' --limit 20
```

Queries go through Grafana's datasource proxy, so datasource credentials stay server-side. Use `--refresh` to re-login when the cached session is rejected.

Typical diagnosis loop: `grafana.py logs` to find the failing unit/message, `ssh.py` to inspect the unit and recent journal, `root-run.sh` when root is required.

## Credential lifecycle

- The scripts use xin's existing Kanidm CLI session to issue a **readonly** API token for `agent_pam_access`, valid for **6 hours**.
- `ssh.py` obtains the opkssh certificate entirely through HTTP APIs: local PKCE start, `/oauth2/authorise`, `/oauth2/authorise/permit` when consent is required, then the local callback.
- `ssh.py` execs `ssh` as `agent_pam_access@<host>` with `IdentitiesOnly=yes`.
- Valid certificates and Grafana sessions are reused first. The API token is only refreshed when a new credential is needed and the cached token is missing, invalid, or near expiry.
- A cache lock serializes credential refresh so concurrent agents cannot mix different private-key/certificate generations.

Sensitive files live under `.cache/agent-pam-ssh/` in the repo. The directory is `0700`, token/private-key/cookie files are `0600`, and the directory is excluded by the root `.gitignore`. Never commit, print, or copy these files into chat or artifacts.

## Authorization invariants

The server-side opkssh policy must use:

- the full Kanidm SPN `agent_pam_access@auth.xiny.li` as the user, because Kanidm presents that name to sshd;
- the bare UUID as `principal`, without a `sub:` prefix.

For Grafana, Kanidm grants the `grafana` client's scopes only via the `grafana-users` group; membership in `grafana-editors` alone yields HTTP 403 (`AccessDenied`) at `/oauth2/authorise`. If SSH returns `Permission denied (publickey)`, check the deployed `/etc/opk/auth_id` and `/var/log/opkssh.log` on the target. Do not weaken sshd authentication or enable password login as a workaround.
