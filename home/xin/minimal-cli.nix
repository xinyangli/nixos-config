{ config, ... }:
{
  imports = [
    ./cli/essential.nix
  ];

  # Let Home Manager install and manage itself.
  programs.home-manager.enable = true;

  xdg.enable = true;

  programs.man.generateCaches = false;
  services.home-manager.autoUpgrade = {
    enable = true;
    useFlake = true;
  };
}
