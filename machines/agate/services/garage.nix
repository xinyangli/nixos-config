{ config, pkgs, ... }:
let
  inherit (config.my-lib.settings) garageFactor;
in
{
  config = {
    sops.secrets = {
      "garage/rpc_secret" = {
        mode = "0400";
        sopsFile = ../secrets.yaml;
      };
      "garage/admin_token" = {
        mode = "0400";
        sopsFile = ../secrets.yaml;
      };
    };

    sops.templates."garage/env" = {
      content = ''
        GARAGE_RPC_SECRET=${config.sops.placeholder."garage/rpc_secret"}
        GARAGE_ADMIN_TOKEN=${config.sops.placeholder."garage/admin_token"}
      '';
    };

    systemd.services.garage.serviceConfig = {
      BindPaths = [
        "/storage/garage:/var/lib/garage/data"
      ];
      SupplementaryGroups = [ "garage-data" ];
    };

    users.groups.garage-data = { };

    services.garage = {
      enable = true;
      package = pkgs.garage_2;
      environmentFile = config.sops.templates."garage/env".path;
      settings = {
        metadata_dir = "/var/lib/garage/meta";
        data_dir = "/var/lib/garage/data";

        replication_factor = garageFactor;
        rpc_bind_addr = "127.0.0.1:3901";
        rpc_public_addr = "127.0.0.1:3901";

        s3_api = {
          s3_region = "cn-north-1";
          api_bind_addr = "127.0.0.1:3900";
          root_domain = ".s3.garage.localhost";
        };
        # s3_web = {
        #   bind_addr = "[::]:3902";
        #   root_domain = ".web.garage.localhost";
        #   index = "index.html";
        # };
        # k2v_api = {
        #   api_bind_addr = "[::]:3904";
        # };
        admin = {
          api_bind_addr = "127.0.0.1:3903";
        };
      };
    };

    services.caddy.virtualHosts."pek-0.garage.xiny.li:8443".extraConfig = ''
      tls {
        dns cloudflare {env.CF_API_TOKEN}
      }
      reverse_proxy 127.0.0.1:3900
    '';
  };
}
