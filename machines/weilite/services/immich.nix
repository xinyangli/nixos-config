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
      issuerUrl = "https://${idpUrl}/oauth2/openid/immich/.well-known/openid-configuration";
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
        concurrency = 1;
      };
      metadataExtraction = {
        concurrency = 2;
      };
      thumbnailGeneration = {
        concurrency = 2;
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
        API_KEY=${config.sops.placeholder."immich/auto_stack_apikey"}
      '';
    };

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
          url = "https://gist.githubusercontent.com/xinyangli/39de5979e72d81af6fe9ddb7d1805df4/raw/805beab14eb9160713b14e1da4d0d5922816d988/immich_auto_stack.py";
          hash = "sha256-vWbw2iFkSD5jLM95Dmk7Kdb2iSI1gd4RexIGG37dm90=";
        };
      in
      {
        environment = {
          SKIP_MATCH_MISS = "true";
          DRY_RUN = "false";
          API_URL = "http://127.0.0.1:${toString config.services.immich.port}/api";
          PARENT_PROMOTE = "hdr,edit,export,selects,output";
        };
        serviceConfig = {
          ExecStart = "${lib.getExe python} ${immich_auto_stack}";
          EnvironmentFile = config.sops.templates."immich/auto_stack.env".path;
          WorkingDirectory = "%t/immich-auto-stack";
          RuntimeDirectory = "immich-auto-stack";
          User = "immich_auto_stack";
          Group = "immich_auto_stack";
        };
      };

    systemd.services.immich-server = {
      serviceConfig = {
        BindReadOnlyPaths = [
          "/mnt/photos/xin/originals:/mnt/immich/external-library/xin"
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
      "privimg"
    ];

    users.groups.privimg = { };

    users.groups.immich_auto_stack = { };
    users.users.immich_auto_stack = {
      isSystemUser = true;
      group = "immich_auto_stack";
    };

    services.immich.redis.host = "/run/redis-immich/redis.sock";
  };
}
