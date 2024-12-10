{
  inputs,
  pkgs,
  lib,
  ...
}:
{
  imports = [
    ./modern-unix.nix
  ];

  home.packages = with pkgs; [
    dig
    file
    man-pages
    unar
    tree
    wget
    tmux
    ffmpeg
    rclone
    wl-clipboard

    inetutils
  ];

  # Required for standalone home configuration
  nix.package = lib.mkForce pkgs.nixVersions.latest;
}
