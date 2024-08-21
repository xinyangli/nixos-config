{ config, lib, pkgs, ... }:

let
  inherit (lib) mkIf mkEnableOption mkOption types;

  cfg = config.commonSettings.nix;
in
{
  options.commonSettings.nix = {
    enable = mkOption {
      default = true;
      type = types.bool;
    };
    enableMirrors = mkEnableOption "cache.nixos.org mirrors in Mainland China";
    signing = {
      enable = mkEnableOption "Sign locally-built paths";
      keyFile = mkOption {
        default = "/etc/nix/key.private";
        type = types.str;
      };
    };
  };

  config = mkIf cfg.enable {
    nix.package = pkgs.nixVersions.latest;

    nix.gc = {
      automatic = true;
      dates = "weekly";
      options = "--delete-older-than 30d";
    };

    nix.optimise.automatic = true;

    nix.settings = {
      experimental-features = [ "nix-command" "flakes" ];
      auto-optimise-store = true;
      trusted-users = [ "root" ];

      substituters = [
        "https://nix-community.cachix.org"
        "https://cache.garnix.io"
      ];

      extra-substituters = mkIf cfg.enableMirrors [
        "https://mirrors.cernet.edu.cn/nix-channels/store?priority=20"
      ];

      trusted-public-keys = [
        "nix-community.cachix.org-1:mB9FSh9qf2dCimDSUo8Zy7bkq5CX+/rkCWyvRCYg3Fs="
        "cache.garnix.io:CTFPyKSLcx5RMJKfLo5EEPUObbA78b0YQ2DTCJXqr9g="
        "xin-1:8/ul1IhdWLswERF/8RfeAw8VZqjwHrJ1x55y1yjxQ+Y="
      ];

      secret-key-files = mkIf cfg.signing.enable [
        cfg.signing.keyFile
      ];
    };
  };
}

