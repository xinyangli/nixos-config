{
  imports = [
    ./common-settings/auth.nix
    ./common-settings/autoupgrade.nix
    ./common-settings/nix-conf.nix
    ./common-settings/proxy-server.nix
    ./common-settings/mainland.nix
    ./disk-partitions
    ./restic.nix
    ./monitor
    ./kanidm-client.nix
    # ./ssh-tpm-agent.nix # FIXME: Waiting for upstream merge
    ./forgejo-actions-runner.nix
    ./immich.nix
  ];
}
