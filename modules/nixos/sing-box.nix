{ config, pkgs, lib, utils, ... }:
let
  cfg = config.custom.sing-box;
  settingsFormat = pkgs.formats.json { };
in
{
  options = {
    custom.sing-box = {
      enable = lib.mkEnableOption "sing-box";

      package = lib.mkPackageOption pkgs "sing-box" { };

      stateDir = lib.mkOption {
        type = lib.types.path;
        default = "/var/lib/sing-box";
      };

      configFile = {
        urlFile = lib.mkOption {
          type = lib.types.path;
        };
        name = lib.mkOption {
          type = lib.types.str;
          default = "config.json";
        };
        hash = lib.mkOption {
          type = lib.types.str;
          example = "9a304bcb87d4c3f1e50f6281f25dd78635255ebde06cd4d2555729ecda43aed4";
        };
      };

      overrideSettings = lib.mkOption {
        type = lib.types.submodule {
          freeformType = settingsFormat.type;
          options = {
            route = {
              geoip.path = lib.mkOption {
                type = lib.types.path;
                default = "${pkgs.sing-geoip}/share/sing-box/geoip.db";
                defaultText = lib.literalExpression "\${pkgs.sing-geoip}/share/sing-box/geoip.db";
                description = lib.mdDoc ''
                  The path to the sing-geoip database.
                '';
              };
              geosite.path = lib.mkOption {
                type = lib.types.path;
                default = "${pkgs.sing-geosite}/share/sing-box/geosite.db";
                defaultText = lib.literalExpression "\${pkgs.sing-geosite}/share/sing-box/geosite.db";
                description = lib.mdDoc ''
                  The path to the sing-geosite database.
                '';
              };
            };
          };
        };
        default = { };
      };
    };
  };
  config = lib.mkIf cfg.enable {
    networking.firewall.trustedInterfaces = [ "tun0" ];

    systemd.packages = [ cfg.package ];

    systemd.services.sing-box = 
    let
      configFile = cfg.stateDir + "/${cfg.configFile.name}";
    in
      {
        preStart = ''
          umask 0077
          mkdir -p /etc/sing-box
          if ! [ -e ${configFile} ]; then
            ${pkgs.curl}/bin/curl "$(${pkgs.coreutils}/bin/cat ${cfg.configFile.urlFile})" > '${configFile}'
            test "${cfg.configFile.hash}" $(${pkgs.coreutils}/bin/sha256sum '${configFile}' | ${pkgs.coreutils}/bin/cut -d ' ' -f 1)
          fi 
          ${utils.genJqSecretsReplacementSnippet cfg.overrideSettings "/etc/sing-box/config.json"}
          ${cfg.package}/bin/sing-box merge -c '${configFile}' -c /etc/sing-box/config.json /etc/sing-box/config.json
        '';
        wantedBy = [ "multi-user.target" ];
      };
  };
}

