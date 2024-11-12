{ config, lib, ... }:
with lib;

let
  cfg = config.custom-hm.alacritty;
in
{
  options.custom-hm.alacritty = {
    enable = mkEnableOption "alacritty";
  };

  config = mkIf cfg.enable {
    programs.alacritty = {
      enable = true;
      settings = {
        terminal.shell = {
          program = config.programs.zellij.package + "/bin/zellij";
          args = [
            "attach"
            "-c"
            "alacritty-zellij"
          ];
        };
        font.size = 10.0;
        window = {
          resize_increments = true;
          dynamic_padding = true;
          decorations = "none";
        };
      };
    };
  };
}
