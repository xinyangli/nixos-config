{ pkgs, lib, ... }:
{
  home.packages = with pkgs; [
    # File Manager
    (xfce.thunar.override {
      thunarPlugins = [
        xfce.thunar-archive-plugin
        xfce.thunar-media-tags-plugin
        xfce.thunar-volman
      ];
    })
    nautilus
    mate.engrampa

    thunderbird
    telegram-desktop
    element-desktop

    swayimg
    vlc

    zotero

    spotify
    coppwr
    imhex

    nixvim
    neovide
  ];

  xdg.autostart = {
    enable = true;
    readOnly = true;
    entries = [
      "${pkgs.thunderbird}/share/applications/thunderbird.desktop"
      "${pkgs.firefox}/share/applications/firefox.desktop"
      "${pkgs.telegram-desktop}/share/applications/org.telegram.desktop.desktop"
      "${pkgs.element-desktop}/share/applications/element-desktop.desktop"
    ];
  };
  xdg.userDirs.enable = true;

  programs.zathura = {
    enable = true;
    options = {
      recolor = false;
      selection-clipboard = "clipboard";
    };
  };

  programs.foot = {
    enable = true;
    settings = {
      main = {
        font = "monospace:size=14";
      };
      desktop-notifications = {
        command = "${lib.getExe pkgs.libnotify} --wait --app-name \${app-id} --icon \${app-id} --category \${category} --urgency \${urgency} --expire-time \${expire-time} --hint STRING:image-path:\${icon} --hint BOOLEAN:suppress-sound:\${muted} --hint STRING:sound-name:\${sound-name} --replace-id \${replace-id} \${action-argument} --print-id -- \${title} \${body}";
        inhibit-when-focused = "yes";
      };
    };
  };

  # === Input method ===
  i18n.inputMethod = {
    enable = true;
    type = "fcitx5";
    fcitx5 = {
      addons = with pkgs; [
        (fcitx5-rime.override {
          rimeDataPkgs = [
            rime-ice
            rime-zhwiki
            ../../rime-custom
          ];
        })
        fcitx5-gtk
      ];
      waylandFrontend = true;
      settings = {
        globalOptions = {
          Behavior = {
            ActiveByDefault = true;
          };
        };
        inputMethod = {
          GroupOrder."0" = "Default";
          "Groups/0" = {
            Name = "Default";
            "Default Layout" = "us";
            DefaultIM = "rime";
          };
          "Groups/0/Items/0".Name = "keyboard-us";
          "Groups/0/Items/1".Name = "rime";
        };
      };
    };
  };
  # === === ===

  # === Neovim ===
  programs.neovim.enable = false;
  home.file.".config/neovide/config.toml" =
    let
      tomlFormat = pkgs.formats.toml { };
    in
    {
      source = tomlFormat.generate "neovide-config" {
        neovim-bin = lib.getExe pkgs.nixvim;
        frame = "none";
        font = {
          normal = {
            family = "monospace";
            style = "Medium";
          };
          bold = {
            family = "monospace";
            style = "Bold";
          };
          italic = {
            family = "monospace";
            style = "Medium Italic";
          };
          bold_italic = {
            family = "monospace";
            style = "Bold Italic";
          };
          size = 12.0;
        };
      };
    };
  home.sessionVariables.EDITOR = "neovide --no-fork";
  # === === ===

  programs.firefox = {
    enable = true;
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
