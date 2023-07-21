{ pkgs, home-manager, ... }:
  home-manager.lib.homeManagerConfiguration {
    inherit pkgs;
    modules = [
      ../common
      {
        home.username = "xin";
        home.homeDirectory = "/home/xin";
        home.stateVersion = "23.05";

        # Let Home Manager install and manage itself.
        programs.home-manager.enable = true;
      }
    ];
  }
