{ config, lib, pkgs, ... }:

let
  inherit (lib) mkIf mkEnableOption mkOption types;

  cfg = config.programs.oidc-agent;
  providerFormat = pkgs.formats.json {};
in
{
  options.programs.oidc-agent = {
    enable = mkEnableOption "OpenID Connect Agent";
    package = mkOption {
      type = types.package;
      default = pkgs.oidc-agent;
      description = ''
        Which oidc-agent package to use
      '';
    };
    providers = mkOption {
      type = providerFormat.type;
      default = {};
      description = ''
        Configuration of providers which contains a json array of json objects
        each describing an issuer, see https://indigo-dc.gitbook.io/oidc-agent/configuration/issuers
      '';
    };
  };

  config = mkIf cfg.enable {
    systemd.user.services.oidc-agent = {
      unitConfig = {
        Description = "OpenID Connect Agent";
        Documentation = "man:oidc-agent(1)";
      };
      serviceConfig = {
        ExecStart = "${cfg.package}/bin/oidc-agent -d --log-stderr -a %t/oidc-agent";
      };
    };

    # environment.etc."oidc-agent/config".source = "${pkgs.oidc-agent}/etc/oidc-agent/config";

    # environment.etc."oidc-agent/issuer.config.d".source =
    #   "${pkgs.oidc-agent}/etc/oidc-agent/issuer.config.d";

    # environment.etc."oidc-agent/issuer.config".source =
    #  providerFormat.generate "oidc-agent-issuer.config" cfg.providers;

    environment.extraInit = ''export OIDC_SOCK="$XDG_RUNTIME_DIR/oidc-agent"'';
  };
}
