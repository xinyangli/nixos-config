{ inputs, config, libs, pkgs, ... }:

{
  imports = [
    inputs.sops-nix.nixosModules.sops
    ./hardware-configuration.nix
    ./networking.nix
    ./services.nix
  ];
  
  sops = {
    defaultSopsFile = ./secrets.yaml;
    age.sshKeyPaths = [ "/etc/ssh/ssh_host_ed25519_key" ];
    secrets = {
      storage_box_mount = {
        owner = "root";
      };
      gts_env = {
        owner = "gotosocial";
      };
      hedgedoc_env = {
        owner = "hedgedoc";
      };
      grafana_cloud_api = {
        owner = "prometheus";
        sopsFile = ../secrets.yaml;
      };
    };
  };

  boot.loader.efi.canTouchEfiVariables = true;
  boot.loader.efi.efiSysMountPoint = "/boot";
  boot.loader.grub = {
    enable = true;
    efiSupport = true;
  };

  fileSystems."/mnt/storage" = {
    device = "//u380335-sub1.your-storagebox.de/u380335-sub1";
    fsType = "cifs";
    options = ["credentials=${config.sops.secrets.storage_box_mount.path}"];
  };

  environment.systemPackages = with pkgs; [
    cifs-utils
    git
  ];

  nix.settings.experimental-features = [ "nix-command" "flakes" ];
  nix.gc = {
    automatic = true;
    dates = "weekly";
    options = "--delete-older-than 7d";
  };
  nix.optimise.automatic = true;
  nix.settings.auto-optimise-store = true;


  system.stateVersion = "22.11";
  
  networking = {
    hostName = "massicot";
  };

  custom.kanidm-client = {
    enable = true;
    uri = "https://auth.xinyang.life/";
    asSSHAuth = {
      enable = true;
      allowedGroups = [ "linux_users" ];
    };
    sudoers = [ "xin@auth.xinyang.life" ];
  };

  security.sudo = {
      execWheelOnly = true;
      wheelNeedsPassword = false;
    };

  services.openssh = {
    enable = true;
    settings = {
      PasswordAuthentication = false;
      KbdInteractiveAuthentication = false;
      PermitRootLogin = "no";
      GSSAPIAuthentication = "no";
      KerberosAuthentication = "no";
    };
  };
  services.fail2ban.enable = true;
  programs.mosh.enable = true;
  
  systemd.services.sshd.wantedBy = pkgs.lib.mkForce [ "multi-user.target" ];
}
