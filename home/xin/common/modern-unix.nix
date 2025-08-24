{ pkgs, ... }:
{
  home.packages = with pkgs; [
    httpie
    curlie
    bat
    htop
    procs
    rust-parallel
    jq
    fd
    du-dust # du + rust
    ripgrep
    tealdeer
  ];
  programs.zoxide.enable = true;
}
