{ pkgs, ... }: {
  imports = [
    ./fish.nix
    ./git.nix
    ./zellij.nix
  ];
  home.packages = with pkgs; [
    dig
    du-dust # du + rust
    zoxide # autojumper
    man-pages
    tree
    wget
    tmux
    ffmpeg
    tealdeer
    neofetch
    rclone
    clash
  ];
}