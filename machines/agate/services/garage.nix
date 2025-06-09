{ config, pkgs, ... }:
{
  config = {
    sops.secrets = {
      "garage/rpc_secret" = {
        owner = "root";
        mode = "0400";
        sopsFile = ../secrets.yaml;
      };
    };

    sops.templates."garage/env" = {
      content = ''
        GARAGE_RPC_SECRET=${config.sops.placeholder."garage/rpc_secret"}
      '';
    };

    services.garage = {
      enable = true;
      package = pkgs.garage_1_x;
      environmentFile = config.sops.templates."garage/env".path;
      settings = {
        metadata_dir = "/var/lib/garage/meta";
        data_dir = "/storage/garage";

        rpc_bind_addr = "[::]:3901";
        rpc_public_addr = "127.0.0.1:3901";

        s3_api = {
          s3_region = "cn-north-1";
          api_bind_addr = "[::]:3900";
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
      };
    };
  };
}
