{
  config,
  lib,
  pkgs,
  ...
}:

let
  inherit (lib)
    mkIf
    mkEnableOption
    mkOption
    types
    ;

  cfg = config.commonSettings.auth;
in
{
  options.commonSettings.auth = {
    enable = mkEnableOption "Common auth settings for servers";
  };

  config = mkIf cfg.enable {
    custom.kanidm-client = {
      enable = true;
      uri = "https://auth.xinyang.life";
      asSSHAuth = {
        enable = true;
        allowedGroups = [ "linux_users" ];
      };
      sudoers = [ "xin@auth.xinyang.life" ];
    };

    services.openssh = {
      settings = {
        PasswordAuthentication = false;
        KbdInteractiveAuthentication = false;
        PermitRootLogin = "no";
        GSSAPIAuthentication = "no";
        KerberosAuthentication = "no";
      };
    };
    services.fail2ban.enable = true;

    security.sudo = {
      execWheelOnly = true;
      wheelNeedsPassword = false;
    };
  };
}
