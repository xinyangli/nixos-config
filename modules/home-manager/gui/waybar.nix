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
      style = readFile ./waybar.css;
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
            "network#if"
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

          "network#if" = {
            format = "{ifname}";
            format-disconnected = "󰌙";
            format-ethernet = "󰌘";
            format-linked = "{ifname} (No IP)  󰈁";
            format-wifi = "{icon}";
            format-icons = [
              "󰤯"
              "󰤟"
              "󰤢"
              "󰤥"
              "󰤨"
            ];
            interval = 10;
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
        };
      };
      systemd.enable = true;
    };
  };
}
