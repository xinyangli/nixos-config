{ inputs, pkgs, lib, ... }: {
  imports = [ ];

  home.packages = with pkgs; [
    dig
    du-dust # du + rust
    zoxide # autojumper
    ripgrep
    file
    man-pages
    unar
    tree
    wget
    tmux
    ffmpeg
    tealdeer
    rclone
    wl-clipboard

    inetutils
  ];

  # Required for standalone home configuration
  nix.package = lib.mkForce pkgs.nixVersions.latest;
}
