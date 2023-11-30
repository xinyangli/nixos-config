{ config, lib, pkgs, ... }:
let
  server = {
    _secret = config.sops.secrets.singbox_domain.path;
  };
  password = {
    _secret = config.sops.secrets.singbox_password.path;
  };
  uuid = {
    _secret = config.sops.secrets.singbox_password.path;
  };
  sg_server = {
    _secret = config.sops.secrets.singbox_sg_server.path;
  };
  sg_password = {
    _secret = config.sops.secrets.singbox_sg_password.path;
  };
  sg_uuid = {
    _secret = config.sops.secrets.singbox_sg_uuid.path;
  };
in
{
  services.sing-box = {
    enable = true;
    settings = {
      log = { level = "warning"; };
      experimental = {
        clash_api = {
          external_controller = "127.0.0.1:9090";
          store_selected = true;
          external_ui = "${config.nur.repos.linyinfeng.yacd}";
        };
      };
      dns = {
        rules = [
          {
            disable_cache = true;
            geosite = "category-ads-all";
            server = "_dns_block";
          }
          {
            geosite = "cn";
            server = "_dns_doh_mainland";
          }
          {
            domain_suffix = server;
            server = "_dns_doh_mainland";
          }
          {
            domain_suffix = sg_server;
            server = "_dns_doh_mainland";
          }
        ];
        servers = [
          {
            address = "tls://dns.google:853/";
            address_resolver = "_dns_udp_global";
            detour = "_proxy_select";
            tag = "_dns_global";
          }
          {
            address = "1.1.1.1";
            detour = "_proxy_select";
            tag = "_dns_udp_global";
          }
          {
            address = "119.29.29.29";
            detour = "direct";
            tag = "_dns_udp_mainland";
          }
          {
            address = "https://doh.pub/dns-query";
            address_resolver = "_dns_udp_mainland";
            detour = "direct";
            tag = "_dns_doh_mainland";
          }
          {
            address = "rcode://success";
            tag = "_dns_block";
          }
        ];
        final = "_dns_global";
        disable_cache = true;
      };
      inbounds = [
        {
          type = "mixed";
          tag = "mixed-in";
          listen = "127.0.0.1";
          listen_port = 7891;
        }
        {
          type = "tun";
          tag = "tun-in";
          auto_route = true;
          strict_route = false;
          inet4_address = "172.19.0.1/30";
          inet6_address = "fdfe:dcba:9876::1/126";
          sniff = true;
        }
      ];
      route = {
        auto_detect_interface = true;
        final = "_proxy_select";
        rules = [
          { outbound = "dns-out"; protocol = "dns"; }
          {
            geoip = "cn";
            geosite = "cn";
            outbound = "direct";
          }
          { geoip = "private"; outbound = "direct"; }
          {
            domain = sg_server;
            outbound = "direct";
          }
          { 
            geosite = "cn";
            geoip = "cn";
            invert = true;
            outbound = "_proxy_select";
          }
        ];
      };
      outbounds = [ 
        { tag = "selfhost"; type = "urltest"; outbounds = lib.forEach (lib.range 0 4) (id: "sg" + toString id); tolerance = 800; url = "http://www.gstatic.com/generate_204"; interval = "1m0s"; }
        { tag = "sg0"; type = "trojan"; server = sg_server; server_port = 8080; password = sg_password; tls = { enabled = true; server_name = sg_server; utls = { enabled = true; fingerprint = "firefox"; }; }; }
        
        { default = "auto"; outbounds = [ "auto" "selfhost" "direct" "block"]; tag = "_proxy_select"; type = "selector"; }
        { interval = "1m0s"; outbounds = [ "香港SS-01" "香港SS-02" "香港SS-03" "香港SS-04" "日本SS-01" "日本SS-02" "日本SS-03" "美国SS-01" "美国SS-02" "美国SS-03" "台湾SS-01" "台湾SS-02" "台湾SS-03" "台湾SS-04" "香港中继1" "香港中继2" "香港中继3" "香港中继4" "香港中继5" "香港中继6" "香港中继7" "香港中继8" "日本中继1" "日本中继2" "日本中继3" "日本中继4" "美国中继1" "美国中继2" "美国中继3" "美国中继4" "美国中继5" "美国中继6" "美国中继7" "美国中继8" "新加坡中继1" "新加坡中继2" "台湾中继1" "台湾中继2" "台湾中继3" "台湾中继4" "台湾中继5" "台湾中继6" "韩国中继1" "韩国中继2" ]; tag = "auto"; tolerance = 300; type = "urltest"; url = "http://www.gstatic.com/generate_204"; }
        { tag = "direct"; type = "direct"; }
        { tag = "block"; type = "block"; }
        { tag = "dns-out"; type = "dns"; }
        { inherit server password; method = "aes-128-gcm"; server_port = 12001; tag = "香港SS-01"; type = "shadowsocks"; udp_over_tcp = false; }
        { inherit server password; method = "aes-128-gcm"; server_port = 12002; tag = "香港SS-02"; type = "shadowsocks"; udp_over_tcp = false; }
        { inherit server password; method = "aes-128-gcm"; server_port = 12003; tag = "香港SS-03"; type = "shadowsocks"; udp_over_tcp = false; }
        { inherit server password; method = "aes-128-gcm"; server_port = 12004; tag = "香港SS-04"; type = "shadowsocks"; udp_over_tcp = false; }
        { inherit server password; method = "aes-128-gcm"; server_port = 12011; tag = "日本SS-01"; type = "shadowsocks"; udp_over_tcp = false; }
        { inherit server password; method = "aes-128-gcm"; server_port = 12012; tag = "日本SS-02"; type = "shadowsocks"; udp_over_tcp = false; }
        { inherit server password; method = "aes-128-gcm"; server_port = 12013; tag = "日本SS-03"; type = "shadowsocks"; udp_over_tcp = false; }
        { inherit server password; method = "aes-128-gcm"; server_port = 12021; tag = "美国SS-01"; type = "shadowsocks"; udp_over_tcp = false; }
        { inherit server password; method = "aes-128-gcm"; server_port = 12022; tag = "美国SS-02"; type = "shadowsocks"; udp_over_tcp = false; }
        { inherit server password; method = "aes-128-gcm"; server_port = 12023; tag = "美国SS-03"; type = "shadowsocks"; udp_over_tcp = false; }
        { inherit server password; method = "aes-128-gcm"; server_port = 12031; tag = "台湾SS-01"; type = "shadowsocks"; udp_over_tcp = false; }
        { inherit server password; method = "aes-128-gcm"; server_port = 12032; tag = "台湾SS-02"; type = "shadowsocks"; udp_over_tcp = false; }
        { inherit server password; method = "aes-128-gcm"; server_port = 12033; tag = "台湾SS-03"; type = "shadowsocks"; udp_over_tcp = false; }
        { inherit server password; method = "aes-128-gcm"; server_port = 12034; tag = "台湾SS-04"; type = "shadowsocks"; udp_over_tcp = false; }
        { inherit server uuid; security = "auto"; server_port = 1201; tag = "香港中继1"; type = "vmess"; }
        { inherit server uuid; security = "auto"; server_port = 1202; tag = "香港中继2"; type = "vmess"; }
        { inherit server uuid; security = "auto"; server_port = 1203; tag = "香港中继3"; type = "vmess"; }
        { inherit server uuid; security = "auto"; server_port = 1204; tag = "香港中继4"; transport = { path = "/"; type = "ws"; }; type = "vmess"; }
        { inherit server uuid; security = "auto"; server_port = 1205; tag = "香港中继5"; type = "vmess"; }
        { inherit server uuid; security = "auto"; server_port = 1206; tag = "香港中继6"; type = "vmess"; }
        { inherit server uuid; security = "auto"; server_port = 1207; tag = "香港中继7"; type = "vmess"; }
        { inherit server uuid; security = "auto"; server_port = 1208; tag = "香港中继8"; transport = { path = "/"; type = "ws"; }; type = "vmess"; }
        { inherit server uuid; security = "auto"; server_port = 1211; tag = "日本中继1"; type = "vmess"; }
        { inherit server uuid; security = "auto"; server_port = 1212; tag = "日本中继2"; type = "vmess"; }
        { inherit server uuid; security = "auto"; server_port = 1213; tag = "日本中继3"; type = "vmess"; }
        { inherit server uuid; security = "auto"; server_port = 1214; tag = "日本中继4"; type = "vmess"; }
        { inherit server uuid; security = "auto"; server_port = 1231; tag = "美国中继1"; type = "vmess"; }
        { inherit server uuid; security = "auto"; server_port = 1232; tag = "美国中继2"; type = "vmess"; }
        { inherit server uuid; security = "auto"; server_port = 1233; tag = "美国中继3"; type = "vmess"; }
        { inherit server uuid; security = "auto"; server_port = 1234; tag = "美国中继4"; type = "vmess"; }
        { inherit server uuid; security = "auto"; server_port = 1235; tag = "美国中继5"; type = "vmess"; }
        { inherit server uuid; security = "auto"; server_port = 1236; tag = "美国中继6"; type = "vmess"; }
        { inherit server uuid; security = "auto"; server_port = 1237; tag = "美国中继7"; type = "vmess"; }
        { inherit server uuid; security = "auto"; server_port = 1238; tag = "美国中继8"; type = "vmess"; }
        { inherit server uuid; security = "auto"; server_port = 1241; tag = "新加坡中继1"; type = "vmess"; }
        { inherit server uuid; security = "auto"; server_port = 1242; tag = "新加坡中继2"; type = "vmess"; }
        { inherit server uuid; security = "auto"; server_port = 1261; tag = "台湾中继1"; type = "vmess"; }
        { inherit server uuid; security = "auto"; server_port = 1262; tag = "台湾中继2"; type = "vmess"; }
        { inherit server uuid; security = "auto"; server_port = 1263; tag = "台湾中继3"; type = "vmess"; }
        { inherit server uuid; security = "auto"; server_port = 1264; tag = "台湾中继4"; type = "vmess"; }
        { inherit server uuid; security = "auto"; server_port = 1265; tag = "台湾中继5"; type = "vmess"; }
        { inherit server uuid; security = "auto"; server_port = 1266; tag = "台湾中继6"; type = "vmess"; }
        { inherit server uuid; security = "auto"; server_port = 1251; tag = "韩国中继1"; type = "vmess"; }
        { inherit server uuid; security = "auto"; server_port = 1252; tag = "韩国中继2"; type = "vmess"; }
      ] ++ lib.forEach (lib.range 6311 6314) (port: {
        tag = "sg" + toString (port - 6310);
        type = "tuic";
        congestion_control = "bbr";
        server = sg_server;
        server_port = port;
        uuid = sg_uuid;
        password = sg_password;
        tls = { enabled = true; server_name = sg_server; };
      });
    };
  };
}

