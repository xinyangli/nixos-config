{ config, lib, ... }:
let
  databaseName = config.services.atticd.user;
in
{
  sops.secrets = {
    "atticd/jwt_secret" = { };
    "atticd/s3_access_key" = { };
    "atticd/s3_secret_key" = { };
  };
  sops.templates."atticd/env".content = ''
    AWS_ACCESS_KEY_ID=${config.sops.placeholder."atticd/s3_access_key"}
    AWS_SECRET_ACCESS_KEY=${config.sops.placeholder."atticd/s3_secret_key"}
    ATTIC_SERVER_TOKEN_RS256_SECRET_BASE64=${config.sops.placeholder."atticd/jwt_secret"}
  '';
  services.atticd = {
    enable = true;
    environmentFile = config.sops.templates."atticd/env".path;
    settings = {
      listen = "127.0.0.1:16321";
      jwt = { };
      database = {
        url = "postgresql:///${databaseName}?host=/run/postgresql";
      };
      storage = {
        type = "s3";
        region = "cn-north-1";
        bucket = "attic";
        endpoint = "https://pek-0.garage.xiny.li:8443";
      };
      chunking = {
        # The minimum NAR size to trigger chunking
        nar-size-threshold = 64 * 1024; # 64 KiB
        # The preferred minimum size of a chunk, in bytes
        min-size = 64 * 1024; # 16 KiB
        # The preferred average size of a chunk, in bytes
        avg-size = 128 * 1024; # 64 KiB
        # The preferred maximum size of a chunk, in bytes
        max-size = 256 * 1024; # 256 KiB
      };
    };
  };

  services.postgresql = {
    enable = true;
    ensureDatabases = [ databaseName ];
    ensureUsers = [
      {
        name = databaseName;
        ensureDBOwnership = true;
        ensureClauses.login = true;
      }
    ];
  };

  services.caddy.virtualHosts."https://pek-0.cache.xiny.li:8443".extraConfig = ''
    tls {
      dns cloudflare {env.CF_API_TOKEN}
    }
    reverse_proxy ${config.services.atticd.settings.listen}
  '';
}
