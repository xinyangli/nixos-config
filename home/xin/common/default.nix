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
    substituters = "https://cache.nixos.org https://mirrors.ustc.edu.cn/nix-channels/store https://mirrors.tuna.tsinghua.edu.cn/nix-channels/store https://cache.nixos.org/ https://cuda-maintainers.cachix.org";
    trusted-public-keys = "cache.nixos.org-1:6NCHdD59X431o0gWypbMrAURkbJ16ZPMQFGspcDShjY= cuda-maintainers.cachix.org-1:0dq3bujKpuEPMCX6U4WylrUDZ9JyUG0VpVZa7CNfq5E=";
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
