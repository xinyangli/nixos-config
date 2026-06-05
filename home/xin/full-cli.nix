{ config, lib, ... }:
let
  envUsername = builtins.getEnv "XIN_FLAKES_HM_USERNAME";
in
{
  imports = [
    ./cli/essential.nix
    ./cli/extra.nix
    ./agents
  ];

  home = lib.mkIf (envUsername != "") {
    username = envUsername;
    homeDirectory = "/home/${envUsername}";
  };

  # Let Home Manager install and manage itself.
  programs.home-manager.enable = true;

  xdg.enable = true;

  programs.man.generateCaches = false;
}
