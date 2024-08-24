{ config, pkgs, lib, ... }:

let
  inherit (lib) mkEnableOption mkIf;

  cfg = config.custom-hm.cosmic-term;
in
{
  options.custom-hm.cosmic-term = {
    enable = mkEnableOption "cosmic-term";
  };

  config = mkIf cfg.enable {
    home.packages = [ pkgs.cosmic-term ];
  };
}
