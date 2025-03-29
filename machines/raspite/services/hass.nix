{ config, pkgs, ... }:
{
  services.home-assistant = {
    enable = true;
    openFirewall = false;
    config = {
      http = {
        server_host = "127.0.0.1";
        use_x_forwarded_for = true;
        trusted_proxies = [ "127.0.0.1" ];
      };
      assist_pipeline = { };
      backup = { };
      bluetooth = { };
      config = { };
      conversation = { };
      history = { };
      recorder = {
        purge_keep_days = 14;
      };
      homeassistant_alerts = { };
      image_upload = { };
      logbook = { };
      media_source = { };
      mobile_app = { };
      my = { };
      ssdp = { };
      stream = { };
      sun = { };
      usb = { };
      webhook = { };
      zeroconf = { };
    };
    extraPackages =
      python3Packages: with python3Packages; [
        # speed up aiohttp
        isal
        zlib-ng
      ];
    extraComponents = [
      "mqtt"
      "roborock"
      "openai_conversation"
    ];
  };

  systemd.services.home-assistant.environment = {
    OPENAI_BASE_URL = "https://api.deepseek.com/v1";
  };

  services.esphome = {
    enable = true;
    openFirewall = false;
  };

  users.groups.dialout.members = config.users.groups.wheel.members;

  services.mosquitto = {
    enable = true;
  };

  services.zigbee2mqtt = {
    enable = true;
    package = pkgs.zigbee2mqtt_2;
    settings = {
      home-assistant = config.services.home-assistant.enable;
      serial = {
        adapter = "zstack";
        port = "/dev/ttyUSB0";
      };
      frontend = {
        enabled = true;
        port = 15313;
        host = "127.0.0.1";
      };
      advanced = {
        log_level = "debug";
        availability = {
          # Periodically check whether devices are online/offline
          enabled = true;
        };
        channel = 11;
        homeassistant_legacy_entity_attributes = false;
        homeassistant_legacy_triggers = false;
        legacy_api = false;
        legacy_availability_payload = false;
      };
      device_options = {
        legacy = false;
      };
      devices = {
        "0x000d6f001673c5d4" = {
          friendly_name = "小次卧开关";
        };
        "0x000d6f001673c1df" = {
          friendly_name = "衣帽间开关";
        };
        "0x000d6f0014cbc2c6" = {
          friendly_name = "主卧床头开关";
        };
        "0x8cf681fffe0a5e38" = {
          friendly_name = "玄关开关";
          description = "1: 玄关灯 2: 书房灯";
        };
        "0x8cf681fffe0d9f1c" = {
          friendly_name = "客厅开关1";
          description = "1: 轨道灯东 2: 轨道灯西";
        };
        "0x000d6f00167839ff" = {
          friendly_name = "客厅开关2";
          description = "1: 客厅射灯北 2: 客厅射灯南";
        };
        "0x8cf681fffe0db266" = {
          friendly_name = "客厅开关3";
          description = "过道射灯";
        };
        "0x8cf681fffe0d9ccb" = {
          friendly_name = "客厅开关4";
          description = "1.厨房射灯";
        };
        "0x000d6f001673c512" = {
          friendly_name = "小过道开关";
        };
        "0xa4c13815e2f92d74" = {
          friendly_name = "客厅格栅灯";
          transition = 1;
        };
        "0x540f57fffe54ced3" = {
          friendly_name = "书房灯西南";
          transition = 1;
        };
        "0x540f57fffe54c8d4" = {
          friendly_name = "书房灯东北";
          transition = 1;
        };
        "0x540f57fffe54c82b" = {
          friendly_name = "书房灯西北";
          transition = 1;
        };
        "0x540f57fffe5210bc" = {
          friendly_name = "书房灯东南";
          transition = 1;
        };
        "0x540f57fffe54c851" = {
          friendly_name = "鞋柜灯";
          transition = 1;
        };
        "0x540f57fffe54ce63" = {
          friendly_name = "入户灯";
          transition = 1;
        };
        "0x540f57fffe54c8ce" = {
          friendly_name = "影壁灯";
          transition = 1;
        };
        "0xa4c138693a2afad7" = {
          friendly_name = "次卧泛光灯";
          transition = 1;
        };
        "0x540f57fffe54c826" = {
          friendly_name = "厨房水池灯";
          transition = 1;
        };
        "0x540f57fffe521114" = {
          friendly_name = "厨房灯";
          transition = 1;
        };
        "0x540f57fffe54c86b" = {
          friendly_name = "过道灯西";
          transition = 1;
        };
        "0x540f57fffe54c82e" = {
          friendly_name = "过道灯东";
          transition = 1;
        };
        "0x540f57fffe5210e3" = {
          friendly_name = "客卫洗手池射灯";
          transition = 1;
        };
        "0xfc4d6afffe6eb9e3" = {
          friendly_name = "客卫镜前灯";
        };
        "0x540f57fffe5210cf" = {
          friendly_name = "客厅射灯北1";
          transition = 1;
        };
        "0x540f57fffe54c8bb" = {
          friendly_name = "客厅射灯北2";
          transition = 1;
        };
        "0x540f57fffe5210db" = {
          friendly_name = "客厅射灯北3";
          transition = 1;
        };
        "0x540f57fffe54cec5" = {
          friendly_name = "客厅射灯南1";
          transition = 1;
        };
        "0x540f57fffe520d1d" = {
          friendly_name = "客厅射灯南2";
          transition = 1;
        };
        "0x540f57fffe54c966" = {
          friendly_name = "客厅射灯南3";
          transition = 1;
        };
        "0x540f57fffe520ceb" = {
          friendly_name = "小次卧射灯北";
          transition = 1;
        };
        "0x540f57fffe5210cd" = {
          friendly_name = "小次卧射灯南";
          transition = 1;
        };
      };
    };
  };

  networking.firewall.allowedTCPPorts = [ 8443 ];

  services.caddy = {
    enable = true;
    virtualHosts = {
      "raspite.coho-tet.ts.net".extraConfig = ''
        reverse_proxy ${config.services.home-assistant.config.http.server_host}:${toString config.services.home-assistant.config.http.server_port}
      '';
      "https://raspite.coho-tet.ts.net:8080".extraConfig = ''
        reverse_proxy ${config.services.zigbee2mqtt.settings.frontend.host}:${toString config.services.zigbee2mqtt.settings.frontend.port}
      '';
    };
  };
}
