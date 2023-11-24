{ pkgs, ... }: {
  imports = [
    ./fish.nix
    ./git.nix
    ./zellij.nix
    ./vim.nix
  ];

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
    neofetch
    rclone

    inetutils
  ];
}
