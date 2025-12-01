{ config, pkgs, ... }:
let
  domain = "ente.xiny.li:8443";
  cfgWeb = config.services.ente.web;
  webPackage =
    enteApp:
    cfgWeb.package.override {
      inherit enteApp;
      enteMainUrl = "https://${cfgWeb.domains.photos}";
      extraBuildEnv = {
        NEXT_PUBLIC_ENTE_ENDPOINT = "https://${cfgWeb.domains.api}";
        NEXT_PUBLIC_ENTE_ALBUMS_ENDPOINT = "https://${cfgWeb.domains.albums}";
        NEXT_TELEMETRY_DISABLED = "1";
      };
    };
  domainFor = app: cfgWeb.domains.${app};
in
{
  sops.secrets =
    let
      user = config.services.ente.api.user;
    in
    {

      "ente/s3_access_key" = {
        owner = user;
      };
      "ente/s3_secret_key" = {
        owner = user;
      };
      "ente/encryption_key" = {
        owner = user;
      };
      "ente/hash" = {
        owner = user;
      };
      "ente/jwt_secret" = {
        owner = user;
      };
      "ente/hardcode_otp" = {
        owner = user;
      };
    };
  services.ente = {
    web = {
      enable = true;
      domains = {
        accounts = "accounts.${domain}";
        albums = "albums.${domain}";
        cast = "cast.${domain}";
        photos = "photos.${domain}";
      };
    };
    api = {
      enable = true;
      # Create a local postgres database and set the necessary config in ente
      enableLocalDB = true;
      domain = "api.${domain}";
      settings = {
        internal = {
          hardcoded-ott = {
            emails = [
            ];
            local-domain-suffix = "@example.org";
            local-domain-value = config.sops.secrets."ente/hardcode_otp".path;
          };
          admin = 1580559962386438;
        };
        s3 = {
          use_path_style_urls = true;
          b2-eu-cen = {
            endpoint = "https://pek-0.garage.xiny.li:8443";
            region = "cn-north-1";
            bucket = "ente";
            key._secret = config.sops.secrets."ente/s3_access_key".path;
            secret._secret = config.sops.secrets."ente/s3_secret_key".path;
          };
        };
        key = {
          # generate with: openssl rand -base64 32
          encryption._secret = config.sops.secrets."ente/encryption_key".path;
          # generate with: openssl rand -base64 64
          hash._secret = config.sops.secrets."ente/hash".path;
        };
        # generate with: openssl rand -base64 32
        jwt.secret._secret = config.sops.secrets."ente/jwt_secret".path;
      };
    };
  };

  services.caddy =
    let
      caddyFor = enteApp: ''
        tls {
          dns cloudflare {env.CF_API_TOKEN}
        }
        root * ${webPackage enteApp}
        header Access-Control-Allow-Origin https://${cfgWeb.domains.api}
        try_files {path} {path}.html /index.html
        file_server
      '';
    in
    {
      virtualHosts."api.${domain}".extraConfig = ''
        tls {
          dns cloudflare {env.CF_API_TOKEN}
        }
        route {
          reverse_proxy 127.0.0.1:8080
        }
      '';
      virtualHosts.${domainFor "accounts"}.extraConfig = caddyFor "accounts";
      virtualHosts.${domainFor "cast"}.extraConfig = caddyFor "cast";
      virtualHosts.${domainFor "photos"} = {
        serverAliases = [ (domainFor "albums") ];
        extraConfig = caddyFor "photos";
      };

    };
}
