{ config, pkgs, ... }:
{
  imports = [
    ./restic.nix
    ./vaultwarden.nix
    ./prometheus.nix
  ];
}