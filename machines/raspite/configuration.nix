{
  config,
  lib,
  pkgs,
  ...
}:

{
  imports = [ ./hass.nix ];

  commonSettings = {
    nix.enable = true;
    auth.enable = true;
    comin.enable = true;
  };

  environment.systemPackages = with pkgs; [
    git
    libraspberrypi
    raspberrypi-eeprom
  ];

  system.stateVersion = "24.05";

  networking = {
    hostName = "raspite";
    useDHCP = false;
    interfaces.eth0.useDHCP = true;
  };

  time.timeZone = "Asia/Shanghai";

  # fileSystems."/".fsType = lib.mkForce "btrfs";
  boot.supportedFilesystems.zfs = lib.mkForce false;

  services.tailscale = {
    enable = true;
    permitCertUid = config.services.caddy.user;
    openFirewall = true;
  };
}
