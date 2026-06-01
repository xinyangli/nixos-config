{
  config,
  lib,
  pkgs,
  ...
}:
let
  inherit (config.my-lib.settings) minifluxUrl;
  listenAddr = "127.0.0.1:58174";
in
{
  sops.secrets = {
    "miniflux/tts_api_token" = { };
    "miniflux/tts_openai_api_key" = { };
    "miniflux/tts_browser_token" = { };
  };
  sops.templates."miniflux-tts.env".content = ''
    MINIFLUX_API_TOKEN=${config.sops.placeholder."miniflux/tts_api_token"}
    MINIFLUX_TTS_OPENAI_API_KEY=${config.sops.placeholder."miniflux/tts_openai_api_key"}
    TTS_BROWSER_TOKEN=${config.sops.placeholder."miniflux/tts_browser_token"}
  '';

  systemd.services.miniflux-tts = {
    description = "Miniflux TTS integration";
    after = [
      "network-online.target"
      "miniflux.service"
    ];
    wants = [
      "network-online.target"
      "miniflux.service"
    ];
    wantedBy = [ "multi-user.target" ];

    environment = {
      TTS_ADDR = listenAddr;
      MINIFLUX_BASE_URL = "http://${config.services.miniflux.config.LISTEN_ADDR}";
      PUBLIC_BASE_URL = minifluxUrl;
      ALLOWED_MINIFLUX_ORIGIN = minifluxUrl;
      STORAGE_DIR = "/var/lib/miniflux-tts/audio";
      MINIFLUX_TTS_PROVIDER = "openai";
      MINIFLUX_TTS_OPENAI_BASE_URL = "https://api.xiaomimimo.com/v1";
      MINIFLUX_TTS_OPENAI_MODEL = "mimo-v2.5-tts";
      MINIFLUX_TTS_OPENAI_VOICE = "冰糖";
      MINIFLUX_TTS_OPENAI_FORMAT = "wav";
    };

    serviceConfig = {
      DynamicUser = true;
      EnvironmentFile = config.sops.templates."miniflux-tts.env".path;
      ExecStart = lib.getExe pkgs.miniflux-tts;
      Restart = "on-failure";
      RestartSec = "5s";
      StateDirectory = "miniflux-tts";
    };
  };

  services.caddy.virtualHosts.${minifluxUrl}.extraConfig = lib.mkBefore ''
    @miniflux_tts_bad_origin {
      path /tts/*
      not {
        header Origin ${minifluxUrl}
      }
    }
    respond @miniflux_tts_bad_origin "forbidden" 403

    handle /tts/* {
      reverse_proxy ${listenAddr}
    }
    handle /audio/* {
      reverse_proxy ${listenAddr}
    }
  '';
}
