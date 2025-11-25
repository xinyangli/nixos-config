{
  imports = [
    ./full.nix
    ./gui/engineering.nix
  ];
  home.stateVersion = "25.05";

  home = {
    homeDirectory = "/home/xin";
    username = "xin";
  };
}
