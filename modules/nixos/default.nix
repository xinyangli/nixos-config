{ config, pkgs, ... }:
{
  imports = [
    ./common-settings/auth.nix
    ./common-settings/nix-conf.nix
    ./restic.nix
    ./vaultwarden.nix
    ./prometheus.nix
    ./hedgedoc.nix
    ./sing-box.nix
    ./kanidm-client.nix
    ./ssh-tpm-agent.nix # FIXME: Waiting for upstream merge
    ./forgejo-actions-runner.nix
    ./oidc-agent.nix
  ];
}
