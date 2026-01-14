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
            url = "https://github.com/wrvsrx/niri/compare/tag_support-shm-sharing_2~19..tag_support-shm-sharing_2.patch";
            hash = "sha256-RIy6scbIHGlngu28O7nwhN8FF9x5eHUIGhPC48DKQGc=";
          })
        ];
      };
    })
  ];

  commonSettings = {
    auth = {
      enable = true;
      enableHowdy = true;
    };
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

  system.nixos-init.enable = true;
  system.etc.overlay.enable = true;
  services.userborn.enable = true;

  boot.kernelPackages = pkgs.linuxPackages_latest;
  services.scx = {
    enable = true;
    scheduler = "scx_lavd";
  };
  boot.binfmt.emulatedSystems = [ "aarch64-linux" ];
  boot.kernelModules = [ "acpi_call" ];
  boot.extraModulePackages = [
    config.boot.kernelPackages.acpi_call
    (pkgs.callPackage ./camera_led_kernel_module.nix { kernel = config.boot.kernelPackages.kernel; })
  ];

  # Bootloader.
  boot = {
    plymouth.enable = true;

    # Enable "Silent boot"
    consoleLogLevel = 3;
    initrd.verbose = false;
    initrd.availableKernelModules = [ "xe" ];
    initrd.systemd.services.cryptsetup-timeout = {
      # man systemd-cryptsetup@.service
      # https://github.com/NixOS/nixpkgs/blob/nixos-25.05/nixos/modules/system/boot/systemd/initrd.nix
      # https://blog.decent.id/post/nixos-systemd-initrd/
      # https://discourse.nixos.org/t/migrating-to-boot-initrd-systemd-and-debugging-stage-1-systemd-services/54444/7
      # As root: nix shell nixpkgs#dracut, lsinitrd /boot/EFI/nixos/...
      wantedBy = [ "sysinit.target" ];
      bindsTo = [ "systemd-cryptsetup@crypted.service" ];
      unitConfig.DefaultDependencies = "no";
      serviceConfig = {
        Type = "oneshot";
        ExecStart = "/bin/sh -c 'sleep 180 && systemctl poweroff'";
      };
    };
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
    applyUdevRules = false;
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
    # FIXME: Upstream (systemd) does not allow regular users to own device nodes, which makes
    # managing tss group with kanidm impossible. Use uaccess tag here to avoid specifying a group
    # See https://github.com/systemd/systemd/issues/39056
    KERNEL=="tpm[0-9]*", TAG+="systemd", MODE="0660"
    KERNEL=="tpmrm[0-9]*", TAG+="systemd", TAG+="uaccess", MODE="0660"

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
  # See https://discuss.kde.org/t/no-hdr-available-on-oled-laptop-with-intel-igpu/31580/2,
  # There's many OLED laptop displays where libdisplay-info doesn't yet parse the
  # parts of the EDID that would signal HDR support.
  environment.variables.KWIN_FORCE_ASSUME_HDR_SUPPORT = 1;
  programs.niri.enable = true;
  # Disable gcr-ssh-agent as it does not support ed25519-sk yet
  services.gnome.gcr-ssh-agent.enable = false;
  environment.sessionVariables.NIXOS_OZONE_WL = "1";
  security.pam.services.gtklock = { }; # Required by gtklock
  catppuccin = {
    enable = true;
    accent = "peach";
    flavor = "mocha";
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
    enable = false;
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
    # kdePackages.kwin
    # kdePackages.kscreen
    # kdePackages.libkscreen
    # kdePackages.kcmutils
    # kdePackages.kscreenlocker
    # kdePackages.kglobalacceld
    # kdePackages.kde-cli-tools
    # kdePackages.knewstuff
    # kdePackages.systemsettings
    # kdePackages.powerdevil

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
    gparted
    bibata-cursors

    # TODO: Wait for https://github.com/NixOS/nixpkgs/pull/475916
    # (epsonscan2.overrideAttrs (
    #   finalAttrs: prevAttrs: {
    #     patches = prevAttrs.patches ++ [ ./fix-crash.patch ];
    #   }
    # ))

    virt-manager
    # wineWowPackages.waylandFull
    # winetricks
    # bottles
  ];

  system.stateVersion = "22.05";

  sops.secrets = {
    "restic/repo_url" = {
      owner = "xin";
      sopsFile = ./secrets.yaml;
    };
    "restic/repo_password" = {
      owner = "xin";
      sopsFile = ./secrets.yaml;
    };
  };

  # MTP support
  services.gvfs.enable = true;

  services.flatpak.enable = true;

  # Fonts
  fonts = {
    packages = with pkgs; [
      nerd-fonts.noto
      source-han-sans
      source-han-serif
    ];
    fontconfig = {
      hinting.enable = true;
      useEmbeddedBitmaps = true;
    };
    enableDefaultPackages = false;
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
}
