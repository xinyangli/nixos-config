{
  config,
  pkgs,
  lib,
  ...
}:
let
  inherit (lib) getExe;
  inherit (config.my-lib.settings) idpUrl;
in
{
  imports = [
    # Include the results of the hardware scan.
    ./hardware-configuration.nix
    ./disko-config.nix
    ./network.nix
    ../sops.nix
    ./lanzaboote.nix
  ];

  nixpkgs.overlays = [
    (self: super: {
      niri = super.niri.overrideAttrs {
        patches = [
          (pkgs.fetchurl {
            url = "https://patch-diff.githubusercontent.com/raw/YaLTeR/niri/pull/1791.diff";
            hash = "sha256-oHtim6jsFDiHG0BxPd7n9GJc8BWA46G/yjj2nmFrirg=";
          })
        ];
      };
    })
  ];

  commonSettings = {
    auth.enable = true;
    nix = {
      signing.enable = true;
    };
    comin.enable = true;
    network = {
      localdns.enable = true;
      enableProxy = true;
    };
  };

  nix.settings.substituters = [
    "https://nix-community.cachix.org"
  ];
  nix.settings.trusted-public-keys = [
    # Compare to the key published at https://nix-community.org/cache
    "nix-community.cachix.org-1:mB9FSh9qf2dCimDSUo8Zy7bkq5CX+/rkCWyvRCYg3Fs="
  ];

  boot.kernelPackages = pkgs.linuxPackages_latest;
  boot.binfmt.emulatedSystems = [ "aarch64-linux" ];

  # Bootloader.
  boot = {
    plymouth.enable = true;

    # Enable "Silent boot"
    consoleLogLevel = 3;
    initrd.verbose = false;
    initrd.availableKernelModules = [ "xe" ];
    kernelParams = [
      "quiet"
      "splash"
      "boot.shell_on_fail"
      "udev.log_priority=3"
      "rd.systemd.show_status=auto"
    ];

    loader = {
      # Hide the OS choice for bootloaders.
      timeout = 0;
      systemd-boot = {
        enable = true;
        configurationLimit = 10;
      };
      efi.canTouchEfiVariables = true;
      efi.efiSysMountPoint = "/boot";
    };
  };

  services.logind = {
    settings.Login = {
      HandlePowerKey = "suspend-then-hibernate";
      HandlePowerKeyLongPress = "poweroff";
      HandleLidSwitch = "suspend-then-hibernate";
      HandlelidSwitchDocked = "ignore";
    };
  };

  systemd.sleep.extraConfig = ''
    SuspendEstimationSec=5m
    HibernateDelaySec=4h
    HibernateOnACPower=false
  '';

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

  programs.ssh.agentPKCS11Whitelist = "${config.security.tpm2.pkcs11.package}/lib/libtpm_pkcs11.so";
  programs.gnupg.agent.pinentryPackage = pkgs.pinentry-gtk2;

  networking.hostName = "cinnabar";

  services.blueman.enable = true;

  programs.steam = {
    enable = true;
    gamescopeSession = {
      enable = true;
    };
  };
  services.udev.extraRules = ''
    # 8BitDo Ultimate 2 Wireless over USB
    KERNEL=="hidraw*", ATTRS{idVendor}=="2dc8", ATTRS{idProduct}=="6012", MODE="0660"

    # 8BitDo Ultimate 2 Wireless over Bluetooth
    KERNEL=="hidraw*", KERNELS=="*2DC8:6012*", MODE="0660", TAG+="uaccess"
  '';

  programs.vim.enable = true;
  programs.neovim.defaultEditor = true;

  # Keep this even if enabled in home manager
  programs.fish.enable = true;
  environment.shells = [ pkgs.fish ];
  users.defaultUserShell = pkgs.fish;

  # Setup wireguard
  # Set your time zone.
  time.timeZone = "Europe/Helsinki";

  # Select internationalisation properties.
  i18n.defaultLocale = "en_US.UTF-8";

  i18n.extraLocaleSettings = {
    LC_ADDRESS = "zh_CN.UTF-8";
    LC_IDENTIFICATION = "zh_CN.UTF-8";
    LC_MEASUREMENT = "zh_CN.UTF-8";
    LC_MONETARY = "zh_CN.UTF-8";
    LC_NAME = "zh_CN.UTF-8";
    LC_NUMERIC = "zh_CN.UTF-8";
    LC_PAPER = "zh_CN.UTF-8";
    LC_TELEPHONE = "zh_CN.UTF-8";
    LC_TIME = "en_US.UTF-8";
  };

  # ====== GUI ======

  services.desktopManager.plasma6.enable = true;
  # See https://discuss.kde.org/t/no-hdr-available-on-oled-laptop-with-intel-igpu/31580/2,
  # There's many OLED laptop displays where libdisplay-info doesn't yet parse the
  # parts of the EDID that would signal HDR support.
  environment.variables.KWIN_FORCE_ASSUME_HDR_SUPPORT = 1;
  programs.niri.enable = true;
  # Disable gcr-ssh-agent as it does not support ed25519-sk yet
  services.gnome.gcr-ssh-agent.enable = false;
  environment.sessionVariables.NIXOS_OZONE_WL = "1";
  security.pam.services.gtklock = { }; # Required by gtklock
  services.system76-scheduler = {
    enable = true;
  };

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

  programs.regreet = {
    enable = true;
    settings = {
      background.path = "${../../bwmountains.jpg}";
      application_prefer_dark_theme = true;
    };
    theme = {
      name = "Catppuccin-GTK-Dark";
      package = pkgs.magnetic-catppuccin-gtk;
    };
    iconTheme = {
      name = lib.mkForce "Qogir";
      package = lib.mkForce pkgs.qogir-icon-theme;
    };
    cursorTheme = {
      package = pkgs.bibata-cursors;
      name = "Bibata-Modern-Ice";
    };
  };
  services.greetd =
    let
      niri-login-config = pkgs.writeText "niri-login-config.kdl" ''
        animations {
          off
        }
        hotkey-overlay {
          skip-at-startup
        }
        environment {
          GTK_USE_PORTAL "0"
          GDK_DEBUG "no-portals"
        }
        spawn-at-startup "${getExe pkgs.swayidle}" "-w" "timeout" "60" "${getExe pkgs.brightnessctl} -s set 2" "resume" "${getExe pkgs.brightnessctl} -r" "timeout" "300" "${getExe pkgs.niri} msg action power-off-monitors"
        spawn-at-startup "sh" "-c" "${pkgs.regreet}/bin/regreet; niri msg action quit --skip-confirmation"
      '';
    in
    {
      enable = true;
      settings = {
        default_session = {
          command = "${getExe pkgs.niri} -c ${niri-login-config}";
        };
      };
    };

  # Keyboard mapping on internal keyboard
  services.keyd = {
    enable = true;
    keyboards = {
      default = {
        ids = [ "*" ];
        settings = {
          main = {
            capslock = "overload(control, esc)";
            control = "overload(control, esc)";
          };
        };
      };
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
          };
        };
      };
    };
  };

  # Enable CUPS to print documents.
  services.printing.enable = true;
  services.printing.drivers = [
    pkgs.hplip
    pkgs.gutenprint
    pkgs.gutenprintBin
  ];
  hardware.sane = {
    enable = true;
    extraBackends = [ pkgs.hplipWithPlugin ];
  };

  security.rtkit.enable = true;
  services.avahi.enable = true;
  services.pipewire = {
    enable = true;
    wireplumber.enable = true;
    alsa.enable = true;
    pulse.enable = true;
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
      "scanner"
    ];
  };

  # Smart services
  services.smartd.enable = true;

  # Allow unfree packages
  nixpkgs.system = "x86_64-linux";
  nixpkgs.config.allowUnfree = true;
  nixpkgs.config.permittedInsecurePackages = [
    "openssl-1.1.1w"
    "libsoup-2.74.3"
  ];
  environment.systemPackages = with pkgs; [
    # ==== Development ==== #
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

    bibata-cursors

    (epsonscan2.overrideAttrs (
      finalAttrs: prevAttrs: {
        patches = prevAttrs.patches ++ [ ./fix-crash.patch ];
      }
    ))

    virt-manager
    wineWowPackages.waylandFull
    winetricks
  ];

  users.groups.dialout.members = [ "xin" ];

  system.stateVersion = "22.05";

  system.switch.enable = true;

  sops.secrets = {
    "restic/repo_url" = {
      owner = "xin";
      sopsFile = ./secrets.yaml;
    };
    "restic/repo_password" = {
      owner = "xin";
      sopsFile = ./secrets.yaml;
    };
    "davfs2/photosync_password" = {
      sopsFile = ./secrets.yaml;
      mode = "0600";
    };
  };

  sops.templates."davfs2.conf" = {
    owner = config.services.davfs2.davUser;
    content = ''
      https://agate.coho-tet.ts.net:6065/photosync photosync ${
        config.sops.placeholder."davfs2/photosync_password"
      }
    '';
  };

  environment.etc = {
    "davfs2/secrets" = {
      source = config.sops.templates."davfs2.conf".path;
      mode = "0600";
    };
  };

  custom = {
    restic = {
      enable = true;
      paths = [
        "/backup/rootfs/var/lib"
        "/backup/home"
      ];
    };
  };

  # MTP support
  services.gvfs.enable = true;

  services.flatpak.enable = true;

  services.davfs2 = {
    enable = true;
    settings = {
      globalSection = {
        use_locks = 1;
        gui_optimize = 1;
        table_size = 4096;
        cache_size = 10240;
      };
    };
  };

  fileSystems = {
    "/media/photosync" = {
      device = "https://agate.coho-tet.ts.net:6065/photosync";
      fsType = "davfs";
      options = [
        "rw"
        "uid=1000"
        "nodev"
        "nosuid"
        "nofail"
      ];
    };
  };

  # Fonts
  fonts = {
    packages = with pkgs; [
      nerd-fonts.ubuntu-sans
      nerd-fonts.ubuntu
      nerd-fonts.fira-code
      nerd-fonts.fira-mono
      nerd-fonts.jetbrains-mono
      nerd-fonts.roboto-mono
      nerd-fonts.noto
      noto-fonts
      noto-fonts-color-emoji
      liberation_ttf
      mplus-outline-fonts.githubRelease
      dina-font
      proggyfonts
      ubuntu-classic
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

  services.nixseparatedebuginfod2.enable = true;
  services.bloop = {
    install = true;
    extraOptions = [
      "-J-Xmx2G"
      "-J-XX:MaxInlineLevel=20"
      "-J-XX:+UseParallelGC"
    ];
  };
}
