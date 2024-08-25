{
  inputs = {
    nix.url = "github:/nixos/nix?ref=2.21.0";
    nix.inputs.nixpkgs.follows = "nixpkgs";
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-23.11";
    flake-utils.url = "github:numtide/flake-utils";
  };

  outputs =
    {
      self,
      flake-utils,
      nix,
      nixpkgs,
      ...
    }:
    flake-utils.lib.eachDefaultSystem (
      system:
      let
        pkgs = (import nixpkgs) { inherit system; };
        lib = pkgs.lib;
      in
      rec {
        packages = rec {
          # a modified version of the nixos/nix image
          # re-using the upstream nix docker image generation code
          base = import (nix + "/docker.nix") {
            inherit pkgs;
            name = "nix-ci-base";
            maxLayers = 10;
            extraPkgs = with pkgs; [
              nodejs_20 # nodejs is needed for running most 3rdparty actions
              # add any other pre-installed packages here
              curl
              xz
              openssl
              coreutils-full
              cmake
              gnumake
              gcc
            ];
            # change this is you want 
            channelURL = "https://nixos.org/channels/nixpkgs-23.11";
            nixConf = {
              substituters = [
                "https://mirrors.bfsu.edu.cn/nix-channels/store"
                "https://mirrors.ustc.edu.cn/nix-channels/store"
                "https://cache.nixos.org/"

                "https://nix-community.cachix.org"
              ];
              accept-flake-config = "true";
              log-lines = "300";
              trusted-public-keys = [
                "cache.nixos.org-1:6NCHdD59X431o0gWypbMrAURkbJ16ZPMQFGspcDShjY="
                "nix-community.cachix.org-1:mB9FSh9qf2dCimDSUo8Zy7bkq5CX+/rkCWyvRCYg3Fs="
              ];
              # allow using the new flake commands in our workflows
              experimental-features = [
                "nix-command"
                "flakes"
              ];
            };
          };
          # make /bin/sleep available on the image
          runner = pkgs.dockerTools.buildImage {
            name = "nix-runner";
            tag = "2.21.0-pkgs-23.11";

            fromImage = base;
            fromImageName = null;
            fromImageTag = "latest";

            copyToRoot = pkgs.buildEnv {
              name = "image-root";
              paths = [ pkgs.coreutils-full ];
              pathsToLink = [ "/bin" ]; # add coreutuls (which includes sleep) to /bin
            };
          };
        };
      }
    );
}
