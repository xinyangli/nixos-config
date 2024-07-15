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

  nix.package = lib.mkForce pkgs.nixVersions.latest;
  nix.extraOptions = ''
    extra-substituters = https://nix-community.cachix.org
    extra-trusted-public-keys = nix-community.cachix.org-1:mB9FSh9qf2dCimDSUo8Zy7bkq5CX+/rkCWyvRCYg3Fs=
  '';
}
