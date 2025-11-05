{ config, pkgs, ... }:
let
  niri-taskbar = pkgs.callPackage (
    {
      rustPlatform,
      lib,
      fetchFromGitHub,
      pkg-config,
      gtk3,
    }:

    rustPlatform.buildRustPackage rec {
      pname = "niri-taskbar";
      version = "0.1.0";

      src = fetchFromGitHub {
        owner = "LawnGnome";
        repo = "niri-taskbar";
        tag = "v${version}";
        hash = "sha256-mzO2j3CnYJsF8UCoKquG2AT1Lb0PDsSEs2mdmTcTGPA=";
      };

      cargoHash = "sha256-zOAdnkWSSJd2tfT1bV9WkFY74DKSGD6HkSl8a+Fyd9o=";

      nativeBuildInputs = [
        pkg-config
      ];

      buildInputs = [
        gtk3
      ];

      meta = {
        maintainers = with lib.maintainers; [ bot-wxt1221 ];
      };
    }
  ) { };
in
{
  home.packages = with pkgs; [
    waybar-mpris
  ];
  services.playerctld.enable = true;
  programs.waybar = {
    enable = true;
    style = ''
      * {
        font-family: Ubuntu Nerd Font, NotoSans Nerd Font, sans;
        min-height: 14px;
        border-radius: 1rem;
        color: @text;
        background-color: transparent;
      }

      menu, tooltip {
        background: @crust;
      }

      #workspaces,
      #tray, #custom-notification {
        background-color: alpha(@crust, 0.8);
      }
      #mpris,
      #network, #wireplumber, #cpu, #memory, #backlight, #battery {
        color: @crust;
        background-color: transparent;
      }

      /* Hover on filled elements */
      #workspaces button:hover, #tray > .active:hover, #custom-notification:hover {
        background: @base;
      }
      /* Transparent Hover */
      .niri-taskbar button:hover,
      #mpris:hover, #clock:hover, #network:hover, #wireplumber:hover, #cpu:hover, #memory:hover, #backlight:hover, #battery:hover {

        background-color: alpha(@crust, 0.2);
      }

      #tray {
        padding: 0 0.8rem;
      }
      #mpris, #network, #wireplumber, #cpu, #memory, #backlight, #battery {
        padding: 0 0.5rem;
      }

      #mpris {
        font-weight: normal;
        font-size: 16px;
      }

      #clock {
        padding: 0 1rem;
      }
      #custom-notification {
        min-width: 2.8rem;
        padding: 0;
      }

      #workspaces button {
        min-width: 1.2rem;
      }

      #workspaces button.focused, workspaces button.active {
        border-radius: 1rem 1rem 0 0;
        border-bottom: 4px solid @${config.catppuccin.accent};
      }
      .niri-taskbar button.focused {
        background-color: alpha(@crust, 0.1);
        border-radius: 1rem 1rem 0 0;
        border-bottom: 4px solid @${config.catppuccin.accent};
      }


      #network, #wireplumber, #cpu, #memory {
        font-size: 14px;
        font-weight: bold;
      }

      #backlight, #battery {
        font-size: 16px;
      }

      #wireplumber, #cpu, #memory, #backlight {
        border-radius: 0;
      }

      #network, #tray {
        border-radius: 1rem 0 0 1rem;
      }

      #battery, #custom-notification{
        border-radius: 0 1rem 1rem 0;
      }

      #tray {
        font-weight: bold;
        font-size: 14px;
      }

      #clock {
        color: @crust;
        background-color: transparent;
        font-weight: bold;
        font-size: 16px;
      }
    '';
    settings = {
      main = {
        margin = "1px 1px 0 1px";
        height = 20;
        layer = "bottom";
        "cffi/niri-taskbar" = {
          module_path = "${niri-taskbar}/lib/libniri_taskbar.so";
          apps = {
            signal = [
              {
                match = "\\([0-9]+\\)$";
                class = "unread";
              }
            ];
          };
        };
        "mpris" = {
          format = "{player_icon} {status_icon}  {title} - {artist}";
          format-paused = "{player_icon} {status_icon}";
          justify = "left";
          expand = false;
          ellipsis = ".";
          player-icons = {
            default = "";
            spotify = "";
            Spot = "";
            Valent = "";
            vlc = "󰕼";
          };
          status-icons = {
            paused = "";
            playing = "";
          };
          ignored-players = [
            "firefox"
            "chromium"
          ];
          max-length = 20;
        };
        "custom/separator" = {
          format = " ";
          interval = "once";
          tooltip = false;
        };
        modules-left = [
          "niri/workspaces"
          "mpris"
        ];
        modules-center = [
          "clock"
        ];
        modules-right = [
          "network#speed"
          "wireplumber#sink"
          "wireplumber#source"
          "memory"
          "cpu"
          "backlight"
          "battery"
          "tray"
          "custom/notification"
        ];
        "niri/workspaces" = {
          all-outputs = true;
          format = "{icon}";
          format-icons = {
            "terminal" = "";
            "browser" = "";
            "chat" = "";
            "mail" = "󰇮";
          };
        };
        "niri/window" = {
          max-length = 50;
        };

        "wireplumber#sink" = {
          format = "{icon} {volume}%";
          format-muted = "";
          format-icons = [
            ""
            ""
            ""
          ];
          on-click = "${pkgs.pwvucontrol}/bin/pwvucontrol";
          on-click-middle = "${pkgs.coppwr}/bin/coppwr";
          on-click-right = "wpctl set-mute @DEFAULT_AUDIO_SINK@ toggle";
          scroll-step = 2;
        };

        "wireplumber#source" = {
          node-type = "Audio/Source";
          format = " {volume}%";
          format-muted = "";
          on-click = "${pkgs.pwvucontrol}/bin/pwvucontrol";
          on-click-middle = "${pkgs.coppwr}/bin/coppwr";
          on-click-right = "wpctl set-mute @DEFAULT_AUDIO_SOURCE@ toggle";
          scroll-step = 2;
        };

        backlight = {
          format = "{icon}";
          format-icons = [
            "󱩎"
            "󱩐"
            "󱩒"
            "󱩔"
            "󰛨"
          ];
          on-scroll-down = "${pkgs.brightnessctl}/bin/brightnessctl set 1%-";
          on-scroll-up = "${pkgs.brightnessctl}/bin/brightnessctl set +1%";
        };
        battery = {
          interval = 10;
          format = "{icon}";
          format-charging = "{icon} 󱐋";
          format-plugged = "{icon} ";
          format-icons = [
            ""
            ""
            ""
            ""
            ""
          ];
          tooltip-format = "{capacity}% ({time})";
          tooltip-format-plugged = "{capacity}%";
          states = {
            warning = 15;
            critical = 5;
          };
          events = {
            "on-discharging-warning" = "${pkgs.libnotify}/bin/notify-send -u normal 'Low Battery'";
            "on-discharging-critical" = "${pkgs.libnotify}/bin/notify-send -u normal 'Very Low battery'";
          };
        };
        clock = {
          format = "{:%a %b %d %H:%M}";
          tooltip-format = "<tt><small>{calendar}</small></tt>";
        };
        memory = {
          format = "  {percentage}%";
        };

        "network#speed" = {
          format = "{ifname}";
          format-disconnected = "󰌙";
          format-ethernet = " {bandwidthDownBytes}   {bandwidthUpBytes}";
          format-linked = "";
          format-wifi = " {bandwidthDownBytes}   {bandwidthUpBytes}";
          interval = 5;
          max-length = 30;
          tooltip-format = "{ipaddr}";
          tooltip-format-disconnected = "󰌙 Disconnected";
          tooltip-format-ethernet = "{ifname} 󰌘";
          tooltip-format-wifi = "{essid} {icon} {signalStrength}%";
        };

        cpu = {
          format = "  {usage}%";
          interval = 5;
        };

        tray = {
          icon-size = 18;
          spacing = 10;
        };

        "custom/notification" = {
          escape = true;
          exec = "swaync-client -swb";
          exec-if = "which swaync-client";
          format = "{icon}";
          format-icons = {
            dnd-inhibited-none = "";
            dnd-inhibited-notification = "<span foreground='#fab387'><sup></sup></span>";
            dnd-none = "";
            dnd-notification = "<span foreground='#fab387'><sup></sup></span>";
            inhibited-none = "";
            inhibited-notification = "<span foreground='#fab387'><sup></sup></span>";
            none = "";
            notification = "<span foreground='#fab387'><sup></sup></span>";
          };
          on-click = "swaync-client -t -sw";
          on-click-right = "swaync-client -d -sw";
          return-type = "json";
          tooltip = false;
        };
      };
    };
    systemd.enable = true;
  };
}
