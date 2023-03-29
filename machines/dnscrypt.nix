{ config, lib, pkgs, ... }:
{
  services.dnscrypt-proxy2 = {
    enable = true;
    settings = {
      ipv6_servers = false;
      require_dnssec = true;
      sources = {
        public-resolvers = {
          urls = [
            "https://raw.githubusercontent.com/DNSCrypt/dnscrypt-resolvers/master/v3/public-resolvers.md"
            "https://download.dnscrypt.info/resolvers-list/v3/public-resolvers.md"
          ];
          cache_file = "/var/lib/dnscrypt-proxy2/public-resolvers.md";
          minisign_key = "RWQf6LRCGA9i53mlYecO4IzT51TGPpvWucNSCh1CBM0QTaLn73Y7GFO3";
        };
      };
      server_names = [ "cloudflare" "tuna-doh-ipv4" ];
    };
  };

  networking.networkmanager.dns = "none";

  # dns
  systemd.services.dnscrypt-proxy2.serviceConfig = {
    StateDirectory = "dnscrypt-proxy";
  };
}
