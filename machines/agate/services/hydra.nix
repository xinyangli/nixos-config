{ config, pkgs, ... }:
{
  sops.secrets = {
    "hydra/attic_token" = { };
  };
  sops.templates."hydra/env".content = ''
    HYDRA_ATTIC_TOKEN=${config.sops.placeholder."hydra/attic_token"}
  '';
  services.hydra = {
    enable = true;
    hydraURL = "http://agate.coho-tet.ts.net:3000/";
    notificationSender = "hydra@localhost";
    buildMachinesFiles = [ ];
    useSubstitutes = true;
    minimumDiskFreeEvaluator = 20;
    minimumDiskFree = 20;
    extraConfig = ''
      allow_import_from_derivation = true
    '';
  };

  systemd.services.attic-watch-store = {
    wantedBy = [ "multi-user.target" ];
    after = [ "network-online.target" ];
    requires = [ "network-online.target" ];
    description = "Upload all store content to binary cache";
    environment = {
      # attic login write to $XDG_CONFIG_HOME/attic/config.toml
      XDG_CONFIG_HOME = "/var/lib/attic-watch-store";
    };
    serviceConfig = {
      DynamicUser = true;
      EnvironmentFile = config.sops.templates."hydra/env".path;
      StateDirectory = "attic-watch-store";
      WorkingDirectory = "%S/attic-watch-store";
      ExecStartPre = pkgs.writeShellScript "attic-watch-store-start-pre" ''
        ${pkgs.attic-client}/bin/attic login attic "https://pek-0.cache.xiny.li:8443/" "''$HYDRA_ATTIC_TOKEN"
      '';
      ExecStart = "${pkgs.attic-client}/bin/attic watch-store general";
    };
  };
}
