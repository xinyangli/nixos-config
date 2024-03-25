{ config, pkgs, lib, ... }:
let
  cfg = config.custom.forgejo-actions-runner;
in
{
  options = {
    custom.forgejo-actions-runner = {
      enable = lib.mkEnableOption "TPM supported ssh agent in go";
      tokenFile = lib.mkOption {
        type = lib.types.path;
      };
    };
  };
  config = lib.mkIf cfg.enable {
    virtualisation.docker.enable = true;
    services.gitea-actions-runner.package = pkgs.forgejo-actions-runner;
    services.gitea-actions-runner.instances = {
      "git.xinyang.life" = {
        enable = true;
        url = "https://git.xinyang.life";
        tokenFile = cfg.tokenFile;
        name = config.networking.hostName;
        labels = [
          "debian-latest:docker://node:18-bullseye"
          "ubuntu-latest:docker://node:18-bullseye"
          "nix:docker://xiny/nix-runner:2.21.0-pkgs-23.11"
        ];
        settings = {
          container.network = "host";
        };
      };
    };
  };
}
