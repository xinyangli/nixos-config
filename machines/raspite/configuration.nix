{
  config,
  lib,
  pkgs,
  ...
}:

{
  imports = [ ./hass.nix ];

  commonSettings.nix.enableMirrors = true;

  nixpkgs.overlays = [
    # Workaround https://github.com/NixOS/nixpkgs/issues/126755#issuecomment-869149243
    (final: super: {
      makeModulesClosure = x: super.makeModulesClosure (x // { allowMissing = true; });
    })
  ];

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

  # boot.kernelPackages = pkgs.linuxPackages_stable;

  custom.kanidm-client = {
    enable = true;
    uri = "https://auth.xinyang.life";
    asSSHAuth = {
      enable = true;
      allowedGroups = [ "linux_users" ];
      hardening = true;
    };
    sudoers = [ "xin@auth.xinyang.life" ];
  };

  security.sudo = {
    execWheelOnly = true;
    wheelNeedsPassword = false;
  };

  # fileSystems."/".fsType = lib.mkForce "btrfs";
  boot.supportedFilesystems.zfs = lib.mkForce false;

  services.dae.enable = false;
  services.dae.configFile = "/var/lib/dae/config.dae";
}
