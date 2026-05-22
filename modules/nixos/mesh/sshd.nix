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

  # A standalone sshd_config rather than reusing /etc/ssh/sshd_config: the
  # host config pins Port/ListenAddress from services.openssh.{ports,listenAddresses},
  # which would either collide with the mesh port or force users to special-case it.
  # Keeping it small and inheriting only host keys + PAM keeps the surface obvious;
  # extraConfig is the escape hatch for site overrides.
  meshSshdConfig = pkgs.writeText "mesh-sshd_config" ''
    Port ${toString cfg.port}
    HostKey /etc/ssh/ssh_host_ed25519_key
    HostKey /etc/ssh/ssh_host_rsa_key
    AuthorizedKeysFile .ssh/authorized_keys /etc/ssh/authorized_keys.d/%u
    UsePAM yes
    KbdInteractiveAuthentication no
    PrintMotd no
    PidFile /run/mesh-sshd.pid
    Subsystem sftp ${ssh.package}/libexec/sftp-server
    ${cfg.extraConfig}
  '';
in
{
  options.custom.mesh-network.sshd = {
    # Defaults to mesh enablement: every mesh node gets a VRF-bound sshd
    # without per-host opt-in. Set to false explicitly to drop it.
    enable = lib.mkOption {
      type = lib.types.bool;
      default = meshCfg.ipsec.enable;
      defaultText = lib.literalExpression "config.custom.mesh-network.ipsec.enable";
      description = "Run a second sshd bound to the gravity VRF via systemd BindNetworkInterface=.";
    };
    port = lib.mkOption {
      type = lib.types.port;
      default = 22;
      description = ''
        TCP port for the mesh sshd. Can match the host sshd's port because
        BindNetworkInterface= scopes the listening socket to the gravity
        VRF while the host sshd lives in the default routing scope.
      '';
    };
    extraConfig = lib.mkOption {
      type = lib.types.lines;
      default = "";
      description = "Extra sshd_config lines appended to the mesh sshd's config.";
    };
    openFirewall = lib.mkOption {
      type = lib.types.bool;
      default = true;
      description = ''
        Open the firewall on this port. Safe even when set globally:
        BindNetworkInterface= already scopes the listener to the gravity
        VRF, so a SYN to the port on a non-mesh interface meets no listener
        and is RST'd.
      '';
    };
  };

  config = lib.mkIf cfg.enable {
    assertions = [
      {
        assertion = meshCfg.ipsec.enable;
        message = "custom.mesh-network.sshd.enable requires custom.mesh-network.ipsec.enable so the gravity VRF exists for BindNetworkInterface= to target.";
      }
      {
        assertion = ssh.enable;
        message = "custom.mesh-network.sshd.enable reuses services.openssh's host keys and PAM stack — enable services.openssh too.";
      }
    ];

    systemd.services.mesh-sshd = {
      description = "SSH Daemon bound to the gravity VRF";
      wantedBy = [ "multi-user.target" ];
      # The gravity device must exist before sshd binds, otherwise the eBPF
      # hook installed by BindNetworkInterface= has nothing to point at.
      after = [
        "network.target"
        "sshd-keygen.service"
        "sys-subsystem-net-devices-gravity.device"
      ];
      bindsTo = [ "sys-subsystem-net-devices-gravity.device" ];
      wants = [ "sshd-keygen.service" ];
      stopIfChanged = false;
      path = [ ssh.package ];
      restartTriggers = [ meshSshdConfig ];

      serviceConfig = {
        ExecStart = "${lib.getExe' ssh.package "sshd"} -D -f ${meshSshdConfig}";
        KillMode = "process";
        Restart = "on-failure";
        BindNetworkInterface = "gravity";
      };
    };

    security.pam.services.mesh-sshd = {
      startSession = true;
      showMotd = true;
      unixAuth = ssh.settings.PasswordAuthentication or false;
    };

    networking.firewall.allowedTCPPorts = lib.mkIf cfg.openFirewall [ cfg.port ];
  };
}
