{ config, ... }:
{
  imports = [
    ./cli/essential.nix
    ./cli/extra.nix

    ./gui/theme.nix
    ./gui/wm/niri.nix

    ./gui/essential.nix
    ./gui/extra.nix
    ./gui/media-processing.nix
    ./gui/pentesting.nix
  ];

  # Let Home Manager install and manage itself.
  programs.home-manager.enable = true;

  xdg.enable = true;

  programs.man.generateCaches = false;
}
