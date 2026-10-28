{ config, pkgs, ... }:
{
  sops.templates."caddy.env".content = ''
    DESEC_TOKEN=${config.sops.placeholder."caddy-desec"}
  '';

  services.caddy.package = pkgs.caddy.withPlugins {
    plugins = [
      "github.com/caddy-dns/cloudflare@v0.2.1"
      "github.com/caddy-dns/desec@v1.1.0"
    ];
    hash = "sha256-NsBBmnbBQN1XUfP8QAxvctoewRsyQxe5F+ao9Oh3RUk=";
  };

  systemd.services.caddy.serviceConfig.EnvironmentFile =
    config.sops.templates."caddy.env".path;

  custom.mesh-network.caddy = {
    enable = true;
    ports = [ 443 ];
  };
}
