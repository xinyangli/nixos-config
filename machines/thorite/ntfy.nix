{ config, ... }:
let
  inherit (config.my-lib.settings) ntfyUrl;

  cominBcrypt = "$2a$10$elJoaRScjUm9r1UIXlqllur/8H/PDfTKbgs6d/ygFmBgRTp.H/Ewe";
  agentsBcrypt = "$2a$10$EeYzKuPMq1yrtHToXabWdeBw5Iiz1dSau6tZbyn0Cq2vFPtOyFMsO";
in
{

  services.ntfy-sh = {
    enable = true;
    group = "caddy";
    settings = {
      listen-unix = "/var/run/ntfy-sh/ntfy.sock";
      listen-unix-mode = 432; # octal 0660
      base-url = ntfyUrl;
      enable-login = true;
      auth-file = "/var/lib/ntfy-sh/user.db";
      auth-default-access = "read-write";
      auth-users = [
        "comin:${cominBcrypt}:user"
        "agents:${agentsBcrypt}:user"
      ];
      auth-access = [
        "comin:comin-reboot:rw"
        "agents:agent-notify:rw"
        "agents:agent-notify-reply:rw"
        "everyone:comin-reboot:deny"
        "everyone:agent-notify:deny"
        "everyone:agent-notify-reply:deny"
      ];
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
