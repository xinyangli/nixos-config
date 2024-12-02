{
  lib,
  ...
}:

{
  imports = [
    ./hardware-configurations.nix
    ./services/gotosocial.nix
  ];

  networking.hostName = "biotite";
  networking.useNetworkd = true;
  systemd.network.enable = true;
  systemd.network.networks."10-wan" = {
    matchConfig.MACAddress = "b6:20:0d:9a:6c:34";
    networkConfig = {
      DHCP = "ipv4";
      IPv6SendRA = true;
    };
    address = [ "2a03:4000:4a:148::1/64" ];
  };

  networking.firewall.allowedTCPPorts = [
    80
    443
  ];

  commonSettings = {
    auth.enable = true;
    autoupgrade.enable = true;
  };

  custom.monitoring = {
    promtail.enable = true;
  };

  sops = {
    defaultSopsFile = ./secrets.yaml;
    age.sshKeyPaths = [ "/etc/ssh/ssh_host_ed25519_key" ];
  };

  services.caddy.enable = true;
  services.tailscale.enable = true;

  users.users.root.hashedPassword = "$y$j9T$NToEZWJBONjSgRnMd9Ur9/$o6n7a9b8eUILQz4d37oiHCCVnDJ8hZTZt.c.37zFfU.";

  system.stateVersion = "24.11";
  nixpkgs.hostPlatform = lib.mkDefault "x86_64-linux";
}
