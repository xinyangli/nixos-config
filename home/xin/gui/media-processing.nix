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
    # TODO: wait for https://github.com/NixOS/nixpkgs/issues/475989
    # oculante
  ];
}
