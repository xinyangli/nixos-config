# These applications have larger closure size and is not always necessary
{ pkgs, ... }:
{
  home.packages = with pkgs; [
    resources
    remmina
    qq
    wechat
    wpsoffice
    ttf-wps-fonts

    gnome-sound-recorder

    eudic
    calibre

    # Multimedia
    obs-studio
    piliplus

    # Browser
    chromium

    # wemeet
    wemeet
  ];
}
