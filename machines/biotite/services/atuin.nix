{ config, pkgs, ... }:
let
  atuinHost = "atuin.u.xiny.li";
  atuinPort = 443;
in
{
  sops.templates."caddy.env".content = ''
    DESEC_TOKEN=${config.sops.placeholder."caddy-desec"}
  '';

  services.atuin = {
    enable = true;
    openRegistration = false;
    host = "127.0.0.1";
    port = 8888;
  };

  services.caddy = {
    package = pkgs.caddy.withPlugins {
      plugins = [
        "github.com/caddy-dns/desec@v1.1.0"
        "github.com/MayCXC/caddy-systemd-socket-activation@v1.0.0"
      ];
      hash = "sha256-AOvvws5dh2zPoXw3bPeb3FS7BZdZ4LFu4BOO8hBlDxc=";
    };

    virtualHosts."http://".extraConfig = ''
      redir https://{host}{uri} permanent
    '';

    virtualHosts."https://${atuinHost}".extraConfig = ''
      bind ${config.custom.mesh-network.caddy.fdRefs."${toString atuinPort}"}
      tls {
        dns desec {
          token {env.DESEC_TOKEN}
        }
        propagation_delay 1m
        propagation_timeout 15m
        dns_ttl 1m
      }
      reverse_proxy 127.0.0.1:${toString config.services.atuin.port}
    '';
  };

  systemd.services.caddy.serviceConfig.EnvironmentFile = config.sops.templates."caddy.env".path;

  systemd.services.postgresql-setup = {
    preStart = ''
      if [ "$(${config.services.postgresql.package}/bin/psql -d postgres -tAc "SELECT 1 FROM pg_database WHERE datname = 'atuin'")" != "1" ]; then
        ${config.services.postgresql.package}/bin/psql -d postgres -v ON_ERROR_STOP=1 -c 'CREATE DATABASE "atuin" TEMPLATE template0'
      fi
    '';
    serviceConfig = {
      Restart = "on-failure";
      RestartSec = "5s";
    };
  };

  custom.mesh-network.caddy = {
    enable = true;
    ports = [ atuinPort ];
    publicPorts = [ 443 ];
  };
}
