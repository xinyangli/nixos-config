{ config, pkgs, ... }:
{
  home.packages = with pkgs; [
    waybar-mpris
  ];
  services.playerctld.enable = true;
  programs.waybar = {
    enable = true;
    style = ''
      * {
        font-family: MiSans Nerd Font Propo, sans;
        font-size: 14px;
        font-weight: 500;
        min-height: 12px;
        border-radius: 1rem;
        color: @text;
        background-color: transparent;
      }

      menu, tooltip {
        background: @base;
        font-size: 12px;
        font-weight: 400;
      }

      #tray, #custom-notification {
        background-color: alpha(@base, 0.9);
      }
      #mpris {
        font-size: 16px;
      }
      #mpris,
      #network, #wireplumber, #cpu, #memory, #backlight, #battery {
        color: @text;
        background-color: alpha(@base, 0.1);
      }

      /* Hover on filled elements */
      #tray > .active:hover, #custom-notification:hover {
        background: @base;
      }
      /* Transparent Hover */
      #mpris:hover, #clock:hover, #network:hover, #wireplumber:hover, #cpu:hover, #memory:hover, #backlight:hover, #battery:hover {

        background-color: alpha(@base, 0.2);
      }

      #tray {
        padding: 0 0.8rem;
      }
      #mpris, #network, #wireplumber, #cpu, #memory, #backlight, #battery {
        padding: 0 0.5rem;
      }

      #clock {
        padding: 0 1rem;
      }
      #custom-notification {
        min-width: 2.8rem;
        padding: 0;
      }

      #workspaces {
        font-size: 12px;
        font-weight: bold;
      }

      #workspaces button {
        min-width: 1.2rem;
        background-color: alpha(@base, 0.6);
        border-radius: 0;
        transition-duration: 0.1s;
      }
      #workspaces button:hover {
        background-color: alpha(@base, 0.65);
      }
      #workspaces button:first-child {
        border-radius: 1em 0 0 1em;
      }
      #workspaces button:last-child {
        border-radius: 0 1em 1em 0;
      }
      #workspaces button.active {
        border-bottom: 4px solid @overlay2;
        border-top: 0px solid transparent;
        min-height: 10px;
      }
      #workspaces button.current_output {
        background-color: alpha(@base, 0.9);
      }
      #workspaces button.current_output:hover {
        background-color: @base;
      }
      #workspaces button.urgent {
        background-color: @overlay0;
      }
      #workspaces button.urgent label {
        color: @${config.catppuccin.accent};
      }
      #workspaces button.focused {
        border-bottom: 4px solid @${config.catppuccin.accent};
      }

      #network, #wireplumber, #cpu, #memory {
        font-weight: bold;
      }

      #backlight, #battery {
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

      #clock {
        color: @text;
        background-color: alpha(@base, 0.1);
        font-weight: bold;
      }
    '';
    settings = {
      main = {
        margin = "1px 1px 0 1px";
        height = 20;
        layer = "bottom";
        "mpris" = {
          format = "{player_icon} {status_icon}  {title} - {artist}";
          format-paused = "{player_icon} {status_icon}";
          justify = "left";
          expand = false;
          ellipsis = ".";
          player-icons = {
            default = "";
            spotify = "";
            spotifyd = " 󰀿";
            Spot = "";
            Valent = "";
            kdeconnect = "";
            firefox = "󰈹";
            chromium = "";
            vlc = "󰕼";
          };
          status-icons = {
            paused = "";
            playing = "";
          };
          ignored-players = [
            "kdeconnect"
          ];
          on-click-right = "${pkgs.playerctl}/bin/playerctld shift";
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
            "media" = "";
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
          on-click = "${pkgs.iwgtk}/bin/iwgtk";
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
