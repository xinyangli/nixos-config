---
name: agent-pam-ssh
description: SSH to repo-managed hosts as agent_pam_access with a short-lived Kanidm API token and browserless opkssh. Use when an agent needs agent_pam_access access to agate or another configured host.
---

# agent-pam-ssh

Use the bundled script rather than manually driving Kanidm or opkssh. It reuses valid cached credentials and never opens a browser or prints API tokens.

## Prerequisites

- `kanidm`, `opkssh`, `python3`, and `ssh` are available.
- `xin` is an entry manager for `agent_pam_access`.
- The target deploys the `services.opkssh.authorizations` entry from `modules/nixos/common-settings/auth.nix`.

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

## Credential lifecycle

- The script uses xin's existing Kanidm CLI session to issue a **readonly** API token for `agent_pam_access`, valid for **6 hours**.
- It obtains the opkssh certificate entirely through HTTP APIs: local PKCE start, `/oauth2/authorise`, `/oauth2/authorise/permit` when consent is required, then the local callback.
- It execs `ssh` as `agent_pam_access@<host>` with `IdentitiesOnly=yes`.
- Valid certificates are reused first. The API token is only refreshed when a new certificate is needed and the cached token is missing, invalid, or near expiry.
- A cache lock serializes credential refresh so concurrent agents cannot mix different private-key/certificate generations.

Sensitive files live under `.cache/agent-pam-ssh/` in the repo. The directory is `0700`, token/private-key files are `0600`, and the directory is excluded by the root `.gitignore`. Never commit, print, or copy these files into chat or artifacts.

## Authorization invariants

The server-side opkssh policy must use:

- the full Kanidm SPN `agent_pam_access@auth.xiny.li` as the user, because Kanidm presents that name to sshd;
- the bare UUID as `principal`, without a `sub:` prefix.

If SSH returns `Permission denied (publickey)`, check the deployed `/etc/opk/auth_id` and `/var/log/opkssh.log` on the target. Do not weaken sshd authentication or enable password login as a workaround.
