{
  config,
  pkgs,
  lib,
  ...
}:
let
  inherit (config.my-lib) flakePath;
  configDir = "${flakePath config}/config";
in
{
  # Theme
  catppuccin = {
    enable = true;
    accent = "peach";
    flavor = "mocha";
    gtk.icon.enable = true;
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

  home.pointerCursor = {
    name = "Bibata-Modern-Ice";
    size = 24;
    package = pkgs.bibata-cursors;
    gtk.enable = true;
  };
  gtk = {
    enable = true;
    theme = {
      name = "Catppuccin-GTK-Peach-Dark";
      # TODO: Wait for update so that "peach" is available
      package =
        (pkgs.magnetic-catppuccin-gtk.overrideAttrs {
          src = pkgs.fetchFromGitHub {
            owner = "Fausto-Korpsvart";
            repo = "Catppuccin-GTK-Theme";
            rev = "f25d8cf688d8f224f0ce396689ffcf5767eb647e";
            hash = "sha256-W+NGyPnOEKoicJPwnftq26iP7jya1ZKq38lMjx/k9ss=";
          };
        }).override
          { accent = [ "all" ]; };
    };
    gtk2.configLocation = "${config.xdg.configHome}/gtk-2.0/gtkrc";
    gtk3.extraConfig = {
      gtk-application-prefer-dark-theme = 1;
    };
  };
  dconf.settings = {
    "org/gnome/desktop/interface" = {
      color-scheme = "prefer-dark";
    };
  };

  xdg.configFile.qt5ct.source = config.lib.file.mkOutOfStoreSymlink "${configDir}/qt5ct";
  xdg.configFile.qt6ct.source = config.lib.file.mkOutOfStoreSymlink "${configDir}/qt6ct";
  qt = {
    enable = true;
    style.name = "kvantum";
    platformTheme = {
      name = "qtct";
    };
  };
  home.sessionVariables."QT_STYLE_OVERRIDE" = lib.mkForce "";
  home.packages = with pkgs; [
    nerd-fonts.ubuntu-sans
    nerd-fonts.ubuntu
    nerd-fonts.fira-code
    nerd-fonts.fira-mono
    nerd-fonts.jetbrains-mono
    nerd-fonts.noto
    # nerd-fonts.liberation
    roboto-mono
    mplus-outline-fonts.githubRelease
    ubuntu-classic
    google-fonts
    liberation_ttf

    # Chinese
    nerd-fonts-misans
    wqy_microhei
    wqy_zenhei
    noto-fonts-cjk-sans
    noto-fonts-cjk-serif
    source-han-sans
    source-han-serif
    source-han-mono
    smiley-sans
    foundertype-fonts

    # Emoji
    joypixels
    noto-fonts-color-emoji
  ];

  nixpkgs.config.allowUnfree = true;
  nixpkgs.config.joypixels.acceptLicense = true;

  fonts.fontconfig = {
    enable = true;
    antialiasing = true;
    hinting = "slight";
    defaultFonts = {
      serif = [
        "Liberation Serif"
        "Noto Serif CJK SC"
        "Joypixels"
      ];
      sansSerif = [
        # MiSans Global
        "MiSans"
        "MiSans Latin"
        "MiSans Tibetan"
        "MiSans Arabic"
        "MiSans Devanagari"
        "MiSans Gujarati"
        "MiSans Gurmukhi"
        "MiSans Khmer"
        "MiSans Lao"
        "MiSans Latin"
        "MiSans Myanmar"
        "MiSans Thai"
        "MiSans L3"
        "MiSans TC"
        "Joypixels"
      ];
      monospace = [
        "JetbrainsMono Nerd Font"
        "Joypixels"
        "Source Han Mono SC"
      ];
      emoji = [
        "Joypixels"
        "Noto Emoji Color"
      ];
    };
    configFile =
      let
        pkg = pkgs.fontconfig;
      in
      {
        # These will only be used if global default settings are not present
        "misans-ko-ja" = {
          enable = true;
          priority = 40;
          text = ''
            <?xml version="1.0"?>
            <!DOCTYPE fontconfig SYSTEM "urn:fontconfig:fonts.dtd">
            <fontconfig>
            <match target="pattern">
              <test name="lang" compare="contains">
                <string>ko</string>
              </test>
              <test name="lang" compare="contains">
                <string>ja</string>
              </test>
              <test name="family">
                <string>sans-serif</string>
              </test>
              <edit name="family" mode="prepend" binding="strong">
                <string>MiSans</string>
              </edit>
            </match>
            </fontconfig>
          '';
        };
        "evil-wps-fonts" = {
          enable = true;
          priority = 40;
          text = ''
            <?xml version="1.0"?>
            <!DOCTYPE fontconfig SYSTEM "urn:fontconfig:fonts.dtd">
            <fontconfig>
            <match>
              <test name="family"><string>宋体</string></test>
              <edit name="family" mode="prepend" binding="strong">
                <string>方正书宋_GBK</string>
                <string>Noto Serif CJK SC</string>
              </edit>
            </match>

            <match target="pattern">
              <test name="family"><string>SimSun</string> </test>
              <edit binding="strong" mode="prepend" name="family">
                <string>方正书宋_GBK</string>
                <string>Noto Serif CJK SC</string>
              </edit>
            </match>

            <match>
              <test name="family"><string>仿宋</string></test>
              <edit name="family" mode="prepend" binding="strong">
                <string>FZFangSong-Z02</string>
                <string>Noto Serif CJK SC</string>
              </edit>
            </match>

            <match>
              <test name="family"><string>黑体</string></test>
              <edit name="family" mode="prepend" binding="strong">
                <string>方正黑体_GBK</string>
                <string>Noto Sans CJK SC</string>
              </edit>
            </match>

            <match>
              <test name="family"><string>SimHei</string></test>
              <edit name="family" mode="prepend" binding="strong">
                <string>方正黑体_GBK</string>
                <string>Noto Sans CJK SC</string>
              </edit>
            </match>

            <match>
              <test name="family"><string>楷体</string></test>
              <edit name="family" mode="prepend" binding="strong">
                <string>方正楷体_GBK</string>
                <string>Noto Sans CJK SC</string>
              </edit>
            </match>

            <alias binding="strong">
              <family>FangSong</family>
              <accept>
                <family>方正仿宋_GBK</family>
              </accept>
            </alias>

            <alias binding="strong">
              <family>仿宋</family>
              <accept>
                <family>方正仿宋_GBK</family>
              </accept>
            </alias>

            <alias binding="strong">
              <family>KaiTi</family>
              <accept>
                <family>方正楷体_GBK</family>
              </accept>
            </alias>

            <alias binding="strong">
              <family>KaiTi SC</family>
              <accept>
                <family>方正楷体_GBK</family>
              </accept>
            </alias>

            <alias binding="strong">
              <family>楷体</family>
              <accept>
                <family>方正楷体_GBK</family>
              </accept>
            </alias>

            <alias binding="strong">
              <family>等线</family>
              <accept>
                <family>Source Han Mono SC</family>
              </accept>
            </alias>

            <alias binding="strong">
              <family>Dengxian</family>
              <accept>
                <family>Source Han Mono SC</family>
              </accept>
            </alias>
            </fontconfig>
          '';
        };
        "lcdfilter-default" = {
          enable = true;
          priority = 11;
          source = "${pkg.out}/share/fontconfig/conf.avail/11-lcdfilter-default.conf";
        };
      };
  };
}
