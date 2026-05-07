{
  config,
  pkgs,
  lib,
  ...
}:
let
  wallpaper_directory = config.home.homeDirectory + "/Pictures/Wallpapers";
  wallpaper_switch = pkgs.writeShellScript "wallpaper-switch" ''
    img=$(ls ${wallpaper_directory} | shuf | head -1)
    ${lib.getExe pkgs.awww} img ${wallpaper_directory}/$img
  '';
in
{
  services.awww.enable = true;
  systemd.user.services.bg-switch = {
    Install = {
      WantedBy = [ config.wayland.systemd.target ];
    };
    Unit = {
      After = [ config.wayland.systemd.target ];
    };
    Service = {
      ExecStart = "${wallpaper_switch}";
      Restart = "on-failure";
      RestartSec = "30s";
    };
  };
  systemd.user.timers.bg-switch = {
    Unit = {
      Description = "Switch wallpaper hourly";
    };
    Install = {
      WantedBy = [ config.wayland.systemd.target ];
    };
    Timer = {
      Unit = "bg-switch.service";
      OnCalendar = "hourly";
    };
  };

}
