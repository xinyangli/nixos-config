{
  inputs,
  pkgs,
  ...
}:

{
  imports = [
    inputs.sops-nix.nixosModules.sops
    ./hardware-configuration.nix
    ./networking.nix
    ./services.nix
    ./services
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
      grafana_oauth_secret = {
        owner = "grafana";
      };
      "miniflux/oauth2_secret" = {
        owner = "root";
      };
      "forgejo/env" = {
        owner = "forgejo";
      };
    };
  };

  boot.loader.efi.canTouchEfiVariables = true;
  boot.loader.efi.efiSysMountPoint = "/boot";
  boot.loader.grub = {
    enable = true;
    efiSupport = true;
    configurationLimit = 5;
  };
  environment.systemPackages = with pkgs; [
    cifs-utils
    git
  ];

  # Disable docs on servers
  documentation.nixos.enable = false;
  documentation.man.enable = false;

  system.stateVersion = "22.11";

  networking = {
    hostName = "massicot";
  };

  commonSettings = {
    auth.enable = true;
    nix = {
      enable = true;
    };
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
