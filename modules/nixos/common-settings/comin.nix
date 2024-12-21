{
  config,
  lib,
  ...
}:
let
  inherit (lib)
    mkEnableOption
    mkIf
    ;

  cfg = config.commonSettings.comin;
in
{
  options.commonSettings.comin = {
    enable = mkEnableOption "auto updater with comin";
  };

  config = {
    services.comin = mkIf cfg.enable {
      enable = true;
      remotes = [
        {
          name = "origin";
          url = "https://github.com/xinyangli/nixos-config.git";
          branches.main.name = "deploy-comin-eval";
        }
      ];
      hostname = config.networking.hostName;
    };
  };
}
