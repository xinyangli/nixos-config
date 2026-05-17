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

  inherit (config.my-lib.settings) idpUrl;

  cfg = config.commonSettings.auth;

  kanidm_pkg = pkgs.kanidm_1_9;
in
{
  options.commonSettings.auth = {
    enable = mkEnableOption "Common auth settings for servers";
    sshAccess = mkEnableOption "kanidm-managed ssh access to this machine" // {
      default = true;
    };
    enableHowdy = mkEnableOption "howdy for logging into the machine";
  };

  config = lib.mkMerge [
    (mkIf cfg.enable {
      services.userborn.enable = true;
      users.users.root.hashedPassword = "$y$j9T$oJ8a7zKc3EV9HOf8qYKC6/$ZEq0Kl8rapeN/WKyJ8eXnTGoTpLb2W/LWLcS8QlNPPB";
      services.kanidm = {
        package = kanidm_pkg;
        client = {
          enable = true;
          settings = {
            uri = "https://${idpUrl}";
          };
        };
        unix.enable = true;
        unix.settings = {
          kanidm.pam_allowed_login_groups = [ "linux_users" ];
          default_shell = "${lib.getExe pkgs.fish}";
        };
      };
      security.polkit = {
        enable = true;
        persistentAuthentication = true;
        adminIdentities = [ "unix-group:unix_admin@${idpUrl}" ];
      };
      security.run0-sudo-shim.enable = true;
    })

    (mkIf (cfg.enable && cfg.sshAccess) {
      services.openssh = mkIf cfg.sshAccess {
        enable = true;
        authorizedKeysCommand = "/etc/ssh/auth %u";
        authorizedKeysCommandUser = "kanidm-ssh-runner";
        openFirewall = true;
        settings = {
          PasswordAuthentication = false;
          KbdInteractiveAuthentication = false;
          PermitRootLogin = lib.mkForce "no";
        };
      };

      environment.etc."ssh/auth" = {
        mode = "0555";
        text = ''
          #!/bin/sh
          ${kanidm_pkg}/bin/kanidm_ssh_authorizedkeys $1
        '';
      };
      users.groups.kanidm-ssh-runner = { };
      users.users.kanidm-ssh-runner = {
        isSystemUser = true;
        group = "kanidm-ssh-runner";
      };

      services.fail2ban.enable = true;
    })
    (mkIf (cfg.enable && cfg.enableHowdy) {
      security.pam.howdy.enable = true;
      services.howdy = {
        enable = true;
        control = "sufficient";
        settings = {
          core = {
            detection_notice = true;
          };
          video = {
            force_mjpeg = true;
          };
        };
      };
      services.linux-enable-ir-emitter.enable = true;

      systemd.services."polkit-agent-helper@" = {
        serviceConfig = {
          PrivateDevices = false;
          DeviceAllow = [
            "char-video4linux rw" # /dev/video* for the IR camera
          ];
        };
      };
    })
  ];
}
