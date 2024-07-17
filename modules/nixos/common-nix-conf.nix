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
        "https://mirrors.bfsu.edu.cn/nix-channels/store"
        "https://mirrors.ustc.edu.cn/nix-channels/store"
      ];

      trusted-public-keys = [
        "cache.nixos.org-1:6NCHdD59X431o0gWypbMrAURkbJ16ZPMQFGspcDShjY="
        "nix-community.cachix.org-1:mB9FSh9qf2dCimDSUo8Zy7bkq5CX+/rkCWyvRCYg3Fs="
        "cache.garnix.io:CTFPyKSLcx5RMJKfLo5EEPUObbA78b0YQ2DTCJXqr9g="
      ];
    };
  };
}

