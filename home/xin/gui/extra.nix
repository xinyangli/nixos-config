# These applications have larger closure size and is not always necessary
{ pkgs, ... }:
{
  home.packages = with pkgs; [
    resources
    remmina
    qq
    wechat-uos
    wpsoffice
    ttf-wps-fonts

    eudic
    calibre

    # Multimedia
    obs-studio

    # Browser
    chromium

    # wemeet
    wemeet
  ];

  services.system76-scheduler-niri.enable = true;
}
