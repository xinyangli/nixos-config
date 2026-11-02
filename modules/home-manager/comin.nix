{ comin }:
{
  config,
  lib,
  pkgs,
  ...
}:
let
  inherit (lib)
    mkEnableOption
    mkIf
    mkOption
    types
    ;

  cfg = config.commonSettings.comin;

  system = pkgs.stdenv.hostPlatform.system;
in
{
  imports = [ comin.homeManagerModules.comin ];

  options.commonSettings.comin = {
    enable = mkEnableOption "auto updater with comin";
    configuration = mkOption {
      type = types.str;
      description = ''
        The `homeConfigurations.<name>` flake output comin builds and
        activates on this machine.
      '';
      example = "xin-x86_64-linux";
    };
    url = mkOption {
      type = types.str;
      default = "/home/xin@auth.xiny.li/repo/personal/nixos-config";
      description = ''
        Local path of the nixos-config checkout comin fetches from.
        Home Manager deployments always build on the local machine
        (no Hydra executor), so a local directory remote avoids a
        pointless network round-trip.
      '';
    };
  };

  config = mkIf cfg.enable {
    services.comin = {
      enable = true;
      # Must come from the comin branch with Home Manager support: the
      # nixpkgs `comin` package predates `comin run --home-manager`.
      package = comin.packages.${system}.default;
      homeManagerConfiguration = cfg.configuration;
      # The metrics server always starts and a bind failure is fatal;
      # 4243 is taken by the system comin instance on fleet machines.
      exporter = {
        listen_address = "127.0.0.1";
        port = 4244;
      };
      remotes = [
        {
          name = "local";
          url = cfg.url;
          branches.main.name = "deploy";
          branches.testing.name = "deploy-test";
        }
        # Upstream mirrors: comin picks the first remote with a new head, so
        # local-only changes win while commits pushed elsewhere (or merged
        # PRs) still trigger an update once the local checkout is in sync.
        {
          name = "origin";
          url = "https://github.com/xinyangli/nixos-config.git";
          branches.main.name = "deploy";
          branches.testing.name = "deploy-test";
        }
        {
          name = "forgejo";
          url = "https://git.xiny.li/xin/nixos-config.git";
          branches.main.name = "deploy";
          branches.testing.name = "deploy-test";
        }
      ];
    };
  };
}
