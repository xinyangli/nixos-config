{ config, pkgs, ... }:
{
  home.packages = with pkgs; [
    # File Manager
    xfce.thunar
    xfce.thunar-archive-plugin
    xfce.thunar-media-tags-plugin
    xfce.thunar-volman

    swayimg
  ];
}
