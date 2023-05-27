{ config, lib, pkgs, ... }:
{
  sops = {
    secrets.clash_subscription_link = { 
      owner = "xin";
    };
  };

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
      ${pkgs.gnused}/bin/sed -i 's/enable: false/enable: true/g; s/log-level: info/log-level: warning/g' /home/xin/.config/clash/config.yaml
      ${pkgs.gnused}/bin/sed -i '0,/proxies/s/114.114.114.114/https:\/\/dns.alidns.com\/dns-query/g; 0,/proxies/s/119.29.29.29/tls:\/\/dns.tuna.tsinghua.edu.cn:8853/g' /home/xin/.config/clash/config.yaml
      ${pkgs.gnused}/bin/sed -i 's/dns:/dns: \n  nameserver-policy:\n     +.ts.net: "100.100.100.100"/g; s/log-level: info/log-level: warning/g' /home/xin/.config/clash/config.yaml
      ${pkgs.gnused}/bin/sed -i 's/www.gstatic.cn/www.google.com/g' /home/xin/.config/clash/config.yaml
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
