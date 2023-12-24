{ config, lib, ... }: 
with lib;

let
  cfg = config.custom-hm.direnv;
in
{
  options.custom-hm.direnv = {
    enable = mkEnableOption "direnv";
  };
  config = {
    programs = mkIf config.custom-hm.direnv.enable {
      direnv = {
        enable = true;
      };
    };
  };
}