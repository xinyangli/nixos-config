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
    vscode = { enable = true; languages = { cxx = true; python = true; scala = true; latex = true; }; llm = true; };
    zellij = { enable = true; };
  };

  programs.atuin = {
    enable = true;
    flags = [ "--disable-up-arrow" ];
  };

  programs.firefox.enable = true;

  programs.firefox.policies = {
    DefaultDownloadDirectory = "/media/data/Downloads";
  };

  programs.firefox.profiles.default = {
    isDefault = true;
    userChrome = builtins.readFile "${pkgs.fetchgit {
      url = "https://gist.github.com/0ded98af9fe3da35f3688f81364d8c14.git";
      rev = "11bb4f428382052bcbbceb6cc3fef97f3c939481";
      hash = "sha256-J11indzEGdUA0HSW8eFe5AjesOxCL/G05KwkJk9GZSY=";
    }}/userChrome.css";
  };
}
