{ config, ... }:
let
  homeDirectory = "/home/xin";
in
{
  imports = [
    ./cli/essential.nix
    ./cli/extra.nix

    ./gui/wm/niri.nix

    ./gui/essential.nix
    ./gui/extra.nix
    ./gui/media-processing.nix
    ./gui/pentesting.nix
  ];

  programs.nix-index-database.comma.enable = true;

  home = {
    inherit homeDirectory;
    username = "xin";
    stateVersion = "23.05";
  };

  # Let Home Manager install and manage itself.
  programs.home-manager.enable = true;

  # Theme
  catppuccin = {
    enable = true;
    accent = "peach";
    flavor = "mocha";
    fcitx5 = {
      # See https://github.com/nix-community/home-manager/issues/5982#issuecomment-2822054196
      # catppuccin/nix directly bind to conf/classiui.conf, which cause the problem if
      # any fcitx5 settings is set in home-manager
      apply = false;
      enableRounded = true;
    };
  };
  i18n.inputMethod.fcitx5.settings.addons.classicui.globalSection.Theme =
    let
      cfg = config.catppuccin.fcitx5;
    in
    "catppuccin-${cfg.flavor}-${cfg.accent}";

  xdg.enable = true;

  programs.man.generateCaches = false;
}
