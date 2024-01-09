{ config, pkgs, lib, ... }:
with lib;

let
  cfg = config.custom.kanidm-client;
in
{
  options = {
    custom.kanidm-client = {
      enable = mkEnableOption "Kanidm client service";
      asSSHAuth = mkOption {
        type = types.submodule {
          options = {
            enable = mkEnableOption "Kanidm as system authentication source";
            allowedGroups = mkOption {
              type = types.listOf types.str;
              example = [ "linux_users" ];
            };
          };
        };
      };
      sudoers = mkOption {
        type = types.listOf types.str;
        default = [ ];
      };
      uri = mkOption {
        type = types.str;
      };
    };
  };
  config = mkIf cfg.enable {
    services.kanidm = mkMerge
      [ (mkIf cfg.enable {
          enableClient = true;
          clientSettings = {
            uri = cfg.uri;
          };
        })
        (mkIf cfg.asSSHAuth.enable {
           enablePam = true;
           unixSettings = {
             pam_allowed_login_groups = cfg.asSSHAuth.allowedGroups;
             default_shell = "/bin/sh";
           };
        })
      ];
    services.openssh = mkIf cfg.asSSHAuth.enable {
      enable = true;
      authorizedKeysCommand = "/etc/ssh/auth %u";
      authorizedKeysCommandUser = "kanidm-ssh-runner"; 
    };
    environment.etc."ssh/auth" = mkIf cfg.asSSHAuth.enable {
      mode = "0555";
      text = ''
        #!${pkgs.stdenv.shell}
        ${pkgs.kanidm}/bin/kanidm_ssh_authorizedkeys $1
      '';
    };
    users.groups.wheel.members = cfg.sudoers;
    users.groups.kanidm-ssh-runner = { };
    users.users.kanidm-ssh-runner = { isSystemUser = true; group = "kanidm-ssh-runner"; };
  };
}

