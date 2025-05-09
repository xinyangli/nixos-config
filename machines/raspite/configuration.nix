{
  config,
  lib,
  pkgs,
  ...
}:

{
  imports = [ ./services/hass.nix ];

  commonSettings = {
    nix.enable = true;
    auth.enable = true;
    comin.enable = true;
    network.enableProxy = false;
    serverComponents.enable = true;
  };

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

  time.timeZone = "Asia/Shanghai";
}
