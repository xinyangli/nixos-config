{ pkgs, lib, ... }:
{
  home.packages = with pkgs; [
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
  xdg.mimeApps =
    let
      imageMimes = [
        "image/avif" "image/bmp" "image/gif" "image/heif" "image/jpeg" "image/jpg" "image/jxl"
        "image/pbm" "image/pjpeg" "image/png" "image/svg+xml" "image/tiff" "image/webp"
      ];
      imageAssociations = lib.genAttrs imageMimes (_: "swayimg.desktop");
      textMimes = [
        "text/english" "text/plain" "text/x-makefile" "text/x-c++hdr" "text/x-c++src" "text/x-chdr"
        "text/x-csrc" "text/x-java" "text/x-moc" "text/x-pascal" "text/x-tcl" "text/x-tex"
        "text/x-python"  "inode/x-empty" "application/x-shellscript" "text/x-c" "text/x-c++"
      ];
      textAssociations = lib.genAttrs textMimes (_: "neovide.desktop");
    in
    {
      enable = true;
      defaultApplications = {
        "x-scheme-handler/http" = "firefox.desktop";
        "x-scheme-handler/https" = "firefox.desktop";
        "x-scheme-handler/chrome" = "firefox.desktop";
        "text/html" = "firefox.desktop";
        "application/x-extension-htm" = "firefox.desktop";
        "application/x-extension-html" = "firefox.desktop";
        "application/x-extension-shtml" = "firefox.desktop";
        "application/xhtml+xml" = "firefox.desktop";
        "application/x-extension-xhtml" = "firefox.desktop";
        "application/x-extension-xht" = "firefox.desktop";
        "x-scheme-handler/tg" = "org.telegram.desktop.desktop";
        "x-scheme-handler/tonsite" = "org.telegram.desktop.desktop";
        "x-scheme-handler/terminal" = "foot.desktop";
        "inode/directory" = "nemo.desktop";
        "x-directory/normal" = "nemo.desktop";
        "application/pdf" = "org.pwmt.zathura.desktop";
        "application/epub+zip" = "calibre-ebook-viewer.desktop";
        "application/ereader" = "calibre-ebook-viewer.desktop";
        "application/msword" = "wps-office-wps.desktop";
        "application/x-msword" = "wps-office-wps.desktop";
      }
      // imageAssociations
      // textAssociations;
      associations.added = {
        "inode/directory" = "yazi.desktop";
      };
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
      extraConfig = ''
        /****************************************************************************
         * Betterfox                                                                *
         * "Ad meliora"                                                             *
         * version: 144                                                             *
         * url: https://github.com/yokoffing/Betterfox                              *
        ****************************************************************************/

        /****************************************************************************
         * SECTION: FASTFOX                                                         *
        ****************************************************************************/
        /** GENERAL ***/
        user_pref("gfx.content.skia-font-cache-size", 32);

        /** GFX ***/
        user_pref("gfx.canvas.accelerated.cache-items", 32768);
        user_pref("gfx.canvas.accelerated.cache-size", 4096);
        user_pref("webgl.max-size", 16384);

        /** DISK CACHE ***/
        user_pref("browser.cache.disk.enable", false);

        /** MEMORY CACHE ***/
        user_pref("browser.cache.memory.capacity", 131072);
        user_pref("browser.cache.memory.max_entry_size", 20480);
        user_pref("browser.sessionhistory.max_total_viewers", 4);
        user_pref("browser.sessionstore.max_tabs_undo", 10);

        /** MEDIA CACHE ***/
        user_pref("media.memory_cache_max_size", 262144);
        user_pref("media.memory_caches_combined_limit_kb", 1048576);
        user_pref("media.cache_readahead_limit", 600);
        user_pref("media.cache_resume_threshold", 300);

        /** IMAGE CACHE ***/
        user_pref("image.cache.size", 10485760);
        user_pref("image.mem.decode_bytes_at_a_time", 65536);

        /** NETWORK ***/
        user_pref("network.http.max-connections", 1800);
        user_pref("network.http.max-persistent-connections-per-server", 10);
        user_pref("network.http.max-urgent-start-excessive-connections-per-host", 5);
        user_pref("network.http.request.max-start-delay", 5);
        user_pref("network.http.pacing.requests.enabled", false);
        user_pref("network.dnsCacheEntries", 10000);
        user_pref("network.dnsCacheExpiration", 3600);
        user_pref("network.ssl_tokens_cache_capacity", 10240);

        /** SPECULATIVE LOADING ***/
        user_pref("network.http.speculative-parallel-limit", 0);
        user_pref("network.dns.disablePrefetch", true);
        user_pref("network.dns.disablePrefetchFromHTTPS", true);
        user_pref("browser.urlbar.speculativeConnect.enabled", false);
        user_pref("browser.places.speculativeConnect.enabled", false);
        user_pref("network.prefetch-next", false);
        user_pref("network.predictor.enabled", false);

        /****************************************************************************
         * SECTION: SMOOTHFOX                                                       *
        ****************************************************************************/
        user_pref("general.smoothScroll", true); // DEFAULT
        user_pref("general.smoothScroll.msdPhysics.continuousMotionMaxDeltaMS", 12);
        user_pref("general.smoothScroll.msdPhysics.enabled", true);
        user_pref("general.smoothScroll.msdPhysics.motionBeginSpringConstant", 600);
        user_pref("general.smoothScroll.msdPhysics.regularSpringConstant", 650);
        user_pref("general.smoothScroll.msdPhysics.slowdownMinDeltaMS", 25);
        user_pref("general.smoothScroll.msdPhysics.slowdownMinDeltaRatio", "2");
        user_pref("general.smoothScroll.msdPhysics.slowdownSpringConstant", 250);
        user_pref("general.smoothScroll.currentVelocityWeighting", "1");
        user_pref("general.smoothScroll.stopDecelerationWeighting", "1");
        user_pref("mousewheel.default.delta_multiplier_y", 100); // 250-400; adjust this number to your liking
      '';
    };
  };
}
