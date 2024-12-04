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
    ;

  cfg = config.commonSettings.auth;
in
{
  options.commonSettings.auth = {
    enable = mkEnableOption "Common auth settings for servers";
  };

  config = mkIf cfg.enable {
    services.kanidm = {
      enableClient = true;
      clientSettings = {
        uri = "https://auth.xinyang.life";
      };
      enablePam = true;
      unixSettings = {
        pam_allowed_login_groups = [ "linux_users" ];
        default_shell = "/bin/sh";
      };
    };

    services.openssh = {
      enable = true;
      authorizedKeysCommand = "/etc/ssh/auth %u";
      authorizedKeysCommandUser = "kanidm-ssh-runner";
      settings = {
        PasswordAuthentication = false;
        KbdInteractiveAuthentication = false;
        PermitRootLogin = lib.mkForce "no";
      };
    };

    environment.etc."ssh/auth" = {
      mode = "0555";
      text = ''
        #!${pkgs.stdenv.shell}
        ${pkgs.kanidm}/bin/kanidm_ssh_authorizedkeys $1
      '';
    };
    users.groups.wheel.members = [ "xin@auth.xinyang.life" ];
    users.groups.kanidm-ssh-runner = { };
    users.users.kanidm-ssh-runner = {
      isSystemUser = true;
      group = "kanidm-ssh-runner";
    };

    services.fail2ban.enable = true;

    security.sudo = {
      execWheelOnly = true;
      wheelNeedsPassword = false;
    };
  };
}
