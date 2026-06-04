{
  config,
  lib,
  pkgs,
  ...
}:

let
  cfg = config.custom.mesh-network.gost;
  meshCfg = config.custom.mesh-network;
in
{
  options.custom.mesh-network.gost = {
    enable = lib.mkEnableOption "gost auto-protocol proxy forwarding from default VRF to gravity mesh";

    port = lib.mkOption {
      type = lib.types.port;
      default = 1080;
      description = ''
        TCP port gost listens on in the default VRF. Clients connect here
        using HTTP CONNECT or SOCKS4/5; gost dials the target with
        SO_BINDTODEVICE=gravity, placing outgoing connections in the gravity
        VRF context so the kernel routes them through table 100.
      '';
    };

    listenAddress = lib.mkOption {
      type = lib.types.str;
      default = "0.0.0.0";
      description = "Address to listen on (default VRF, not gravity-scoped).";
    };

    openFirewall = lib.mkOption {
      type = lib.types.bool;
      default = false;
      description = "Open the TCP listen port in the firewall.";
    };

    extraArgs = lib.mkOption {
      type = lib.types.listOf lib.types.str;
      default = [ ];
      description = ''
        Extra arguments appended to the gost ExecStart, e.g. additional
        `-L` listeners or `-F` forwarding chains.
      '';
    };
  };

  config = lib.mkIf cfg.enable {
    assertions = [
      {
        assertion = meshCfg.ipsec.enable;
        message = "custom.mesh-network.gost.enable requires custom.mesh-network.ipsec.enable — the gravity VRF device must exist for SO_BINDTODEVICE=gravity to resolve.";
      }
    ];

    systemd.services.gost-mesh = {
      description = "gost auto-protocol proxy (default VRF → gravity mesh)";
      wantedBy = [ "multi-user.target" ];
      after = [ "systemd-networkd.service" ];
      serviceConfig = {
        ExecStart = lib.concatStringsSep " " (
          [
            (lib.getExe pkgs.gost)
            "-L"
            "auto://${cfg.listenAddress}:${toString cfg.port}?interface=gravity"
          ]
          ++ cfg.extraArgs
        );
        Restart = "on-failure";
        DynamicUser = true;
        NoNewPrivileges = true;
        ProtectSystem = "strict";
        ProtectHome = true;
        PrivateTmp = true;
        # SO_BINDTODEVICE requires CAP_NET_RAW for unprivileged processes.
        AmbientCapabilities = [ "CAP_NET_RAW" ];
        CapabilityBoundingSet = [ "CAP_NET_RAW" ];
      };
    };

    networking.firewall.allowedTCPPorts = lib.mkIf cfg.openFirewall [ cfg.port ];
  };
}
