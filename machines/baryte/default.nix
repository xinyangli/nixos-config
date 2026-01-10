{ config, lib, ... }:
{
  imports = [
  ];
  config = {
    nixpkgs.hostPlatform = "aarch64-linux";
    system.stateVersion = "25.05";

    commonSettings = {
      auth.enable = true;
      network.localdns.enable = true;
      serverComponents.enable = true;
    };

    services.openssh.enable = true;
    time.timeZone = "Asia/Shanghai";
  };
}
