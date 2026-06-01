{ config, lib, pkgs, ... }:
let
  inherit (config.my-lib.settings) minifluxUrl;
  listenAddr = "127.0.0.1:58174";
in
{
  sops.secrets."miniflux/tts_secret_key" = { };
  sops.templates."miniflux-tts.env".content = ''
    MINIFLUX_API_TOKEN=${config.sops.placeholder."miniflux/tts_secret_key"}
    MINIFLUX_TTS_OPENAI_API_KEY=${config.sops.placeholder."miniflux/tts_secret_key"}
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
      MINIFLUX_BASE_URL = minifluxUrl;
      PUBLIC_BASE_URL = minifluxUrl;
      ALLOWED_MINIFLUX_ORIGIN = minifluxUrl;
      STORAGE_DIR = "/var/lib/miniflux-tts/audio";
      MINIFLUX_TTS_PROVIDER = "openai";
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
    handle /miniflux-tts.js {
      root * ${pkgs.miniflux-tts}/share/miniflux-tts
      file_server
    }
  '';
}
