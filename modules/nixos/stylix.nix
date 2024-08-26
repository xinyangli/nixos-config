{
  inputs,
  config,
  pkgs,
  lib,
  ...
}:
let
  inherit (lib) mkEnableOption mkIf;
  cfg = config.custom.stylix;
in
{
  imports = [ inputs.stylix.nixosModules.stylix ];

  options = {
    custom.stylix = {
      enable = mkEnableOption "style management with stylix";
    };
  };

  config = mkIf cfg.enable {
    stylix.enable = true;
    stylix.image = pkgs.fetchurl {
      url = "https://github.com/NixOS/nixos-artwork/blob/master/wallpapers/nixos-wallpaper-catppuccin-mocha.png?raw=true";
      hash = "sha256-fmKFYw2gYAYFjOv4lr8IkXPtZfE1+88yKQ4vjEcax1s=";
    };

    stylix.base16Scheme = "${pkgs.base16-schemes}/share/themes/catppuccin-mocha.yaml";
    stylix.polarity = "dark";
    stylix.autoEnable = false;
    stylix.homeManagerIntegration.autoImport = true;
    stylix.homeManagerIntegration.followSystem = true;
    stylix.fonts = {
      monospace = {
        name = "JetBrainsMono Nerd Font";
        package = pkgs.nerdfonts.override { fonts = [ "JetBrainsMono" ]; };
      };
      serif = {
        name = "Noto Serif CJK SC";
        package = pkgs.noto-fonts;
      };
      sansSerif = {
        name = "Noto Sans CJK SC";
        package = pkgs.noto-fonts;
      };
    };

    stylix.targets = {
      console.enable = true;
      gnome.enable = if config.services.xserver.desktopManager.gnome.enable then true else false;
      gtk.enable = true;
    };
  };
}
