{
  config,
  ...
}:
let
  inherit (config.my-lib.settings) idpUrl;

  user = config.systemd.services.immich-server.serviceConfig.User;
  immichUrl = "immich.xiny.li:8443";
  jsonSettings = {
    oauth = {
      enabled = true;
      issuerUrl = "https://${idpUrl}/oauth2/openid/immich/";
      clientId = "immich";
      clientSecret = config.sops.placeholder."immich/oauth_client_secret";
      scope = "openid email profile";
      signingAlgorithm = "ES256";
      storageLabelClaim = "email";
      buttonText = "Login with Kanidm";
      autoLaunch = true;
      mobileOverrideEnabled = true;
      mobileRedirectUri = "https://${immichUrl}/api/oauth/mobile-redirect/";
    };
    passwordLogin = {
      enabled = false;
    };
    image = {
      extractEmbedded = true;
    };
    newVersionCheck = {
      enabled = false;
    };
  };
in
{
  config = {
    sops.secrets."immich/oauth_client_secret" = { };

    sops.templates."immich/config.json" = {
      owner = user; # Read when running
      content = builtins.toJSON jsonSettings;
    };

    systemd.services.immich-server = {
      serviceConfig = {
        Environment = "IMMICH_CONFIG_FILE=${config.sops.templates."immich/config.json".path}";
      };
    };

    services.immich = {
      enable = true;
      host = "127.0.0.1";
      port = 3001;
      openFirewall = true;
      machine-learning.enable = true;
      environment = {
        IMMICH_MACHINE_LEARNING_ENABLED = "true";
      };
      database.enable = true;
    };

    # https://github.com/NixOS/nixpkgs/pull/324127/files#r1723763510
    services.immich.redis.host = "/run/redis-immich/redis.sock";
  };
}
