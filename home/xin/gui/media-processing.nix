{ pkgs, ... }:

{
  home.packages = with pkgs; [
    exiftool
    darktable
    enblend-enfuse
    hdrmerge
    kdePackages.kdenlive
    inkscape
    gimp3-with-plugins
    hugin
    gthumb
    oculante
  ];
}
