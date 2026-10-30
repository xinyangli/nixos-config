---
name: nixos-deploy
description: Test and deploy NixOS config changes on comin-managed machines. Use when committing/pushing config changes, deploying to deploy-test or deploy branches, or checking deployment status.
---

# NixOS config test & deploy

All machines update themselves via [comin](modules/nixos/common-settings/comin.nix) pulling from this repo. There is no manual `nixos-rebuild` step — deployment = pushing git branches.

## Branch flow

| Branch | Role | Force-push |
|---|---|---|
| `deploy-next` | Build-test only: Hydra builds it, comin never switches machines to it | Allowed |
| `deploy-test` | **Primary testing branch**: all in-progress changes go here first for live testing | Allowed |
| `deploy` | Prod: comin's main branch on every machine. Only receives tested, squashed commits | **Never** |

- Comin remotes: `github.com/xinyangli/nixos-config` and `git.xiny.li/xin/nixos-config`; both track `deploy` (main) and `deploy-test` (testing). Nothing tracks `deploy-next` — machines stay on their current generation.
- Workflow: commit → push to `deploy-next` → confirm Hydra build is green → push/fast-forward `deploy-test` and exercise it live on machines → test → **squash similar/related commits into one commit** → merge that single commit into `deploy` → push. Do not rebase/force-push `deploy`; it is shared prod history. Prod history stays clean: one squashed commit per feature/fix, not a stream of fixups.
- Never push untested work straight to `deploy`. Untested changes always land on `deploy-test` first.

## Hydra builds every pushed commit

- Agate runs Hydra; jobset `nixos-config-deploy` (project `nixos-config`) builds `hydraJobs` from flake.nix for: agate, raspite, baryte, osmium, hafnon, thorite, biotite, la-00, fra-00, plus home-manager configs (`xin-x86_64-linux`, `xin-x86_64-minimal-cli`, `xin-x86_64-full-cli`), plus the NixOS VM tests as `tests.<system>.<name>` for aarch64-linux and x86_64-linux (backup, ipsec-mesh, mesh-sshd, mesh-caddy, mesh-gost, kanidm-provision, pam-oath).
- Hydra-executor machines (biotite, dolomite, raspite, thorite) only switch after the Hydra build succeeds; pushing a broken commit just fails there, it does not get deployed to them.
- agate, hafnon, weilite, cinnabar use the `nix` executor (build locally); agate/hafnon avoid depending on Hydra since they provide it.

## Do not run `nix flake check` locally before pushing

Hydra is the build gate. Check results at **https://hydra.u.xiny.li** (jobset `nixos-config-deploy`, project `nixos-config`); it builds every pushed commit across all `hydraJobs` hosts and home configs.

## Verify a deployment landed

SSH directly to any machine as `<hostname>.u.xiny.li` (e.g. `ssh agate.u.xiny.li`; `~/.ssh/config` has a `*.u.xiny.li` stanza with a shared control master).

For root/TOTP access, use the `agent-pam-ssh` skill.

On the target machine:

```sh
comin status                        # shows fetched branch, commit, build/switch state
systemctl status comin              # service health
```

After a switch that needs a reboot (kernel/initrd/kernel-modules/systemd changed), a post-deploy hook publishes an ntfy notification to the `comin-reboot` topic with a Reboot action — no manual reboot unless asked.

## Gotchas

- `nixpkgs.url` points at `github:xinyangli/nixpkgs/deploy` — input bumps may require that branch too.
- SOPS: new keys require `sops updatekeys` (see note.md); secrets changes don't need extra deploy steps beyond the normal branch flow.
