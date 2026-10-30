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

  kanidm_pkg = pkgs.kanidm_1_11;
in
{
  options.commonSettings.auth = {
    enable = mkEnableOption "Common auth settings for servers";
    sshAccess = mkEnableOption "kanidm-managed ssh access to this machine" // {
      default = true;
    };
    totp.enable = mkEnableOption "TOTP as an alternative to passwords for Polkit authentication" // {
      default = true;
    };
    enableHowdy = mkEnableOption "howdy for logging into the machine";
    u2f = {
      enable = mkEnableOption "Use pam-u2f for authentication";
    };
  };

  config = lib.mkMerge [
    (mkIf cfg.enable {
      services.userborn.enable = true;
      users.users.root.hashedPassword = "$y$j9T$oJ8a7zKc3EV9HOf8qYKC6/$ZEq0Kl8rapeN/WKyJ8eXnTGoTpLb2W/LWLcS8QlNPPB";
      users.groups.systemd-journal.members = [
        "agent_pam_access@${idpUrl}"
        "xin@${idpUrl}"
      ];
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
        extraConfig = ''
          polkit.addRule(function(action, subject) {
            if (action.id == "org.freedesktop.systemd1.manage-units" &&
                subject.user == "agent_pam_access@${idpUrl}") {
              return polkit.Result.YES;
            }
          });
        '';
      };
      security.run0-sudo-shim.enable = true;
    })

    (mkIf (cfg.enable && cfg.totp.enable) {
      environment.systemPackages = [ pkgs.oath-toolkit ];
      security.pam.oath = {
        usersFile = "/var/lib/oath/users.oath";
        digits = 6;
        window = 5;
      };
      security.pam.services.polkit-1 = {
        oathAuth = true;
        rules.auth.oath.control = lib.mkForce "sufficient";
      };
      sops.secrets."oath/users.oath" = {
        sopsFile = ../../../machines/secrets.yaml;
        owner = "root";
        mode = "0600";
      };
      systemd.services.oath-usersfile = {
        wantedBy = [ "sysinit.target" ];
        after = [ "local-fs.target" "sops-install-secrets.service" ];
        before = [ "sysinit.target" "polkit-agent-helper.socket" ];
        unitConfig.DefaultDependencies = "no";
        serviceConfig = {
          Type = "oneshot";
          RemainAfterExit = true;
          ExecStart = pkgs.writeShellScript "oath-usersfile-init" ''
            set -eu
            ${pkgs.coreutils}/bin/install -d -o root -g root -m 0700 /var/lib/oath
            if [ ! -e /var/lib/oath/users.oath ]; then
              ${pkgs.coreutils}/bin/install -o root -g root -m 0600 \
                "${config.sops.secrets."oath/users.oath".path}" /var/lib/oath/users.oath
            fi
          '';
        };
      };
      systemd.services."polkit-agent-helper@".serviceConfig.ReadWritePaths = [ "/var/lib/oath" ];
    })

    (mkIf (cfg.enable && cfg.sshAccess) {
      services.opkssh = {
        enable = true;
        providers = {
          kanidm = {
            issuer = "https://${idpUrl}/oauth2/openid/opkssh";
            clientId = "opkssh";
            lifetime = "24h";
          };
        };
        authorizations = [
          {
            # Kanidm unixd presents the full SPN to sshd's AuthorizedKeysCommand.
            user = "agent_pam_access@${idpUrl}";
            # opkssh matches a bare sub value; a "sub:" prefix is compared literally.
            principal = "a9b5e8c8-1f96-49ca-911b-b8dcd737da86";
            issuer = "https://${idpUrl}/oauth2/openid/opkssh";
          }
        ];
      };

      services.openssh = mkIf cfg.sshAccess {
        enable = true;
        # The opkssh module wires itself directly; use a wrapper for Kanidm fallback.
        authorizedKeysCommand = lib.mkForce "/etc/ssh/auth %u %k %t";
        authorizedKeysCommandUser = lib.mkForce "root";
        openFirewall = true;
        settings = {
          PasswordAuthentication = false;
          KbdInteractiveAuthentication = false;
          PermitRootLogin = lib.mkForce "no";
        };
      };

      environment.etc."opk/providers".user = lib.mkForce "root";
      environment.etc."opk/auth_id".user = lib.mkForce "root";

      environment.etc."ssh/auth" = {
        mode = "0555";
        text = ''
          #!/bin/sh
          if ! ${pkgs.util-linux}/bin/runuser -u opksshuser -- \
            /run/wrappers/bin/opkssh verify "$1" "$2" "$3"
          then
            ${pkgs.util-linux}/bin/runuser -u kanidm-ssh-runner -- \
              ${kanidm_pkg}/bin/kanidm_ssh_authorizedkeys "$1"
          fi
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

    (mkIf (cfg.enable && cfg.u2f.enable) {
      security.pam.u2f = {
        enable = true;
        authFile = pkgs.writeText "pam-u2f-authfile" ''
          xin@auth.xiny.li:MToYpwZldcEPfTX6PwtfvjlMS8fTm8MI0Ihsn2YpURMAAQ/He2AhlkitTWaCGm4zPU6ht12+RwDybP1EQM1/w07G////+Q==,EdXBfc/oWWWZEXEOmPm7e7vhwhb2E2f6ASOz3xHCjmMT/eJ4Vr8ZLdlqEsfBRwlpxXgbo2oJbYS1IwYp7LVfaw==,es256,+presence
        '';
      };
    })

    (mkIf (config.networking.wireless.iwd.enable) {
      services.dbus.packages = [
        (pkgs.writeTextFile {
          name = "iwd-custom-dbus-policy";
          destination = "/share/dbus-1/system.d/iwd-custom.conf";
          text = ''
            <!DOCTYPE busconfig PUBLIC "-//freedesktop//DTD D-BUS Bus Configuration 1.0//EN"
             "http://www.freedesktop.org/standards/dbus/1.0/busconfig.dtd">
            <busconfig>
              <policy group="unix_admin@${idpUrl}">
                <allow send_destination="net.connman.iwd"/>
              </policy>
            </busconfig>
          '';
        })
      ];
    })
  ];
}
