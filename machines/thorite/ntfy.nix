{ config, ... }:
let
  inherit (config.my-lib.settings) ntfyUrl;
in
{

  services.ntfy-sh = {
    enable = true;
    group = "caddy";
    settings = {
      listen-unix = "/var/run/ntfy-sh/ntfy.sock";
      listen-unix-mode = 432; # octal 0660
      base-url = ntfyUrl;
    };
  };

  systemd.services.ntfy-sh.serviceConfig.RuntimeDirectory = "ntfy-sh";

  services.caddy.virtualHosts.${ntfyUrl}.extraConfig = ''
    reverse_proxy unix/${config.services.ntfy-sh.settings.listen-unix}
    @httpget {
      protocol http
      method GET
      path_regexp ^/([-_a-z0-9]{0,64}$|docs/|static/)
    }
    redir @httpget https://{host}{uri}
  '';

}
