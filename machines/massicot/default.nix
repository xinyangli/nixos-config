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

  services.openssh = {
    enable = true;
    settings = {
      PasswordAuthentication = false;
    };
  };
  
  systemd.services.sshd.wantedBy = pkgs.lib.mkForce [ "multi-user.target" ];
  
  users.users.xin = {
    isNormalUser = true;
    extraGroups = [ "wheel" "networkmanager" ];
    openssh.authorizedKeys.keys = [
        "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIPBcSvUQnmMFtpftFKIsDqeyUyZHzRg5ewgn3VEcLnss"
        "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIInPn+7cMbH7zCEPJArU/Ot6oq8NHo8a2rYaCfTp7zgd"
        "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIPeNQ43f/ce4VxVPsAaKPPTp8rokQpmwNIsOX7JBZq4A"
    ];
    hashedPassword = "$y$j9T$JOJn97hZndiDamUmmT.iq.$ue7gNZz/b14ur8GhyutOCvFjsv.3rcsHmk7m.WRk6u7";
  };

  security.sudo.extraRules = [
    { users = [ "xin" ];
      commands = [ { command = "ALL"; options = [ "NOPASSWD" ]; } ];
    }
  ];

  
}
