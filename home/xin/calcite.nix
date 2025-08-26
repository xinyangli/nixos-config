{
  config,
  pkgs,
  lib,
  ...
}:
let
  homeDirectory = "/home/xin";
in
{
  imports = [
    ./common
    ./common/pentesting.nix
    ./common/gui/foot.nix
    ./common/gui/default.nix
    ./localisation.nix
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

    eudic

    exiftool
    darktable
    enblend-enfuse
    hdrmerge
    kdePackages.kdenlive
    inkscape
    gimp3-with-plugins
    hugin
    gthumb
    oculante

    # Multimedia
    vlc
    obs-studio
    spotify
    # TODO: Waiting for a new release of librespot, see github: spotifyd #1299
    spotifyd
    coppwr

    # IM
    element-desktop
    tdesktop

    # Password manager
    bitwarden

    # Browser
    chromium

    # Writting
    zotero

    # wemeet
    wemeet

    imhex
    oidc-agent
  ];

  # Theme
  catppuccin = {
    enable = true;
    accent = "peach";
    flavor = "mocha";
    fcitx5 = {
      # See https://github.com/nix-community/home-manager/issues/5982#issuecomment-2822054196
      # catppuccin/nix directly bind to conf/classiui.conf, which cause the problem if
      # any fcitx5 settings is set in home-manager
      apply = false;
      enableRounded = true;
    };
  };
  i18n.inputMethod.fcitx5.settings.addons.classicui.globalSection.Theme =
    let
      cfg = config.catppuccin.fcitx5;
    in
    "catppuccin-${cfg.flavor}-${cfg.accent}";

  xdg.enable = true;

  custom-hm = {
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
      enable = false;
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

  programs.man.generateCaches = false;

  programs.atuin = {
    enable = true;
    flags = [ "--disable-up-arrow" ];
  };

  programs.zathura = {
    enable = true;
    options = {
      recolor = false;
      selection-clipboard = "clipboard";
    };
  };

  xdg.autostart = {
    enable = true;
    readOnly = true;
    entries = [
      "${pkgs.thunderbird}/share/applications/thunderbird.desktop"
      "${pkgs.firefox}/share/applications/firefox.desktop"
      "${pkgs.tdesktop}/share/applications/org.telegram.desktop.desktop"
    ];
  };

  programs.yazi = {
    enable = true;
    plugins = with pkgs.yaziPlugins; {
      chmod = chmod;
      git = git;
      bypass = bypass;
    };
    initLua = ''
      require("git"):setup()
    '';
    settings = {
      plugin.prepend_fetchers = [
        {
          id = "git";
          name = "*";
          run = "git";
        }
        {
          id = "git";
          name = "*/";
          run = "git";
        }
      ];
    };
    keymap = {
      manager.prepend_keymap = [
        {
          on = "T";
          run = "plugin toggle-pane max-preview";
          desc = "Maximize or restore the preview pane";
        }
        {
          on = [
            "c"
            "m"
          ];
          run = "plugin chmod";
          desc = "Chmod on selected files";
        }
        {
          on = [ "L" ];
          run = "plugin bypass";
          desc = "Recursively enter child directory, skipping children with only a single subdirectory";
        }
        {
          on = [ "H" ];
          run = "plugin bypass reverse";
          desc = "Recursively enter parent directory, skipping parents with only a single subdirectory";
        }
        {

          on = [ "l" ];
          run = "plugin bypass smart_enter";
          desc = "Open a file, or recursively enter child directory, skipping children with only a single subdirectory";

        }

      ];
    };
  };

  programs.lazygit = {
    enable = true;
  };

  programs.firefox = {
    enable = true;
    policies.DefaultDownloadDirectory = "/media/data/Downloads";
    profiles.default = {
      isDefault = true;
      extensions.force = true;
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

        #sidebar-header:hover,
        #sidebar:hover{
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
