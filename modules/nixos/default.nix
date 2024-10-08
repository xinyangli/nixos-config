{
  imports = [
    ./common-settings/auth.nix
    ./common-settings/autoupgrade.nix
    ./common-settings/nix-conf.nix
    ./restic.nix
    ./vaultwarden.nix
    ./prometheus
    ./hedgedoc.nix
    ./sing-box.nix
    ./stylix.nix
    ./kanidm-client.nix
    ./ssh-tpm-agent.nix # FIXME: Waiting for upstream merge
    ./forgejo-actions-runner.nix
    ./oidc-agent.nix
    ./miniflux.nix
    ./immich.nix
  ];
}
