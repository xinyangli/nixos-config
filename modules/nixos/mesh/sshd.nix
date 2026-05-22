{
  config,
  lib,
  pkgs,
  ...
}:

let
  cfg = config.custom.mesh-network.sshd;
  meshCfg = config.custom.mesh-network;
  ssh = config.services.openssh;
in
{
  options.custom.mesh-network.sshd = {
    enable = lib.mkOption {
      type = lib.types.bool;
      default = meshCfg.ipsec.enable;
      defaultText = lib.literalExpression "config.custom.mesh-network.ipsec.enable";
      description = ''
        Accept SSH connections that arrive on the gravity VRF and
        forward them to the host's existing sshd. Implemented as a
        `mesh-sshd.socket` (BindToDevice=gravity) plus a
        long-running `systemd-socket-proxyd` that dials 127.0.0.1:22
        for each accepted connection. One sshd process serves both
        scopes; mesh-side sessions show up to sshd as coming from
        127.0.0.1, so per-peer auth restrictions
        (`from=`, `Match Host`, IP-based logging) don't see the
        original mesh peer.
      '';
    };
  };

  config = lib.mkIf cfg.enable {
    assertions = [
      {
        assertion = meshCfg.ipsec.enable;
        message = "custom.mesh-network.sshd.enable requires custom.mesh-network.ipsec.enable so the gravity VRF exists for BindToDevice= to target.";
      }
      {
        assertion = ssh.enable;
        message = "custom.mesh-network.sshd.enable forwards to the host sshd on 127.0.0.1:22 — enable services.openssh too.";
      }
    ];

    systemd.sockets.mesh-sshd = {
      description = "SSH Socket (gravity VRF)";
      wantedBy = [ "sockets.target" ];
      socketConfig = {
        ListenStream = map toString ssh.ports;
        BindToDevice = "gravity";
      };
    };

    systemd.services.mesh-sshd = {
      description = "SSH forwarder for the gravity VRF";
      wantedBy = [ "multi-user.target" ];
      after = [ "sshd.service" ];
      serviceConfig = {
        # Without Sockets=, multi-user.target activation starts proxyd
        # before LISTEN_FDS is set and the socket queue stalls.
        Sockets = "mesh-sshd.socket";
        # systemd-socket-proxyd lives under lib/systemd/, not bin/, so
        # lib.getExe' (which assumes bin/) doesn't find it.
        ExecStart = "${pkgs.systemd}/lib/systemd/systemd-socket-proxyd 127.0.0.1:22";
        Restart = "on-failure";
        DynamicUser = true;
        PrivateTmp = true;
        ProtectSystem = "strict";
        ProtectHome = true;
        NoNewPrivileges = true;
      };
    };
  };
}
