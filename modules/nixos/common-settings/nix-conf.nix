{
  config,
  lib,
  pkgs,
  ...
}:

let
  inherit (lib)
    mkIf
    mkEnableOption
    mkOption
    types
    ;

  cfg = config.commonSettings.nix;
in
{
  options.commonSettings.nix = {
    enable = mkOption {
      default = true;
      type = types.bool;
    };
    signing = {
      enable = mkEnableOption "Sign locally-built paths";
      keyFile = mkOption {
        default = "/var/lib/nix/key.private";
        type = types.str;
      };
    };
  };

  config = mkIf cfg.enable {
    sops = {
      secrets."nix/github_public_token" = {
        mode = "0444";
        sopsFile = ../../../machines/secrets.yaml;
      };
      templates."nix.secret.conf".content = ''
        extra-access-tokens = github.com=${config.sops.placeholder."nix/github_public_token"}
      '';
      templates."nix.secret.conf".mode = "0444";
    };

    nix.package = pkgs.nixVersions.latest;

    services.angrr = {
      enable = true;
      settings = {
        temporary-root-policies = {
          direnv = {
            path-regex = "/home/.*/\\.cache/direnv/layouts/.*";
            period = "30d";
          };
          result = {
            path-regex = "/result[^/]*$";
            period = "3d";
          };
        };
        profile-policies = {
          system = {
            profile-paths = [
              "/nix/var/nix/profiles/system"
              "/nix/var/nix/profiles/system-profiles/comin"
            ];
            keep-since = "7d";
            keep-latest-n = 3;
            keep-booted-system = true;
            keep-current-system = true;
            keep-n-per-bucket = [
              {
                bucket-window = "1 week";
                bucket-amount = 2;
              }
            ];
          };
          user = {
            enable = true;
            profile-paths = [
              "~/.local/state/nix/profiles/profile"
              "~/.local/state/nix/profiles/home-manager"
              "/nix/var/nix/profiles/per-user/root/profile"
            ];
            keep-since = "1d";
            keep-latest-n = 1;
          };
        };
      };
    };
    nix.gc = {
      automatic = true;
      dates = lib.mkDefault "weekly";
      options = lib.mkDefault "--delete-older-than 30d";
    };

    nix.optimise.automatic = true;

    nix.channel.enable = false;

    nix.extraOptions = ''
      !include ${config.sops.templates."nix.secret.conf".path}
    '';

    nix.settings = {
      experimental-features = [
        "nix-command"
        "flakes"
        "ca-derivations"
      ];
      auto-optimise-store = true;
      trusted-users = [ "root" ];

      substituters = [
        "https://pek-0.cache.xiny.li:8443/general"
        "https://nix-community.cachix.org"
        "https://cache.garnix.io"
      ];

      trusted-public-keys = [
        "general:2Hwow6RGV4egE/mDBARmfkyH5tm84r1+BrYvtPRTzco="
        "nix-community.cachix.org-1:mB9FSh9qf2dCimDSUo8Zy7bkq5CX+/rkCWyvRCYg3Fs="
        "cache.garnix.io:CTFPyKSLcx5RMJKfLo5EEPUObbA78b0YQ2DTCJXqr9g="
        "xin-1:8/ul1IhdWLswERF/8RfeAw8VZqjwHrJ1x55y1yjxQ+Y="
      ];

      secret-key-files = mkIf cfg.signing.enable [ cfg.signing.keyFile ];
    };
  };
}
