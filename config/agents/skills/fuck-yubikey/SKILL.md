---
name: fuck-yubikey
description: Reduce YubiKey touch frequency on Canva Linux devboxes. Diagnoses where touches come from (tsh/kubectl, Python kubernetes clients like utp, AWS prod profile) and applies workarounds. Use when the user says "yubikey 触发太频繁", "kubectl 每次要 touch", "aws cli 一直要 mfa", "infra auth aws 一直 yubikey", "less yubikey touches", "reduce mfa prompts", "fuck yubikey", "/fuck-yubikey", or similar. Linux devbox only — macOS has separate flow that is generally fine.
---

# Reduce YubiKey touches on Canva Linux devbox

Background: Per Canva internal design "Less Yubikey Touches Same Security" (DAGjo2hYw2E, 2025-04-15), MFA caching is enabled for most workflows, BUT Linux devboxes do **not** yet have device identities, so AWS credential negotiation on devbox still prompts every time. kubectl via Teleport similarly hits MFA on every session unless mediated. The workarounds below address each of the three common touch sources.

## Step 0 — Diagnose which touches the user is suffering

Ask the user (or detect from recent shell history) what triggers touches. Map to one of:

1. **`kubectl …`** prompts every time → Teleport per-session MFA. See **Section A**.
2. **`utp …`, `python` scripts using `kubernetes` lib** → Python client ignores kubeconfig `proxy-url`. See **Section B**.
3. **`aws --profile prod …`, S3 downloads, boto3 in scripts** → devbox AWS credential negotiation. See **Section C**.
4. **roo / `infra` commands** → check roo daemon socket; see **Section D**.

User may have more than one. Verify before remediating.

Cheap diagnostics (no touches required):

```bash
# kube: is teleport profile loaded?
tsh status

# does devbox already have a kube proxy systemd service running?
systemctl --user is-active tsh-kube-proxy 2>/dev/null

# AWS prod credential_process current binding
grep -A2 '^\[prod\]' ~/.aws/credentials

# roo daemon reachable
roo daemon info 2>&1 | head -5
```

---

## Section A — Kubectl zero-touch via persistent tsh proxy + PIV agent

**Mechanism**: `tsh proxy kube` listens on `127.0.0.1:8443` with a long-lived kube cert. `tsh piv agent` caches the PIN/MFA so one touch covers the full cert lifetime (~6h-12h depending on role TTL). A systemd user service keeps both alive.

### Constraints to remember
- tsh on Canva devbox is currently v17.x. There is **no** `--piv-pin-cache-ttl` flag on `tsh login` — PIN caching must go through `tsh piv agent` (Canva-flavored subcommand).
- `tsh proxy kube --exec` only reexecs `$SHELL`, you cannot pass `-- bash -c '...'`. Don't try.
- `tsh proxy kube` has no `--kubeconfig` flag. The generated kubeconfig path appears in stdout as `export KUBECONFIG="…"` — parse with regex that strips quotes.
- Inside a systemd service there is no TTY. **Never** call `tsh login` from the service; it will deadlock on the PIN prompt. The service must `exit` if `tsh status` is not logged in and let the user `tsh login` manually + `systemctl --user restart …`.

### Implement
Build two files and one bashrc entry. Confirm with the user before writing — they may already have a working setup.

1. `~/.local/bin/tsh-kube-proxy.sh` — bash script that:
   - exits 1 if `tsh status` fails
   - starts `tsh piv agent` (skip if `/tmp/.Teleport-PIV/agent.sock` already alive)
   - starts `tsh proxy kube --port=$PORT $CLUSTER` in background, captures stdout to a log file
   - polls the log for `KUBECONFIG="…"`, grep/sed strips quotes, gets the path
   - patches the generated kubeconfig to include `namespace: $DEFAULT_NS` under the context (otherwise tools like `utp pool` default to `default` namespace and return empty)
   - `ln -sfn` the generated kubeconfig to a stable path (`~/.kube/tsh-proxy.yaml`)
   - loops monitoring both children; exits 1 if either dies so systemd backs off

2. `~/.config/systemd/user/tsh-kube-proxy.service` — Type=simple, Restart=on-failure, RestartSec=30, with StartLimit so a permanent failure (e.g. logged out) doesn't spin.

3. Bashrc additions:
   ```bash
   # MERGE form, not overwrite. arnold (canva-arnold CLI) looks for a kube context
   # whose name == its app cluster (e.g. "general-aws-use1-prod-0"). The tsh-proxy
   # kubeconfig's context name is "live.teleport.p.canva-cloud.com-<cluster>" and
   # never matches arnold's expectation, so a single-file KUBECONFIG pointing only
   # at tsh-proxy.yaml makes arnold fall through to `infra kube login`, which then
   # fails parsing tsh stderr with: "unable to find http proxy url in stderr" →
   # `LoginError: Failed to login to Kubernetes cluster.` (canva-arnold
   # jobsets/kube.py:140). Merging keeps the stock context name available for
   # arnold while letting kubectl still use the proxy.
   export KUBECONFIG=$HOME/.kube/config:$HOME/.kube/tsh-proxy.yaml
   alias kube-refresh='tsh login --proxy=<PROXY> && systemctl --user restart tsh-kube-proxy'
   ```

Per-user values to ask before generating:
- `PROXY` (e.g. `live.teleport.p.canva-cloud.com`)
- `CLUSTER` (e.g. `general-aws-use1-prod-0`)
- `DEFAULT_NS` (e.g. `b-core-cn-prod`)
- `PORT` (default 8443, change if conflict)

### Rollout
```bash
tsh login --proxy=<PROXY>      # one touch + PIN, only time PIN is typed today
systemctl --user daemon-reload
systemctl --user enable --now tsh-kube-proxy.service
```
Then the user touches the YubiKey once when `tsh proxy kube` first runs (cert issuance). After that, all kubectl is zero-touch until the kube cert expires (~6h). On expiry the service exits; user re-runs `kube-refresh`.

### Validation
```bash
ls -la ~/.kube/tsh-proxy.yaml      # must be a symlink to a real file
kubectl get nodes                  # zero touch
kubectl get nodes                  # second call also zero touch
```

If `kubectl` falls back to `localhost:8080` the symlink target is missing — likely tsh rotated the keys dir. `systemctl --user restart tsh-kube-proxy` regenerates it.

---

## Section B — Python kubernetes clients (utp, custom scripts)

**Problem**: Python `kubernetes` lib (tested through v35) does not honor the kubeconfig `cluster.proxy-url` field, so even with the Section A proxy running, scripts using `config.load_kube_config()` connect directly to `live.teleport.p.canva-cloud.com:443` and fail TLS verification.

**Fix**: Inject `HTTPS_PROXY` and `HTTP_PROXY` env vars pointing at the local proxy port. Do **not** export them globally — that pollutes pip/curl/etc. Wrap individual tools instead.

Bashrc snippet for the `utp` command:
```bash
utp() {
  HTTPS_PROXY=http://127.0.0.1:8443 HTTP_PROXY=http://127.0.0.1:8443 \
    command utp "$@"
}
```
Same pattern for any other Python tool the user runs frequently. Don't try to set these in `KUBECONFIG` or kubeconfig — they must be process env.

### Two gotchas that bite after this wrapper is applied

**Gotcha 1 — subprocess `arnold` inherits HTTPS_PROXY and breaks.**
If the wrapped tool (e.g. `utp`) subprocesses `arnold` for any operation (list, submit, kill), arnold's own k8s client inherits `HTTPS_PROXY=http://127.0.0.1:8443` and tries to route to teleport through it. tsh-proxy:8443 is TLS-only and does not speak plain HTTP CONNECT, so the call fails silently → arnold returns empty stdout → wrapper prints nothing (or "no jobs found"). Fix: in the wrapper tool itself, strip `HTTPS_PROXY`/`HTTP_PROXY` (and lowercase variants) from the env passed to the arnold subprocess. Example for `utp`:
```python
ENV = {
    k: v for k, v in os.environ.items()
    if k not in ("HTTPS_PROXY", "HTTP_PROXY", "https_proxy", "http_proxy")
}
ENV["AWS_PROFILE"] = "deploy"  # plus whatever other arnold-specific env
# ... subprocess.run(["arnold", ...], env=ENV)
```

**Gotcha 2 — merged KUBECONFIG makes Python kube client pick the wrong context.**
With `KUBECONFIG=$HOME/.kube/config:$HOME/.kube/tsh-proxy.yaml`, `config.load_kube_config()` merges both files and uses the **first** `current-context` it finds (the stock one, pointing at `live.teleport.p.canva-cloud.com:443` via exec auth). HTTPS_PROXY then forwards to tsh-proxy, but tsh-proxy expects client-cert auth from the **proxy file's** cluster entry → TLS handshake fails with `tlsv1 alert unknown ca` or `certificate verify failed: self-signed certificate`. Fix: in the wrapped tool, load the tsh-proxy kubeconfig **explicitly** instead of relying on KUBECONFIG env. Example for utp:
```python
def _k8s_clients():
    from kubernetes import client, config
    proxy_cfg = os.path.expanduser("~/.kube/tsh-proxy.yaml")
    try:
        if os.path.isfile(proxy_cfg):
            config.load_kube_config(config_file=proxy_cfg)
        else:
            config.load_kube_config()
    except config.ConfigException:
        config.load_incluster_config()
    return client.CoreV1Api(), client.CustomObjectsApi()
```
`os.path.isfile` (not `os.path.exists`) — the path is a symlink and the target can disappear when tsh rotates certs; isfile resolves through and returns False on a broken symlink so the fallback fires.

**Symptom matrix** (after Section A is set up):

| Symptom                                                                              | Likely cause                                          | Fix                                                                  |
| ------------------------------------------------------------------------------------ | ----------------------------------------------------- | -------------------------------------------------------------------- |
| `utp list` prints empty / "no jobs found" but `arnold list …` works directly         | Gotcha 1 (HTTPS_PROXY leaks to arnold subprocess)     | Strip proxy env in tool's arnold helper                              |
| `utp p` → `SSLCertVerificationError: self-signed certificate` on teleport host       | Symlink `~/.kube/tsh-proxy.yaml` target missing       | `systemctl --user restart tsh-kube-proxy`                            |
| `utp p` → `tlsv1 alert unknown ca` after symlink is healthy                          | Gotcha 2 (merged KUBECONFIG picks stock context)      | Patch `_k8s_clients` to load `~/.kube/tsh-proxy.yaml` explicitly     |
| `arnold list` standalone → `unable to find http proxy url in stderr` + `LoginError`  | `KUBECONFIG` set to tsh-proxy only (overwrite)        | Switch to merge form (`config:tsh-proxy.yaml`) in bashrc             |

### Validation
```bash
source ~/.bashrc
type utp                    # "utp is a function"
utp list                    # exercises subprocess-arnold path (Gotcha 1)
utp p --no-util 2>&1 | head # exercises Python kube client path (Gotcha 2)
```
Both must succeed with no touch and no SSL/Login error. If only one works, consult the symptom matrix above.

---

## Section C — AWS prod profile via local credential cache

**This section requires explicit user consent before applying.** It writes plaintext AWS session tokens to disk (`~/.aws/local-cache/*.json`, chmod 600). Tokens are short-lived (~6h) but this is weaker than the official `roo` → macOS Keychain flow. On Linux devbox the official flow doesn't actually cache anyway (per the Canva design doc — devbox lacks device identity), so for many teams the trade-off is acceptable. **Surface the trade-off, do not apply silently.**

### When to offer this
User reports `aws --profile prod`, S3 downloads, boto3 jobs prompting every call, and observation shows:
- `~/.roo/secrets/secrets.cli.infra auth - aws@prod*` mtime is old (cache writes have been failing for a while)
- `infra auth aws --flavor prod --role …` stderr contains `WARN failed to cache credential prod/core-cn-readwrite/failed to save secret via Roo: exit status 2`

### Mechanism
Drop-in replacement for the credential_process of the affected profile:

1. `~/.local/bin/aws-cred-cached` — bash script taking `<FLAVOR> <ROLE>`:
   - cache path `$HOME/.aws/local-cache/${FLAVOR}_${ROLE}.json`, dir chmod 700
   - serialize concurrent invocations with `flock` (S3 downloaders spawning 32 parallel boto3 sessions would otherwise all MFA)
   - parse cached file's `.Expiration` with `jq`, treat anything within 300s of now as expired
   - if valid, `cat` cache and exit 0
   - else call `/usr/local/bin/infra auth aws --flavor $1 --role $2 > tmp 2>/dev/null`, verify JSON with `jq -e .AccessKeyId tmp`, `mv tmp cache`, then `cat cache`
2. Patch only the **specific** `[prod]` section of `~/.aws/credentials` (or whichever flavor the user is on):
   - `credential_process = /home/<user>/.local/bin/aws-cred-cached <flavor> <role>`
3. Always back up `~/.aws/credentials` first with a timestamped copy.

Do not mass-rewrite all credential_process lines. Mass-rewrite is a security-sensitive operation that auto-mode will block, and you should not bypass it. Limit to the flavor the user actually cares about.

### Validation
```bash
aws --profile <FLAVOR> sts get-caller-identity   # zero touch if cache valid
ls -la ~/.aws/local-cache/                       # cache file present, 600 perms
```

### Long-term
The Canva design DAGjo2hYw2E notes "work underway to enrol the devboxes with their own identities". Once devboxes get device identity, the official `infra auth aws` flow will cache properly and this wrapper becomes unnecessary. Tell the user to revert to the stock credential_process when that ships. They can track progress in `#security-ia-team`.

---

## Section D — roo daemon socket repair (often a red herring)

`~/.roo/daemon.sock` is a symlink to a per-SSH-session forwarded socket at `/tmp/roo.daemon.<ts>.<pid>.<port>.sock`. If the symlink points at a dead session, `roo daemon info` shows `Error: open /dev/tty: no such device or address` from non-TTY contexts and infra-tools cannot reach roo.

Fix:
```bash
LATEST=$(ls -t /tmp/roo.daemon.*.sock 2>/dev/null | head -1)
[ -n "$LATEST" ] && ln -sfn "$LATEST" ~/.roo/daemon.sock
roo daemon info     # should report Uptime cleanly
```

To make this automatic on every new shell, add to bashrc:
```bash
if [ -d /tmp ]; then
  _newest_roo_sock=$(ls -t /tmp/roo.daemon.*.sock 2>/dev/null | head -1)
  [ -n "$_newest_roo_sock" ] && ln -sfn "$_newest_roo_sock" ~/.roo/daemon.sock
  unset _newest_roo_sock
fi
```

**Important**: For AWS prod on devbox, fixing the roo socket alone does **not** stop MFA prompts — devbox doesn't have device identity so the cache layer is bypassed regardless. The wrapper in Section C is what actually reduces touches. Don't promise relief from socket repair alone.

`roo daemon restart` on Linux returns "only supported on macOS". For real daemon issues the user must run it on their Mac.

---

## What this skill is NOT for

- macOS users (their flow is largely already covered by Canva's MFA cache rollout — point them at design DAGjo2hYw2E and Section D only).
- Highly privileged AWS roles (admin, dr-admin), Account Persona Roles, UGC roles — per the design, these intentionally bypass cache and will always step up.
- CI workflows — different identity model.

## Order of operations recommended for a typical devbox user

1. Section D (1-second fix, often not the actual root cause but cheap).
2. Section A (kubectl is usually the most frequent touch source).
3. Section B if user runs `utp` or Python kube clients.
4. Section C only after stating the security trade-off and getting explicit OK.

## After applying

Write per-user memory recording which sections were applied and which values (PROXY, CLUSTER, NS) were used so future sessions can pick up state without re-asking. Do not store credentials themselves in memory.
