{ config, pkgs, ... }:
{
  imports = [
    ./restic.nix
    ./vaultwarden.nix
    ./prometheus.nix
    ./hedgedoc.nix
    ./sing-box.nix
    ./kanidm-client.nix
  ];
}
