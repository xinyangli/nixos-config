{ pkgs, lib, ... }:
let
  homeDirectory = "/home/xin";
in
{
  imports = [
    ./common
  ];

  programs.nix-index-database.comma.enable = true;

  home = {
    inherit homeDirectory;
    username = "xin";
    stateVersion = "23.05";
  };

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
    resources
    thunderbird
    remmina
    qq
    wechat-uos
    wpsoffice
    ttf-wps-fonts
  ];

  # Theme
  catppuccin = {
    enable = true;
    accent = "peach";
    flavor = "mocha";
  };
  # Missing from catppuccin module
  services.swaync.style = pkgs.fetchurl {
    url = "https://github.com/catppuccin/swaync/releases/download/v0.2.3/mocha.css";
    hash = "sha256-Hie/vDt15nGCy4XWERGy1tUIecROw17GOoasT97kIfc=";
  };

  xdg.enable = true;

  custom-hm = {
    alacritty = {
      enable = true;
    };
    cosmic-term = {
      enable = true;
    };
    direnv = {
      enable = true;
    };
    fish = {
      enable = true;
    };
    git = {
      enable = true;
      signing.enable = true;
    };
    neovim = {
      enable = true;
      font = {
        normal = [
          "JetbrainsMono Nerd Font"
          "Noto Sans Mono CJK SC"
          "Ubuntu"
        ];
        size = 12.0;
      };
    };
    vscode = {
      enable = true;
      languages = {
        cxx = true;
        python = true;
        scala = true;
        latex = true;
      };
      llm = true;
    };
    zellij = {
      enable = true;
    };

    gui = {
      niri.enable = true;
      waybar.enable = true;
      fuzzel.enable = true;
    };
  };

  xdg.systemDirs.data = [
    "/usr/share"
    "/var/lib/flatpak/exports/share"
    "${homeDirectory}/.local/share/flatpak/exports/share"
  ];

  programs.man.generateCaches = false;

  programs.atuin = {
    enable = true;
    flags = [ "--disable-up-arrow" ];
  };

  programs.firefox = {
    enable = true;
    policies.DefaultDownloadDirectory = "/media/data/Downloads";
    profiles.default = {
      isDefault = true;
      userChrome = ''

        #TabsToolbar {
          display: none;
        }

        #sidebar-header {
          display: none;
        }

        [titlepreface*="."] #sidebar-header {
          visibility: collapse !important;
        }
        [titlepreface*="."] #TabsToolbar {
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
          z-index: calc(var(--browser-area-z-index-tabbox) + 1);
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

        .sidebar-placeTree {
          /* background-color: transparent !important; */
          color: var(--newtab-text-primary-color) !important;
        }

        .sidebar-placeTree #search-box{
          -moz-appearance: none !important;
          background-color: rgba(249,249,250,0.1) !important;
          color: inherit !important;
        }
      '';
    };
  };

}
