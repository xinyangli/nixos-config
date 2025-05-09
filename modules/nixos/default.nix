{
  imports = [
    ./common-settings/auth.nix
    ./common-settings/autoupgrade.nix
    ./common-settings/comin.nix
    ./common-settings/nix-conf.nix
    ./common-settings/proxy-server.nix
    ./common-settings/mainland.nix
    ./common-settings/network.nix
    ./common-settings/server.nix
    ./disk-partitions
    ./restic.nix
    ./monitor
  ];
}
