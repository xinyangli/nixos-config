{
  config,
  pkgs,
  lib,
  ...
}:
let
  inherit (lib) mkIf mkEnableOption readFile;
  cfg = config.custom-hm.gui.waybar;
in
{
  options.custom-hm.gui.waybar = {
    enable = mkEnableOption "waybar";
  };

  config = mkIf cfg.enable {
    programs.waybar = {
      enable = true;
      style = ''
        * {
          font-family: Ubuntu Nerd Font, Noto Sans CJK SC;
          font-size: 14px;
          font-weight: bold;
          min-height: 14px;
        }

        window#waybar {
          color: @text;
          opacity: 0.95;
          background-color: @crust;
          padding: 2px;
        }

        #custom-nixos {
          background-color: #24273a;
          padding-left: 15px;
          padding-right: 18px;
        }

        #custom-separator {
          margin: 0 2px;
        }

        #workspaces {
          border-radius: 0;
        }
        #workspaces button {
          padding: 0 10px;
          border-radius: 0;
        }
        #workspaces button.focused,
        #workspaces button.active {
          border-bottom: 4px solid #8aadf4;
        }
        #workspaces button.empty {
          font-size: 0;
          min-width: 0;
          min-height: 0;
          margin: 0;
          padding: 0;
          border: 0;
          opacity: 0;
          box-shadow: none;
        }
        #cpu,
        #memory,
        #pulseaudio,
        #network,
        #backlight,
        #battery,
        #tray,
        #custom-notification {
          margin-right: 15px;
        }
        #clock {
          font-size: 16px;
        }
      '';
      settings = {
        main = {
          margin = "2px 3px 2 3px";
          height = 30;
          layer = "top";
          "custom/nixos" = {
            format = "";
            interval = "once";
            tooltip = false;
          };
          "custom/separator" = {
            format = " ";
            interval = "once";
            tooltip = false;
          };
          modules-left = [
            "custom/nixos"
            "niri/workspaces"
            "custom/separator"
            "niri/window"
          ];
          modules-center = [
            "clock"
          ];
          modules-right = [
            "network#speed"
            "custom/separator"
            "pulseaudio"
            "custom/separator"
            "memory"
            "custom/separator"
            "cpu"
            "custom/separator"
            "backlight"
            "custom/separator"
            "battery"
            "custom/separator"
            "tray"
            "custom/separator"
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
          pulseaudio = {
            format = "{icon} {volume}% {format_source}";
            format-bluetooth = "{icon}  {volume}% {format_source}";
            format-bluetooth-muted = "  {icon} {format_source}";
            format-icons = {
              car = "";
              default = [
                ""
                ""
                ""
              ];
              hands-free = "";
              headphone = "";
              headset = "";
              phone = "";
              portable = "";
            };
            format-muted = " {format_source}";
            format-source = " {volume}%";
            format-source-muted = "";
            on-click = "${pkgs.pavucontrol}/bin/pavucontrol";
          };
          backlight = {
            format = "󰖨  {percent}%";
            on-scroll-down = "${pkgs.brightnessctl}/bin/brightnessctl set 1%-";
            on-scroll-up = "${pkgs.brightnessctl}/bin/brightnessctl set +1%";
          };
          battery = {
            interval = 10;
            format = "{icon}  {capacity}%";
            format-charging = "{icon}  {capacity}% 󱐋";
            format-plugged = "{icon}  {capacity}% ";
            format-icons = [
              ""
              ""
              ""
              ""
              ""
            ];
          };
          clock = {
            format = "{:%a %b %d %H:%M}";
            tooltip-format = "<big>{:%Y %B}</big>\n<tt><small>{calendar}</small></tt>";
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
            spacing = 14;
          };

          "custom/notification" = {
            escape = true;
            exec = "swaync-client -swb";
            exec-if = "which swaync-client";
            format = "{icon}";
            format-icons = {
              dnd-inhibited-none = "";
              dnd-inhibited-notification = "<span foreground='red'><sup></sup></span>";
              dnd-none = "";
              dnd-notification = "<span foreground='red'><sup></sup></span>";
              inhibited-none = "";
              inhibited-notification = "<span foreground='red'><sup></sup></span>";
              none = "";
              notification = "<span foreground='red'><sup></sup></span>";
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
  };
}
