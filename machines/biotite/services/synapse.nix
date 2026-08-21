{
  config,
  lib,
  pkgs,
  ...
}:
let
  a =
    (lib.nixosSystem {
      modules = [
        {
          nixpkgs.hostPlatform = "x86_64-linux";
          networking.wireguard.interfaces."wg0".fwMark = "0x11";
          networking.wireguard.useNetworkd = true;
        }
      ];
    }).config.systemd.network.netdevs."40-wg0".wireguardConfig;
  inherit (config.my-lib.settings)
    idpUrl
    synapseDelegateUrl
    synapseUrl
    matrixAuthUrl
    ;
  port-synapse = 6823;
  port-mas = 5124;
  port-mas-health = 15124;
in
{
  sops.secrets = {
    "synapse/oidc_client_secret" = {
      owner = "matrix-synapse";
    };
    "synapse/mas_api_secret" = {
      owner = "matrix-synapse";
    };
    "mas/mas_api_secret" = { };
    "mas/secrets" = { };
    "mas/oidc_client_secret" = { };
  };
  # sops.templates."mas/client_secret.conf" = {
  #   owner = "matrix-authentication-service";
  #   content = ''
  #     upstream_oauth2:
  #       client_secret:
  #
  #   '';
  # };

  nixpkgs.config.permittedInsecurePackages = [
    "olm-3.2.16"
  ];

  services.postgresql = {
    # Not using ensure here because LC_COLLATE and LC_CTYPE must be provided
    # at db creation
    initialScript = pkgs.writeText "synapse-init.sql" ''
      CREATE ROLE "matrix-synapse" WITH LOGIN PASSWORD 'synapse';
      CREATE DATABASE "matrix-synapse" WITH OWNER "matrix-synapse"
        TEMPLATE template0
        LC_COLLATE = "C"
        LC_CTYPE = "C";
    '';
  };

  services.matrix-synapse = {
    enable = true;
    withJemalloc = true;
    settings = {
      server_name = "xiny.li";
      public_baseurl = synapseDelegateUrl;
      database = {
        name = "psycopg2";
        args = {
          user = "matrix-synapse";
        };
      };
      listeners = [
        {
          bind_addresses = [
            "127.0.0.1"
          ];
          port = port-synapse;
          resources = [
            {
              compress = true;
              names = [
                "client"
                "federation"
              ];
            }
          ];
          tls = false;
          type = "http";
          x_forwarded = true;
        }
      ];
      matrix_authentication_service = {
        enabled = true;
        endpoint = "http://127.0.0.1:${toString port-mas}/";
        secret = "ViOCX9n9SUF5w4wzacG1dejTHGII1FIG";
        # secret_file = config.sops.secrets."synapse/mas_api_secret".path;
      };
      experimental_features = {
        # Room summary api
        msc3266_enabled = true;
        # Removing account data
        msc3391_enabled = true;
        # Thread notifications
        msc3773_enabled = true;
        # Remotely toggle push notifications for another client
        msc3881_enabled = true;
        # Remotely silence local notifications
        msc3890_enabled = true;
        # Remove legacy mentions
        msc4210_enabled = true;
      };
      # oidc_providers = [
      #   {
      #     idp_id = "Kanidm";
      #     idp_name = idpUrl;
      #     issuer = "https://${idpUrl}/oauth2/openid/synapse";
      #     authorization_endpoint = "https://${idpUrl}/ui/oauth2";
      #     token_endpoint = "https://${idpUrl}/oauth2/token";
      #     userinfo_endpoint = "https://${idpUrl}/oauth2/openid/synapse/userinfo";
      #     client_id = "synapse";
      #     client_secret_path = config.sops.secrets."synapse/oidc_client_secret".path;
      #     scopes = [
      #       "openid"
      #       "profile"
      #     ];
      #     allow_existing_users = true;
      #     backchannel_logout_enabled = true;
      #     user_mapping_provider.config = {
      #       confirm_localpart = true;
      #       localpart_template = "{{ user.preferred_username }}";
      #       display_name_template = "{{ user.name }}";
      #     };
      #   }
      # ];
    };
  };

  services.matrix-authentication-service = {
    enable = true;
    createDatabase = true;
    extraConfigFiles = [
      config.sops.secrets."mas/secrets".path
    ];
    settings = {
      http = {
        public_base = matrixAuthUrl;
        issuer = matrixAuthUrl;
        trusted_proxies = [
          "127.0.0.1/8"
          "::1/128"
        ];
        listeners = [
          {
            name = "web";
            resources = [
              { name = "discovery"; }
              { name = "human"; }
              { name = "oauth"; }
              { name = "compat"; }
              { name = "graphql"; }
              { name = "assets"; }
            ];
            binds = [
              {
                host = "127.0.0.1";
                port = port-mas;
              }
            ];
            proxy_protocol = false;
          }
          {
            name = "internal";
            resources = [
              { name = "health"; }
            ];
            binds = [
              {
                host = "127.0.0.1";
                port = port-mas-health;
              }
            ];
            proxy_protocol = false;
          }
        ];
      };
      passwords = {
        enabled = false;
        schemes = [
          {
            version = 1;
            algorithm = "bcrypt";
            unicode_normalization = true;
          }
          {
            version = 2;
            algorithm = "argon2id";
          }
        ];
      };
      upstream_oauth2 = {
        providers = [
          {
            id = "01K83K1FPGYD79ENWVY0RTWHTB";
            synapse_idp_id = "oidc-Kanidm";
            issuer = "https://auth.xiny.li/oauth2/openid/synapse";
            human_name = "auth.xiny.li";
            client_id = "synapse";
            client_secret = "49jjp1TJjqMEBg5HvU0whHdUsqZzpsRW2ELCu7jDpB8E53XW";
            token_endpoint_auth_method = "client_secret_basic";
            scope = "openid email profile";
            fetch_userinfo = true;
            authorization_endpoint = "https://auth.xiny.li/ui/oauth2";
            userinfo_endpoint = "https://auth.xiny.li/oauth2/openid/synapse/userinfo";
            token_endpoint = "https://auth.xiny.li/oauth2/token";
            claims_imports = {
              localpart = {
                action = "suggest";
                template = "{{ user.preferred_username }}";
              };
              displayname = {
                action = "suggest";
                template = "{{ user.name }}";
              };
            };
            forward_login_hint = false;
          }
        ];
      };

      matrix = {
        kind = "synapse";
        homeserver = "xiny.li";
        # secret_path = config.sops.secrets."mas/mas_api_secret".path;
        secret = "ViOCX9n9SUF5w4wzacG1dejTHGII1FIG";
        endpoint = "http://127.0.0.1:${toString port-synapse}";
      };
    };
  };

  services.caddy = {
    virtualHosts.${matrixAuthUrl}.extraConfig = ''
      reverse_proxy 127.0.0.1:${toString port-mas}
    '';
    virtualHosts.${synapseUrl}.extraConfig = ''
      header /.well-known/matrix/* Content-Type application/json
      header /.well-known/matrix/* Access-Control-Allow-Origin *
      respond /.well-known/matrix/server `{"m.server":"synapse.xiny.li:443"}`
      respond /.well-known/matrix/client `{"m.homeserver":{"base_url":"${synapseDelegateUrl}"}}`
    '';
    virtualHosts.${synapseDelegateUrl}.extraConfig = ''
      reverse_proxy /_matrix/* 127.0.0.1:${toString port-synapse}
      reverse_proxy /_synapse/client/* 127.0.0.1:${toString port-synapse}
    '';
  };
}
