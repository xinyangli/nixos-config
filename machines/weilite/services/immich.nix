{
  config,
  pkgs,
  lib,
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
    job = {
      faceDetection = {
        concurrency = 3;
      };
      backgroundTask = {
        concurrency = 2;
      };
      metadataExtraction = {
        concurrency = 2;
      };
      thumbnailGeneration = {
        concurrency = 1;
      };
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
    ffmpeg = {
      accel = "qsv";
      accelDecode = true;
    };
    machineLearning = {
      enabled = true;
      clip = {
        enabled = true;
        modelName = "XLM-Roberta-Large-ViT-H-14__frozen_laion5b_s13b_b90k";
      };
      facialRecognition = {
        maxDistance = 0.35;
        minFaces = 10;
      };
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

    systemd.mounts = [
      {
        what = "originals";
        where = "/mnt/immich/external-library/xin";
        type = "virtiofs";
        options = "ro,nodev,nosuid";
        wantedBy = [ "immich-server.service" ];
      }
    ];

    # systemd.timers.immich-auto-stack = {
    #   enable = true;
    #   wantedBy = [ "immich-server.service" ];
    #   timerConfig = {
    #     Unit = "immich-auto-stack.service";
    #     OnCalendar = "*-*-* 4:00:00";
    #   };
    # };
    #
    systemd.services.immich-auto-stack =
      let
        python = pkgs.python3.withPackages (
          ps: with ps; [
            requests
          ]
        );
      in
      {
        serviceConfig = {
          ExecStart = "${lib.getExe python}";
          # TODO:
          environmentFile = "./.";
        };
      };

    systemd.services.immich-server = {
      serviceConfig = {
        ReadWritePaths = [
          "/mnt/immich/external-library/xin"
        ];
        Environment = "IMMICH_CONFIG_FILE=${config.sops.templates."immich/config.json".path}";
      };
    };

    services.immich = {
      enable = true;
      host = "127.0.0.1";
      port = 3001;
      openFirewall = true;
      machine-learning.enable = true;
      accelerationDevices = [
        "/dev/dri/renderD128"
        "/dev/dri/card0"
      ];
      environment = {
        IMMICH_MACHINE_LEARNING_ENABLED = "true";
      };
      database.enable = true;
    };

    users.users.immich.extraGroups = [
      "video"
      "render"
    ];

    services.immich.redis.host = "/run/redis-immich/redis.sock";
  };
}
