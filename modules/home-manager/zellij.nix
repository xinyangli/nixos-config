{ config, pkgs, lib, ... }: 

with lib;

let
  cfg = config.custom-hm.zellij;
in
{
  options.custom-hm.zellij = {
    enable = mkEnableOption "zellij configurations";
  };
  config = {
    programs.zellij = mkIf cfg.enable {
      enable = true;
      settings = {
        default_shell = "fish";
        keybinds = {
          unbind = [
            "Ctrl p"
            "Ctrl n"
          ];
          shared_except = {
            _args = [ "pane" "locked" ];
            bind = {
              _args = [ "Ctrl b"];
              SwitchToMode = "Pane";
            };
          };
        };
      };
    };
  };
}
