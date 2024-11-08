{
  config,
  pkgs,
  lib,
  ...
}:

{
  imports = [
    # Include the results of the hardware scan.
    ./hardware-configuration.nix
    ./network.nix
    ../sops.nix
  ];

  commonSettings = {
    auth.enable = true;
    nix = {
      enableMirrors = true;
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

  security.tpm2 = {
    enable = true;
    # expose /run/current-system/sw/lib/libtpm2_pkcs11.so
    pkcs11.enable = true;
    # TODO: Need this until fapi-config is fixed in NixOS
    pkcs11.package = pkgs.tpm2-pkcs11.override { fapiSupport = false; };
    # TPM2TOOLS_TCTI and TPM2_PKCS11_TCTI env variables
    tctiEnvironment.enable = true;
  };
  services.gnome.gnome-keyring.enable = lib.mkForce false;
  security.pam.services.login.enableGnomeKeyring = lib.mkForce false;
  services.ssh-tpm-agent.enable = true;

  programs.ssh.agentPKCS11Whitelist = "${config.security.tpm2.pkcs11.package}/lib/libtpm_pkcs11.so";

  networking.hostName = "calcite";

  programs.steam = {
    enable = true;
    gamescopeSession = {
      enable = true;
    };
  };

  programs.oidc-agent.enable = true;
  programs.oidc-agent.providers = [
    {
      issuer = "https://home.xinyang.life:9201";
      pubclient = {
        client_id = "xdXOt13JKxym1B1QcEncf2XDkLAexMBFwiT9j6EfhhHFJhs2KM9jbjTmf8JBXE69";
        client_secret = "UBntmLjC2yYCeHwsyj73Uwo9TAaecAetRwMw0xYcvNL9yRdLSUi0hUAHfvCHFeFh";
        scope = "openid offline_access profile email";
      };
    }
  ];

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

  # Enable the X11 windowing system.
  services.xserver.enable = true;

  # Enable the GNOME Desktop Environment.
  services.xserver.displayManager.gdm.enable = true;
  services.xserver.desktopManager.gnome.enable = true;

  # Configure keymap in X11
  services.xserver = {
    xkb.layout = "us";
    xkb.variant = "";
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

  # Enable automatic login for the user.
  services.displayManager.autoLogin.enable = true;
  services.displayManager.autoLogin.user = "xin";

  # Smart services
  services.smartd.enable = true;

  # Workaround for GNOME autologin: https://github.com/NixOS/nixpkgs/issues/103746#issuecomment-945091229
  systemd.services."getty@tty1".enable = false;
  systemd.services."autovt@tty1".enable = false;

  # Allow unfree packages
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

    # Gnome tweaks
    gnomeExtensions.paperwm
    gnomeExtensions.search-light
    gnomeExtensions.appindicator
    gnomeExtensions.pano
    gnome-tweaks
    gnome-themes-extra
    gnome-remote-desktop
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
    qq
    wechat-uos
    feishu

    # Password manager
    bitwarden

    # Browser
    (chromium.override {
      commandLineArgs = [
        "--ozone-platform-hint=auto"
        "--enable-wayland-ime"
      ];
    })
    brave

    # Writting
    zotero
    # onlyoffice-bin
    wpsoffice
    zed-editor

    config.nur.repos.linyinfeng.wemeet

    virt-manager
  ];

  system.stateVersion = "22.05";

  system.switch.enable = false;
  system.switch.enableNg = true;

  nix.extraOptions = ''
    !include "${config.sops.secrets.github_public_token.path}"
  '';

  sops.secrets = {
    restic_repo_calcite_password = {
      owner = "xin";
      sopsFile = ./secrets.yaml;
    };
    restic_repo_calcite = {
      owner = "xin";
      sopsFile = ./secrets.yaml;
    };
    sing_box_url = {
      owner = "root";
      sopsFile = ./secrets.yaml;
    };
    "gitea/envfile" = {
      owner = "root";
      sopsFile = ./secrets.yaml;
    };
  };
  custom.restic.enable = true;
  custom.restic.repositoryFile = config.sops.secrets.restic_repo_calcite.path;
  custom.restic.passwordFile = config.sops.secrets.restic_repo_calcite_password.path;

  custom.forgejo-actions-runner.enable = false;
  custom.forgejo-actions-runner.tokenFile = config.sops.secrets."gitea/envfile".path;

  custom.prometheus = {
    enable = true;
    exporters.blackbox.enable = true;
  };

  custom.stylix.enable = true;

  services.ollama = {
    enable = true;
    acceleration = "cuda";
  };

  # MTP support
  services.gvfs.enable = true;

  # Fonts
  fonts = {
    packages = with pkgs; [
      (nerdfonts.override {
        fonts = [
          "FiraCode"
          "FiraMono"
          "JetBrainsMono"
        ];
      })
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
