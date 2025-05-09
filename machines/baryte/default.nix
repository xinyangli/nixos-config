{ config, lib, ... }:
{
  imports = [
  ];
  config = {
    nixpkgs.hostPlatform = "aarch64-linux";
    system.stateVersion = "25.05";
    users.users.root.hashedPassword = "$y$j9T$NToEZWJBONjSgRnMd9Ur9/$o6n7a9b8eUILQz4d37oiHCCVnDJ8hZTZt.c.37zFfU.";

    commonSettings = {
      auth.enable = true;
      network.localdns.enable = true;
      serverComponents.enable = true;
    };

    services.openssh.enable = true;
    time.timeZone = "Asia/Shanghai";
  };
}
