{ config, pkgs, lib, ... }:
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
        shell = {
          program = config.programs.zellij.package + "/bin/zellij";
          args = [
            "attach"
            "-c"
          ];
        };
        font.size = 10.0;
        window = {
          resize_increments = true;
          dynamic_padding = true;
        };
        import = [
          "${config.xdg.configHome}/alacritty/catppuccin-macchiato.yml"  
        ];
      };
    };
    xdg.configFile."alacritty/catppuccin-macchiato.yml".source = builtins.fetchurl {
      url = "https://raw.githubusercontent.com/catppuccin/alacritty/main/catppuccin-macchiato.yml";
      sha256 = "sha256-+m8FyPStdh1A1xMVBOkHpfcaFPcyVL99tIxHuDZ2zXI=";
    };
  };
}
