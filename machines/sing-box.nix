{ config, lib, pkgs, ... }:
let
  password = {
    _secret = config.sops.secrets.singbox_password.path;
  };
  uuid = {
    _secret = config.sops.secrets.singbox_uuid.path;
  };
  sg_server = {
    _secret = config.sops.secrets.singbox_sg_server.path;
  };
  jp_server = {
    _secret = config.sops.secrets.singbox_jp_server.path;
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
            disable_cache = false;
            domain_suffix = sg_server;
            server = "_dns_doh_mainland";
          }
          {
            disable_cache = false;
            domain_suffix = jp_server;
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
            address = "tls://1.12.12.12:853/";
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
        strategy = "prefer_ipv4";
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
        { tag = "selfhost"; type = "urltest"; outbounds = lib.forEach (lib.range 0 4) (id: "jp" + toString id) ++ lib.forEach (lib.range 0 4) (id: "sg" + toString id); tolerance = 50; url = "http://cp.cloudflare.com/"; }
        { tag = "sg0"; type = "trojan"; server = sg_server; server_port = 8080; password = password; tls = { enabled = true; server_name = sg_server; utls = { enabled = true; fingerprint = "firefox"; }; }; }
        { tag = "jp0"; type = "trojan"; server = jp_server; server_port = 8080; password = password; tls = { enabled = true; server_name = jp_server; utls = { enabled = true; fingerprint = "firefox"; }; }; }
        { default = "auto"; outbounds = [ "selfhost" "direct" "block"]; tag = "_proxy_select"; type = "selector"; }
        { tag = "direct"; type = "direct"; }
        { tag = "block"; type = "block"; }
        { tag = "dns-out"; type = "dns"; }
      ] ++ lib.forEach (lib.range 6311 6314) (port: {
        inherit uuid password;
        tag = "sg" + toString (port - 6310);
        type = "tuic";
        congestion_control = "bbr";
        server = sg_server;
        server_port = port;
        tls = { enabled = true; server_name = sg_server; };
      }) ++ lib.forEach (lib.range 6311 6314) (port: {
        inherit uuid password;
        tag = "jp" + toString (port - 6310);
        type = "tuic";
        congestion_control = "bbr";
        server = jp_server;
        server_port = port;
        tls = { enabled = true; server_name = jp_server; };
      });
    };
  };
}

