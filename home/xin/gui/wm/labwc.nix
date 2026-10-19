{
  config,
  pkgs,
  lib,
  ...
}:
let
  # Minimal waybar bar for labwc sessions. The main waybar config in
  # components/waybar.nix uses niri-specific modules and must not be reused.
  waybarLabwcConfig = builtins.toJSON {
    layer = "bottom";
    position = "top";
    height = 20;
    modules-left = [ "wlr/taskbar" ];
    modules-center = [ "clock" ];
    modules-right = [
      "wireplumber#sink"
      "battery"
      "tray"
    ];
    "wlr/taskbar" = {
      format = "{icon}";
      tooltip-format = "{title}";
      icon-size = 18;
    };
    clock = {
      format = "{:%a %b %d %H:%M}";
      tooltip-format = "<tt><small>{calendar}</small></tt>";
    };
    "wireplumber#sink" = {
      format = "{icon} {volume}%";
      format-muted = "";
      format-icons = [
        ""
        ""
        ""
      ];
      on-click-right = "wpctl set-mute @DEFAULT_AUDIO_SINK@ toggle";
      scroll-step = 2;
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
    };
    tray = {
      icon-size = 18;
      spacing = 10;
    };
  };
in
{
  # Basic labwc session config, mainly used to run darktable with
  # HDR/color-management support on a spare TTY.

  xdg.configFile = {
    "waybar/labwc-config.json".text = waybarLabwcConfig;

    "labwc/environment".text = ''
      # Needed so xdg-desktop-portal picks the wlroots portal config
      # (programs.labwc.enable sets xdg.portal.config.wlroots).
      XDG_CURRENT_DESKTOP=wlroots
      # HDR support in labwc requires the Vulkan renderer
      # (https://github.com/labwc/labwc/pull/3424)
      WLR_RENDERER=vulkan
    '';

    "labwc/rc.xml".text = ''
      <?xml version="1.0" encoding="UTF-8"?>
      <labwc_config>
        <core>
          <!-- Auto-enable HDR on outputs that support it (requires
               WLR_RENDERER=vulkan, see environment) -->
          <hdr>yes</hdr>
        </core>
        <keyboard>
          <default />
          <keybind key="W-Return"><action name="Execute" command="foot"/></keybind>
          <keybind key="W-Space"><action name="Execute" command="vicinae toggle"/></keybind>
          <keybind key="W-Alt-L"><action name="Execute" command="loginctl lock-session"/></keybind>
          <keybind key="XF86_AudioRaiseVolume"><action name="Execute" command="wpctl set-volume @DEFAULT_AUDIO_SINK@ 0.02+"/></keybind>
          <keybind key="XF86_AudioLowerVolume"><action name="Execute" command="wpctl set-volume @DEFAULT_AUDIO_SINK@ 0.02-"/></keybind>
          <keybind key="XF86_AudioMute"><action name="Execute" command="wpctl set-mute @DEFAULT_AUDIO_SINK@ toggle"/></keybind>
          <keybind key="XF86_AudioMicMute"><action name="Execute" command="wpctl set-mute @DEFAULT_AUDIO_SOURCE@ toggle"/></keybind>
          <keybind key="XF86_MonBrightnessUp"><action name="Execute" command="brightnessctl set +5%"/></keybind>
          <keybind key="XF86_MonBrightnessDown"><action name="Execute" command="brightnessctl set 5%-"/></keybind>
        </keyboard>
        <mouse>
          <default />
        </mouse>
      </labwc_config>
    '';

    "labwc/menu.xml".text = ''
      <?xml version="1.0" encoding="UTF-8"?>
      <openbox_menu>
        <menu id="root-menu">
          <item label="Terminal"><action name="Execute" command="foot"/></item>
          <item label="Launcher"><action name="Execute" command="vicinae toggle"/></item>
          <separator />
          <item label="Lock"><action name="Execute" command="loginctl lock-session"/></item>
          <item label="Exit"><action name="Execute" command="labwc --exit"/></item>
        </menu>
      </openbox_menu>
    '';

    "labwc/autostart" = {
      executable = true;
      text = ''
        #!/bin/sh
        # Expose the session environment to the systemd user manager and
        # D-Bus activated services, then start the usual user services
        # (swaync, wallpaper, swayidle, ...).
        ${pkgs.dbus}/bin/dbus-update-activation-environment --systemd WAYLAND_DISPLAY XDG_CURRENT_DESKTOP
        ${pkgs.systemd}/bin/systemctl --user import-environment WAYLAND_DISPLAY XDG_CURRENT_DESKTOP
        ${pkgs.systemd}/bin/systemctl --user start labwc-session.target
        ${pkgs.waybar}/bin/waybar -c "$HOME/.config/waybar/labwc-config.json" -s "$HOME/.config/waybar/style.css" &
      '';
    };
  };
}
