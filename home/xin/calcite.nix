{ config, pkgs, ... }@inputs:
{
  imports = [
    ./common
  ];

  programs.nix-index-database.comma.enable = true;

  home.username = "xin";
  home.homeDirectory = "/home/xin";
  home.stateVersion = "23.05";

  # Let Home Manager install and manage itself.
  programs.home-manager.enable = true;

  accounts.email.accounts.gmail = {
    primary = true;
    address = "lixinyang411@gmail.com";
    flavor = "gmail.com";
    realName = "Xinyang Li";
  };

  accounts.email.accounts.whu = {
    address = "lixinyang411@whu.edu.cn";
  };

  accounts.email.accounts.foxmail = {
    address = "lixinyang411@foxmail.com";
  };

  home.packages = with pkgs; [
    thunderbird
    remmina
  ];

  # Theme
  catppuccin = {
    enable = true;
    flavor = "mocha";
  };
  xdg.enable = true;

  i18n.inputMethod = {
    enabled = "fcitx5";
    fcitx5.addons = with pkgs; [ fcitx5-rime ];
  };

  custom-hm = {
    alacritty = { enable = true; };
    direnv = { enable = true; };
    fish = { enable = true; };
    git = { enable = true; signing.enable = true; };
    neovim = { enable = true; };
    vscode = { enable = true; languages = { cxx = true; python = true; scala = true; latex = true; }; };
    zellij = { enable = true; };
  };
}
