{ config, libs, pkgs, ... }:

{
  imports = [
    ./hardware-configuration.nix
    ./networking.nix
    ./services.nix
  ];

  boot.loader.efi.canTouchEfiVariables = true;
  boot.loader.efi.efiSysMountPoint = "/boot";
  boot.loader.grub = {
    enable = true;
    efiSupport = true;
  };

  environment.systemPackages = with pkgs; [
    git
  ];

  nix.settings.experimental-features = [ "nix-command" "flakes" ];

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
  programs.mosh.enable = true;
  
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
