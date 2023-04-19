# Edit this configuration file to define what should be installed on
# your system.  Help is available in the configuration.nix(5) man page
# and in the NixOS manual (accessible by running ‘nixos-help’).

{ config, pkgs, nixos-cn, nur, nur-xddxdd, ... }:

{
  imports =
    [
      # Include the results of the hardware scan.
      ./hardware-configuration.nix
      ../clash.nix
      ../vscode.nix
      # ../dnscrypt.nix
      ./secret.nix
      ../sops.nix
    ];

  # Bootloader.
  boot.loader.systemd-boot.enable = true;
  boot.loader.efi.canTouchEfiVariables = true;
  boot.loader.efi.efiSysMountPoint = "/boot/efi";
  # boot.kernelPackages = pkgs.linuxPackages_latest;
  boot.kernelModules = [ "nvidia" "nvidia_modeset" "nvidia_uvm" ];

  networking.hostName = "xin-laptop"; # Define your hostname.

  # Enable networking
  networking = {
    nameservers = [ "127.0.0.1" "::1" ];
    networkmanager = {
      enable = true;
    };
    resolvconf.useLocalResolver = true;
  };

  
  sops = {
    defaultSopsFile = ./secrets.yaml;
    age.sshKeyPaths = [ "/etc/ssh/ssh_host_ed25519_key" ];
    age.keyFile = "/var/lib/sops-nix/keys.txt";
    age.generateKey = true;
  };

  # Setup wireguard
  # Set your time zone.
  time.timeZone = "Asia/Shanghai";

  # Select internationalisation properties.
  i18n.defaultLocale = "en_US.utf8";

  # Chinese Input Method
  i18n.inputMethod = {
    enabled = "fcitx5";
    fcitx5.addons = with pkgs; [ fcitx5-rime ];
  };

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
  # List packages installed in system profile. To search, run:
  # $ nix search wget
  environment.systemPackages = with pkgs; [
    # Filesystem
    nfs-utils

    winetricks
    wineWowPackages.waylandFull
    faudio

    man-pages
    # ==== CLI tools ==== #
    rust-analyzer
    leetcode-cli

    tree
    wget
    tmux
    ffmpeg
    tealdeer
    neofetch
    rclone
    clash
    # tesseract5 # ocr
    ocrmypdf # pdfocr

    grc
    fishPlugins.pisces
    fishPlugins.bass
    fishPlugins.done

    hyperfine # benchmarking tool
    grex # generate regex from example
    delta # diff viewer
    zoxide # autojumper
    du-dust # du + rust
    alacritty # terminal emulator
    zellij # modern multiplexer

    # ==== Development ==== #
    # VCS
    git
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
    netease-cloud-music-gtk

    digikam

    # IM
    tdesktop
    qq
    nur-xddxdd.packages."x86_64-linux".wechat-uos-bin
    # nixos-cn.legacyPackages.${system}.wechat-uos

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
  # use vim for editor
  programs.vim = {
    defaultEditor = true;
  };

  # use fish as default shell
  environment.shells = [ pkgs.fish ];
  users.defaultUserShell = pkgs.fish;
  programs.fish = {
    enable = true;
  };

  programs.wireshark = {
    enable = true;
    package = pkgs.wireshark-qt;
  };

  # Add gsconnect, open firewall
  programs.kdeconnect = {
    enable = true;
    package = pkgs.gnomeExtensions.gsconnect;
  };

  programs.steam = {
    enable = true;
    remotePlay.openFirewall = true;
  };
  # Some programs need SUID wrappers, can be configured further or are
  # started in user sessions.
  # programs.mtr.enable = true;
  # programs.gnupg.agent = {
  #   enable = true;
  #   enableSSHSupport = true;
  # };

  # List services that you want to enable:

  # Enable the OpenSSH daemon.
  # services.openssh.enable = true;

  # services.gnome.gnome-remote-desktop.enable = true;

  # Open ports in the firewall.
  # networking.firewall.allowedTCPPorts = [ ... ];
  networking.firewall.allowedUDPPorts = [ 41641 ];
  # Or disable the firewall altogether.
  # networking.firewall.enable = false;

  # This value determines the NixOS release from which the default
  # settings for stateful data, like file locations and database versions
  # on your system were taken. It‘s perfectly fine and recommended to leave
  # this value at the release version of the first install of this system.
  # Before changing this value read the documentation for this option
  # (e.g. man configuration.nix or on https://nixos.org/nixos/options.html).
  system.stateVersion = "22.05"; # Did you read the comment?

  # Use mirror for binary cache
  nix.settings.substituters = [
    "https://mirrors.ustc.edu.cn/nix-channels/store"
    # "https://mirrors.tuna.tsinghua.edu.cn/nix-channels/store"
  ];
  nix.settings.experimental-features = [ "nix-command" "flakes" ];

  # MTP support
  services.gvfs.enable = true;

  # Enable Tailscale
  services.tailscale.enable = true;
  services.tailscale.useRoutingFeatures = "both";

  # Setup Nvidia driver
  services.xserver.videoDrivers = [ "nvidia" ];
  hardware.opengl = {
    enable = true;
    # driSupport = true;
  };
  hardware.nvidia.modesetting.enable = true;
  hardware.nvidia.package = config.boot.kernelPackages.nvidiaPackages.stable;
  # hardware.nvidia.open = true;
  hardware.nvidia.prime = {
    offload.enable = true;
    offload.enableOffloadCmd = true;
    nvidiaBusId = "PCI:1:0:0";
    amdgpuBusId = "PCI:4:0:0";
  };

  # Fonts
  fonts = {
    fonts = with pkgs; [
      noto-fonts
      noto-fonts-emoji
      liberation_ttf
      fira-code
      fira-code-symbols
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
        monospace = [ "FiraCode" "Ubuntu" ];
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
