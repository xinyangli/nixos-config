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
          "${config.xdg.configHome}/alacritty/catppuccin-macchiato.toml"
        ];
      };
    };
    xdg.configFile."alacritty/catppuccin-macchiato.toml".source = builtins.fetchurl {
      url = "https://raw.githubusercontent.com/catppuccin/alacritty/main/catppuccin-macchiato.toml";
      sha256 = "sha256:1iq187vg64h4rd15b8fv210liqkbzkh8sw04ykq0hgpx20w3qilv";
    };
  };
}
