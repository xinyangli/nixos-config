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
    substituters = "https://mirrors.ustc.edu.cn/nix-channels/store https://mirrors.tuna.tsinghua.edu.cn/nix-channels/store";
  };


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
