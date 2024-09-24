{
  config,
  lib,
  ...
}:

let
  inherit (lib)
    mkIf
    mkEnableOption
    mkOption
    types
    ;

  cfg = config.commonSettings.autoupgrade;
in
{
  options.commonSettings.autoupgrade = {
    enable = mkEnableOption "auto upgrade with nixos-rebuild";
    flake = mkOption {
      type = types.str;
      default = "github:xinyangli/nixos-config/deploy";
    };
  };

  config = mkIf cfg.enable {
    system.autoUpgrade = {
      enable = true;
      flake = cfg.flake;
    };
  };
}
