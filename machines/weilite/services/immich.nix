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
      urls = [
        "http://calcite.coho-tet.ts.net:3003"
        "http://127.0.0.1:3003"
      ];
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
    sops.secrets = {
      "immich/oauth_client_secret" = { };
      "immich/auto_stack_apikey" = { };
    };

    sops.templates."immich/config.json" = {
      owner = user; # Read when running
      content = builtins.toJSON jsonSettings;
    };

    sops.templates."immich/auto_stack.env" = {
      owner = "immich_auto_stack";
      content = ''
        API_KEY=${config.sops.placeholder."immich/auto_stack_apikey"};
      '';
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

    systemd.timers.immich-auto-stack = {
      enable = true;
      wantedBy = [ "immich-server.service" ];
      timerConfig = {
        Unit = "immich-auto-stack.service";
        OnCalendar = "*-*-* 4:00:00";
      };
    };

    systemd.services.immich-auto-stack =
      let
        python = pkgs.python3.withPackages (
          ps: with ps; [
            requests
          ]
        );
        immich_auto_stack = pkgs.fetchurl {
          url = "https://gist.github.com/xinyangli/39de5979e72d81af6fe9ddb7d1805df4";
          hash = "sha256-izbzP+330tZUGPTfS3SdJnGS5uSn5uf8WmXd6ep8SQg=";
        };
      in
      {
        environment = {
          SKIP_MATCH_MISS = "true";
          DRY_RUN = "false";
          API_URL = "http://127.0.0.1:${toString config.services.immich.port}/api";
        };
        serviceConfig = {
          ExecStart = "${lib.getExe python} ${immich_auto_stack}";
          EnvironmentFile = config.sops.templates."immich/auto_stack.env".path;
          User = "immich_auto_stack";
          Group = "immich_auto_stack";
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

    users.groups.immich_auto_stack = { };
    users.users.immich_auto_stack = {
      isSystemUser = true;
      group = "immich_auto_stack";
    };

    services.immich.redis.host = "/run/redis-immich/redis.sock";
  };
}
