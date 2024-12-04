{
  config,
  ...
}:
let
  user = config.systemd.services.immich-server.serviceConfig.User;
  jsonSettings = {
    oauth = {
      enabled = true;
      issuerUrl = "https://auth.xinyang.life/oauth2/openid/immich/";
      clientId = "immich";
      clientSecret = config.sops.placeholder."immich/oauth_client_secret";
      scope = "openid email profile";
      signingAlgorithm = "ES256";
      storageLabelClaim = "email";
      buttonText = "Login with Kanidm";
      autoLaunch = true;
      mobileOverrideEnabled = true;
      mobileRedirectUri = "https://immich.xinyang.life:8000/api/oauth/mobile-redirect/";
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
      mediaLocation = "/mnt/XinPhotos/immich";
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
