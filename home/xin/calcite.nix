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
    cosmic-term = { enable = true; };
    direnv = { enable = true; }; fish = { enable = true; }; git = { enable = true; signing.enable = true; };
    neovim = { enable = true; };
    vscode = { enable = true; languages = { cxx = true; python = true; scala = true; latex = true; }; llm = true; };
    zellij = { enable = true; };
  };

  programs.gnome-shell.enable = true;

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
    userChrome = ''
      #titlebar {
        display: none;
      }

      #sidebar-header {
        display: none;
      }

      [titlepreface*="."] #sidebar-header {
        visibility: collapse !important;
      }
      [titlepreface*="."] #titlebar {
        visibility: collapse;
      }

      #sidebar-box{
        --uc-sidebar-width: 33px;
        --uc-sidebar-hover-width: 300px;
        --uc-autohide-sidebar-delay: 90ms;
        position: relative;
        min-width: var(--uc-sidebar-width) !important;
        width: var(--uc-sidebar-width) !important;
        max-width: var(--uc-sidebar-width) !important;
        z-index:1;
      }

      #sidebar-box[positionend]{ direction: rtl }
      #sidebar-box[positionend] > *{ direction: ltr }

      #sidebar-box[positionend]:-moz-locale-dir(rtl){ direction: ltr }
      #sidebar-box[positionend]:-moz-locale-dir(rtl) > *{ direction: rtl }

      #main-window[sizemode="fullscreen"] #sidebar-box{ --uc-sidebar-width: 1px; }

      #sidebar-splitter{ display: none }

      #sidebar-header{
        overflow: hidden;
        color: var(--chrome-color, inherit) !important;
        padding-inline: 0 !important;
      }

      #sidebar-header::before,
      #sidebar-header::after{
        content: "";
        display: -moz-box;
        padding-left: 8px;
      }

      #sidebar-switcher-target{
        -moz-box-pack: start !important;
      }

      #sidebar-header,
      #sidebar{
        transition: min-width 115ms linear var(--uc-autohide-sidebar-delay) !important;
        min-width: var(--uc-sidebar-width) !important;
        will-change: min-width;
      }
      #sidebar-box:hover > #sidebar-header,
      #sidebar-box:hover > #sidebar{
        min-width: var(--uc-sidebar-hover-width) !important;
        transition-delay: 0ms !important;
      }

      .sidebar-panel{
        background-color: transparent !important;
        color: var(--newtab-text-primary-color) !important;
      }

      .sidebar-panel #search-box{
        -moz-appearance: none !important;
        background-color: rgba(249,249,250,0.1) !important;
        color: inherit !important;
      }
    '';
  };
}
