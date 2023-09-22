{ config, lib, pkgs, ... }:
{

  systemd.timers."clash-config-update" = {
    wantedBy = [ "timers.target" ];
    timerConfig = {
      OnUnitActiveSec = "1d";
      Unit = "clash-config-update.service";
    };
  };

  systemd.services."clash-config-update" = {
    script = ''
      ${pkgs.curl}/bin/curl $(${pkgs.coreutils}/bin/cat ${config.sops.secrets.clash_subscription_link.path}) > /tmp/config.yaml && mv /tmp/config.yaml /home/xin/.config/clash/ 
    '';
    serviceConfig = {
      Type = "oneshot";
      User= "xin";
    };
  };

  systemd.services.clash = {
    enable = true;
    after = [ "network.target" ];
    wantedBy = [ "multi-user.target" ];
    serviceConfig.ExecStart = "${pkgs.clash}/bin/clash -d /home/xin/.config/clash";
  };
  
}
