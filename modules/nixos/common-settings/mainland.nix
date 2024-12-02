{
  config,
  lib,
  pkgs,
  ...
}:

let
  inherit (lib)
    mkIf
    mkOption
    types
    mkDefault
    ;

  cfg = config.inMainland;
in
{
  options.inMainland = mkOption {
    type = types.bool;
    default = config.time.timeZone == "Asia/Shanghai";
  };

  config = mkIf cfg {
    nix.settings.extra-substituters = [
      "https://mirrors.cernet.edu.cn/nix-channels/store?priority=20"
    ];

    networking.timeServers = [
      "cn.ntp.org.cn"
      "ntp.ntsc.ac.cn"
    ];

    services.dae = {
      enable = mkDefault true;
    };
  };
}
