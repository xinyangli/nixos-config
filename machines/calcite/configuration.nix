{ config, pkgs, ... }:

{
  imports =
    [
      # Include the results of the hardware scan.
      ./hardware-configuration.nix
      ./network.nix
      ../sops.nix
      ../clash.nix
    ];

  # Bootloader.
  boot.loader.systemd-boot.enable = true;
  boot.loader.efi.canTouchEfiVariables = true;
  boot.loader.efi.efiSysMountPoint = "/boot/efi";
  # boot.kernelPackages = pkgs.linuxPackages_latest;
  boot.kernelModules = [ "nvidia" "nvidia_modeset" "nvidia_uvm" ];
  boot.supportedFilesystems = [ "ntfs" ];

  networking.hostName = "calcite";

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
    layout = "us";
    xkbVariant = "";
  };

  # Enable CUPS to print documents.
  services.printing.enable = true;
  services.printing.drivers = [ pkgs.hplip ];

  # Enable sound with pipewire.
  sound.enable = true;
  hardware.pulseaudio.enable = false;
  security.rtkit.enable = true;
  services.pipewire = {
    enable = true;
    wireplumber.enable = true;
    alsa.enable = true;
    #alsa.support32Bit = true;
    pulse.enable = true;
    # If you want to use JACK applications, uncomment this
    jack.enable = true;
  };

  # Define a user account. Don't forget to set a password with ‘passwd’.
  users.users.xin = {
    isNormalUser = true;
    description = "xin";
    extraGroups = [ "networkmanager" "wheel" "wireshark" ];
  };

  # Enable automatic login for the user.
  services.xserver.displayManager.autoLogin.enable = true;
  services.xserver.displayManager.autoLogin.user = "xin";

  # Workaround for GNOME autologin: https://github.com/NixOS/nixpkgs/issues/103746#issuecomment-945091229
  systemd.services."getty@tty1".enable = false;
  systemd.services."autovt@tty1".enable = false;

  # Allow unfree packages
  nixpkgs.config.allowUnfree = true;
  nixpkgs.config.permittedInsecurePackages = [
    # For wechat-uos
    "electron-19.0.7"
  ];
  # List packages installed in system profile. To search, run:
  # $ nix search wget
  environment.systemPackages = with pkgs; [
    # Filesystem
    nfs-utils

    winetricks
    wineWowPackages.waylandFull
    faudio

    # ==== CLI tools ==== #
    rust-analyzer

    # tesseract5 # ocr
    ocrmypdf # pdfocr

    grc

    # ==== Development ==== #
    # VCS
    git-crypt

    jetbrains.jdk # patch jetbrain runtime java
    jetbrains.clion
    jetbrains.pycharm-professional
    jetbrains.idea-ultimate
    android-studio

    # Language server
    clang-tools
    rnix-lsp

    # C/C++
    gcc
    gdb

    # Python
    # reference: https://nixos.wiki/wiki/Python
    (
      let
        my-python-packages = python-packages: with python-packages; [
          pandas
          requests
          numpy
          pyyaml
        ];
        python-with-my-packages = python3.withPackages my-python-packages;
      in
      python-with-my-packages
    )

    # Tex
    texlive.combined.scheme-full

    # ==== GUI Softwares ==== #
    # Gnome tweaks
    gnomeExtensions.dash-to-dock
    gnomeExtensions.hide-top-bar
    gnomeExtensions.tray-icons-reloaded
    gnome.gnome-tweaks
    gthumb

    steam

    # Multimedia
    vlc
    obs-studio
    spotify

    digikam

    # IM
    tdesktop
    qq
    config.nur.repos.xddxdd.wechat-uos

    # Mail
    thunderbird

    # Password manager
    keepassxc

    # Browser
    firefox
    chromium
    microsoft-edge

    # Writting
    obsidian
    zotero
    wpsoffice

    config.nur.repos.linyinfeng.wemeet

    virt-manager
  ];

  programs.steam = {
    enable = true;
  };

  system.stateVersion = "22.05";

  # Use mirror for binary cache
  nix.settings.substituters = [
    "https://mirrors.ustc.edu.cn/nix-channels/store"
    "https://mirrors.tuna.tsinghua.edu.cn/nix-channels/store"
  ];
  nix.settings.experimental-features = [ "nix-command" "flakes" ];

  # MTP support
  services.gvfs.enable = true;

  # Fonts
  fonts = {
    fonts = with pkgs; [
      (nerdfonts.override { fonts = [ "FiraCode" ]; })
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
        serif = [ "Noto Serif CJK SC" "Ubuntu" ];
        sansSerif = [ "Noto Sans CJK SC" "Ubuntu" ];
        monospace = [ "FiraCode NerdFont Mono" "Ubuntu" ];
      };
    };
  };
  # Virtualization
  virtualisation = {
    libvirtd.enable = true;
    podman = {
      enable = true;
      enableNvidia = true;
    };
    docker = {
      enable = true;
      enableNvidia = true;
      autoPrune.enable = true;
    };
  };
}
