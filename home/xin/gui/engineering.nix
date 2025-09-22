{ pkgs, ... }:

{
  home.packages = with pkgs; [
    kicad
    freecad   
  ];
}
