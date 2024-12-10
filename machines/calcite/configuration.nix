{
  config,
  pkgs,
  lib,
  ...
}:
let
  inherit (lib) mkForce getExe;
in
{
  imports = [
    # Include the results of the hardware scan.
    ./hardware-configuration.nix
    ./network.nix
    ../sops.nix
  ];

  commonSettings = {
    # auth.enable = true;
    nix = {
      signing.enable = true;
    };
  };

  # Bootloader.
  boot.loader.systemd-boot.enable = true;
  boot.loader.efi.canTouchEfiVariables = true;
  boot.loader.efi.efiSysMountPoint = "/boot/efi";
  # boot.kernelPackages = pkgs.linuxPackages_latest;
  boot.kernelModules = [
    "nvidia"
    "nvidia_modeset"
    "nvidia_uvm"
  ];
  boot.supportedFilesystems = [ "ntfs" ];
  boot.binfmt.emulatedSystems = [ "aarch64-linux" ];

  documentation = {
    nixos.enable = false;
    man.enable = false;
  };

  security.tpm2 = {
    enable = true;
    # expose /run/current-system/sw/lib/libtpm2_pkcs11.so
    pkcs11.enable = true;
    # TODO: Need this until fapi-config is fixed in NixOS
    pkcs11.package = pkgs.tpm2-pkcs11.override { fapiSupport = false; };
    # TPM2TOOLS_TCTI and TPM2_PKCS11_TCTI env variables
    tctiEnvironment.enable = true;
  };
  # services.gnome.gnome-keyring.enable = lib.mkForce false;
  security.pam.services.login.enableGnomeKeyring = lib.mkForce false;

  programs.ssh.agentPKCS11Whitelist = "${config.security.tpm2.pkcs11.package}/lib/libtpm_pkcs11.so";

  networking.hostName = "calcite";

  services.blueman.enable = true;

  programs.steam = {
    enable = true;
    gamescopeSession = {
      enable = true;
    };
  };

  programs.vim.enable = true;
  programs.vim.defaultEditor = true;

  # Keep this even if enabled in home manager
  programs.fish.enable = true;
  environment.shells = [ pkgs.fish ];
  users.defaultUserShell = pkgs.fish;

  # Setup wireguard
  # Set your time zone.
  time.timeZone = "Asia/Shanghai";

  # Select internationalisation properties.
  i18n.defaultLocale = "en_US.utf8";

  i18n.extraLocaleSettings = {
    LC_ADDRESS = "zh_CN.utf8";
    LC_IDENTIFICATION = "zh_CN.utf8";
    LC_MEASUREMENT = "zh_CN.utf8";
    LC_MONETARY = "zh_CN.utf8";
    LC_NAME = "zh_CN.utf8";
    LC_NUMERIC = "zh_CN.utf8";
    LC_PAPER = "zh_CN.utf8";
    LC_TELEPHONE = "zh_CN.utf8";
    LC_TIME = "en_US.utf8";
  };

  i18n.inputMethod = {
    enable = true;
    type = "fcitx5";
    fcitx5 = {
      addons = [ pkgs.fcitx5-rime ];
      waylandFrontend = true;
    };
  };

  # ====== GUI ======

  programs.niri.enable = true;
  environment.sessionVariables.NIXOS_OZONE_WL = "1";
  security.pam.services.gtklock = { }; # Required by gtklock

  catppuccin = {
    enable = true;
    accent = "peach";
    flavor = "mocha";
  };

  xdg.portal = {
    enable = true;
    extraPortals = [
      pkgs.xdg-desktop-portal-gnome
      pkgs.xdg-desktop-portal-gtk
    ];
    configPackages = [ pkgs.niri ];
  };

  systemd.user.services.xdg-desktop-portal-gtk.after = [ "graphical-session.target" ];
  systemd.user.services.xdg-desktop-portal-gnome.after = [ "graphical-session.target" ];
  systemd.user.services.xdg-desktop-portal-gnome.wantedBy = [ "graphical-session.target" ];

  services.greetd =
    let
      niri-login-config = pkgs.writeText "niri-login-config.kdl" ''
        animations {
          off
        }
        hotkey-overlay {
          skip-at-startup
        }
      '';
    in
    {
      enable = true;
      vt = 1;
      settings = {
        default_session = {
          command = "${pkgs.dbus}/bin/dbus-run-session -- ${getExe pkgs.niri} -c ${niri-login-config} -- ${getExe pkgs.greetd.gtkgreet} -l -c niri-session -s ${pkgs.magnetic-catppuccin-gtk}/share/themes/Catppuccin-GTK-Dark/gtk-3.0/gtk.css";
        };
      };
    };

  # Keyboard mapping on internal keyboard
  services.keyd = {
    enable = true;
    keyboards = {
      "internal" = {
        ids = [ "0b05:1866" ];
        settings = {
          main = {
            capslock = "overload(control, esc)";
            leftcontrol = "capslock";
          };
        };
      };
      "logiM720" = {
        ids = [ "046d:b015" ];
        settings = {
          main = {
            mouse2 = "leftmeta";
            # leftalt = "mouse1";
          };
        };
      };
      "keydous" = {
        ids = [
          "25a7:fa14"
          "3151:4002"
        ];
        settings = {
          main = {
            capslock = "overload(control, esc)";
          };
        };
      };
    };
  };

  # Enable CUPS to print documents.
  services.printing.enable = true;
  services.printing.drivers = [
    pkgs.hplip
    pkgs.gutenprintBin
    pkgs.canon-cups-ufr2
  ];

  hardware.pulseaudio.enable = false;
  security.rtkit.enable = true;
  services.pipewire = {
    enable = true;
    wireplumber.enable = true;
    alsa.enable = true;
    alsa.support32Bit = true;
    pulse.enable = true;
    # If you want to use JACK applications, uncomment this
    jack.enable = true;
  };

  # Define a user account. Don't forget to set a password with ‘passwd’.
  users.users.xin = {
    isNormalUser = true;
    description = "xin";
    extraGroups = [
      "networkmanager"
      "wheel"
      "wireshark"
      "tss"
    ];
  };

  services.kanidm = {
    enableClient = true;
    clientSettings = {
      uri = "https://auth.xinyang.life";
    };
  };

  # Smart services
  services.smartd.enable = true;

  # Allow unfree packages
  nixpkgs.system = "x86_64-linux";
  nixpkgs.config.allowUnfree = true;
  nixpkgs.config.permittedInsecurePackages = [
    "openssl-1.1.1w"
    # FIXME: Waiting for https://github.com/NixOS/nixpkgs/pull/335753
    "jitsi-meet-1.0.8043"
  ];
  # List packages installed in system profile. To search, run:
  # $ nix search wget
  environment.systemPackages = with pkgs; [
    imhex
    oidc-agent
    # Filesystem
    (owncloud-client.overrideAttrs (
      finalAttrs: previousAttrs: {
        src = pkgs.fetchFromGitHub {
          owner = "xinyangli";
          repo = "client";
          rev = "780d1c4c8bf02be42e118c792ff833ab10c2fdcc";
          hash = "sha256-pEwcGJI9sN9nooW/RQHmi52Du6yzofgZeB8PcjwPtZ8=";
        };
      }
    ))
    nfs-utils

    # tesseract5 # ocr
    ocrmypdf # pdfocr

    gtkwave
    bubblewrap

    # ==== Development ==== #
    # Python
    # reference: https://nixos.wiki/wiki/Python
    (
      let
        my-python-packages =
          python-packages: with python-packages; [
            pandas
            requests
            numpy
            pyyaml
            setuptools
          ];
        python-with-my-packages = python3.withPackages my-python-packages;
      in
      python-with-my-packages
    )

    # ==== GUI Softwares ==== #

    eudic

    bibata-cursors
    gthumb
    oculante

    # Multimedia
    vlc
    obs-studio
    spotify
    # IM
    element-desktop
    tdesktop

    # Password manager
    bitwarden

    # Browser
    chromium

    # Writting
    zotero
    # onlyoffice-bin

    config.nur.repos.linyinfeng.wemeet

    virt-manager
    wineWowPackages.waylandFull
    winetricks
  ];

  services.esphome.enable = true;
  users.groups.dialout.members = [ "xin" ];

  system.stateVersion = "22.05";

  system.switch.enable = false;
  system.switch.enableNg = true;

  sops.secrets = {
    "restic/repo_url" = {
      owner = "xin";
      sopsFile = ./secrets.yaml;
    };
    "restic/repo_password" = {
      owner = "xin";
      sopsFile = ./secrets.yaml;
    };
    "gitea/envfile" = {
      owner = "root";
      sopsFile = ./secrets.yaml;
    };
  };

  custom.restic = {
    enable = true;
    paths = [
      "/backup/rootfs/var/lib"
      "/backup/home"
    ];
  };

  # custom.forgejo-actions-runner = {
  #   enable = false;
  #   tokenFile = config.sops.secrets."gitea/envfile".path;
  #   settings = {
  #     runner.capacity = 2;
  #     runner.fetch_timeout = "120s";
  #     runner.fetch_interval = "30s";
  #   };
  # };
  #
  custom.prometheus = {
    exporters.node.enable = true;
  };

  services.ollama = {
    enable = true;
    acceleration = "cuda";
  };

  # MTP support
  services.gvfs.enable = true;

  services.flatpak.enable = true;

  # Fonts
  fonts = {
    packages = with pkgs; [
      nerd-fonts.ubuntu-sans
      nerd-fonts.ubuntu
      nerd-fonts.fira-code
      nerd-fonts.fira-mono
      nerd-fonts.jetbrains-mono
      nerd-fonts.roboto-mono
      noto-fonts
      noto-fonts-emoji
      liberation_ttf
      mplus-outline-fonts.githubRelease
      dina-font
      proggyfonts
      ubuntu_font_family
      # Chinese
      wqy_microhei
      wqy_zenhei
      noto-fonts-cjk-sans
      noto-fonts-cjk-serif
      source-han-sans
      source-han-serif
    ];
    fontconfig = {
      defaultFonts = {
        serif = [
          "Source Han Serif SC"
          "Ubuntu"
        ];
        sansSerif = [
          "Source Han Sans SC"
          "Ubuntu"
        ];
        monospace = [
          "JetbrainsMono Nerd Font"
          "Noto Sans Mono CJK SC"
          "Ubuntu"
        ];
      };
    };
    enableDefaultPackages = true;
  };
  # Virtualization
  virtualisation = {
    libvirtd.enable = true;
    podman = {
      enable = true;
    };
    docker = {
      enable = true;
      autoPrune.enable = true;
    };
  };

  services.nixseparatedebuginfod.enable = true;
  services.bloop = {
    install = true;
    extraOptions = [
      "-J-Xmx2G"
      "-J-XX:MaxInlineLevel=20"
      "-J-XX:+UseParallelGC"
    ];
  };
}
