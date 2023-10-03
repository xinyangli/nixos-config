{ pkgs, ... }: {
  imports = [
    ./fish.nix
    ./git.nix
    ./zellij.nix
    ./vim.nix
  ];

  nix.settings = {
    experimental-features = [ "nix-command" "flakes" ];
    auto-optimise-store = true;
  };


  home.packages = with pkgs; [
    dig
    du-dust # du + rust
    zoxide # autojumper
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
    clash

    inetutils
  ];
}
