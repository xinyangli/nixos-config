{
  config,
  lib,
  pkgs,
  ...
}:
let
  inherit (config.my-lib.settings) idpUrl synapseDelegateUrl synapseUrl;
  port-synapse = 6823;
in
{
  sops.secrets."synapse/oidc_client_secret" = {
    owner = "matrix-synapse";
  };

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
      oidc_providers = [
        {
          idp_id = "Kanidm";
          idp_name = lib.removePrefix "https://" idpUrl;
          issuer = "${idpUrl}/oauth2/openid/synapse";
          authorization_endpoint = "${idpUrl}/ui/oauth2";
          token_endpoint = "${idpUrl}/oauth2/token";
          userinfo_endpoint = "${idpUrl}/oauth2/openid/synapse/userinfo";
          client_id = "synapse";
          client_secret_path = config.sops.secrets."synapse/oidc_client_secret".path;
          scopes = [
            "openid"
            "profile"
          ];
          allow_existing_users = true;
          backchannel_logout_enabled = true;
          user_mapping_provider.config = {
            confirm_localpart = true;
            localpart_template = "{{ user.preferred_username }}";
            display_name_template = "{{ user.name }}";
          };
        }
      ];
    };
  };

  services.caddy = {
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

  networking.firewall.allowedTCPPorts = [
    443
  ];
}
