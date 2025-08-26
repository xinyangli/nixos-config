{ config, pkgs, ... }:
{
  home.packages = with pkgs; [
    # File Manager
    (xfce.thunar.override {
      thunarPlugins = [
        xfce.thunar-archive-plugin
        xfce.thunar-media-tags-plugin
        xfce.thunar-volman
      ];
    })
    mate.engrampa

    swayimg
  ];
}
