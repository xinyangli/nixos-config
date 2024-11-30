{
  imports = [
    ./common-settings/auth.nix
    ./common-settings/autoupgrade.nix
    ./common-settings/nix-conf.nix
    ./common-settings/proxy-server.nix
    ./disk-partitions
    ./restic.nix
    ./vaultwarden.nix
    ./monitor
    ./hedgedoc.nix
    ./sing-box.nix
    ./kanidm-client.nix
    ./ssh-tpm-agent.nix # FIXME: Waiting for upstream merge
    ./forgejo-actions-runner.nix
    ./oidc-agent.nix
    ./miniflux.nix
    ./immich.nix
  ];
}
