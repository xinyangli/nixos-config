{
  config,
  lib,
  ...
}:

let
  cfg = config.custom.mesh-network.sshd;
  meshCfg = config.custom.mesh-network;
  ssh = config.services.openssh;
  # Mirror the upstream sshd.service shape rather than cloning
  # `config.systemd.services.sshd` directly: reading the merged service
  # while defining a sibling under the same freeform attrset triggers
  # infinite recursion. Everything that matters to the user
  # (sshd_config contents, host keys, package, PAM service name)
  # lives in `services.openssh.*`, so configuration changes there flow
  # to both sshds via the shared /etc/ssh/sshd_config and host-key paths.
in
{
  options.custom.mesh-network.sshd = {
    enable = lib.mkOption {
      type = lib.types.bool;
      default = meshCfg.ipsec.enable;
      defaultText = lib.literalExpression "config.custom.mesh-network.ipsec.enable";
      description = ''
        Run a second sshd bound to the gravity VRF via systemd
        BindNetworkInterface=. Inherits its configuration from
        services.openssh — same sshd_config, same host keys, same PAM
        stack (sshd uses the service name "sshd" unconditionally).
        Changing services.openssh.settings.* updates both daemons.
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
        message = "custom.mesh-network.sshd.enable inherits all configuration from services.openssh — enable services.openssh too.";
      }
      {
        # startWhenNeeded replaces sshd.service with the sshd@ template,
        # which our parallel always-on instance doesn't model.
        assertion = !ssh.startWhenNeeded;
        message = "custom.mesh-network.sshd.enable expects services.openssh.startWhenNeeded = false (no socket-activated template).";
      }
    ];

    systemd.services.mesh-sshd = {
      description = "SSH Daemon bound to the gravity VRF";
      wantedBy = [ "multi-user.target" ];
      # gravity device must exist before sshd binds, otherwise the BPF
      # hook installed by BindNetworkInterface= has no ifindex to point
      # at and the unit fails at startup.
      after = [
        "network.target"
        "sshd-keygen.service"
        "sys-subsystem-net-devices-gravity.device"
      ];
      bindsTo = [ "sys-subsystem-net-devices-gravity.device" ];
      wants = lib.optional ssh.generateHostKeys "sshd-keygen.service";
      stopIfChanged = false;
      path = [ ssh.package ];
      environment.LD_LIBRARY_PATH = config.system.nssModules.path;
      restartTriggers = [ config.environment.etc."ssh/sshd_config".source ];

      serviceConfig = {
        Type = "notify-reload";
        Restart = "always";
        # Reuse the host's rendered sshd_config verbatim; override only
        # the pidfile so the two daemons don't race on /run/sshd.pid
        # (cosmetic — systemd tracks the main PID via notify).
        ExecStart = "${lib.getExe' ssh.package "sshd"} -D -f /etc/ssh/sshd_config -o PidFile=/run/mesh-sshd.pid";
        KillMode = "process";
        BindNetworkInterface = "gravity";
      };
    };
  };
}
