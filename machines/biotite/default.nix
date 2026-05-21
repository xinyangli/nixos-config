{
  pkgs,
  lib,
  config,
  ...
}:

{
  imports = [
    ./hardware-configurations.nix
    ./services/gotosocial.nix
    ./services/synapse.nix
    ./services/restic.nix
    ./services/mailserver.nix
    ./services/miniflux.nix
    ./services/hedgedoc.nix
    ./services/forgejo.nix
    ./services/vaultwarden.nix
    ./services/kanidm.nix
    ./services/rustical.nix
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
    comin.enable = true;
    serverComponents.enable = true;
  };

  custom.mesh-network = {
    ipsec = {
      enable = true;
      commonName = "biotite";
      endpoints = [
        {
          serialNumber = "0";
          addressFamily = "ip4";
          address = "45.142.178.32";
        }
      ];
      interfaces = [ "ens3" ];
    };
    bird.enable = true;
    address = [ "fda1:6cbb:db78::4/128" ];
  };

  sops = {
    defaultSopsFile = ./secrets.yaml;
    age.sshKeyPaths = [ "/etc/ssh/ssh_host_ed25519_key" ];
  };

  services.postgresql = {
    enable = true;
    package = pkgs.postgresql_17;
    settings = {
      allow_alter_system = false;
      # DB Version: 17
      # OS Type: linux
      # DB Type: mixed
      # Total Memory (RAM): 8 GB
      # CPUs num: 4
      # Data Storage: ssd
      max_connections = 100;
      shared_buffers = "2GB";
      effective_cache_size = "6GB";
      maintenance_work_mem = "512MB";
      checkpoint_completion_target = 0.9;
      wal_buffers = "16MB";
      default_statistics_target = 100;
      random_page_cost = 1.1;
      effective_io_concurrency = 200;
      work_mem = "5242kB";
      huge_pages = "off";
      min_wal_size = "1GB";
      max_wal_size = "4GB";
      max_worker_processes = 4;
      max_parallel_workers_per_gather = 2;
      max_parallel_workers = 4;
      max_parallel_maintenance_workers = 2;
    };
  };

  system.stateVersion = "24.11";
  nixpkgs.hostPlatform = lib.mkDefault "x86_64-linux";
}
