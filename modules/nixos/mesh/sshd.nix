{
  config,
  lib,
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
        Listen for SSH inside the gravity VRF via systemd socket
        activation: a `mesh-sshd.socket` unit with `BindToDevice=gravity`
        and `Accept=yes` hands each accepted FD to a per-connection
        `mesh-sshd@<id>.service` instance that runs `sshd -i` against
        the same `/etc/ssh/sshd_config` the host sshd reads. The host
        sshd's default-scope listener is unaffected.
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
        message = "custom.mesh-network.sshd.enable shares /etc/ssh/sshd_config with services.openssh — enable it too.";
      }
    ];

    systemd.sockets.mesh-sshd = {
      description = "SSH Socket (gravity VRF)";
      wantedBy = [ "sockets.target" ];
      socketConfig = {
        # Inherit the host sshd's port list — same kernel port in two
        # routing scopes (BindToDevice=gravity scopes ours; tcp_l3mdev_accept=0
        # keeps default-scope traffic on the host sshd).
        ListenStream = map toString ssh.ports;
        BindToDevice = "gravity";
        # Accept=yes spawns mesh-sshd@<peer>.service per connection; the
        # accepted FD lands on sshd's stdin. systemd derives the template
        # name from the socket name (Service= isn't honoured for Accept=yes),
        # so we mirror upstream's sshd@.service below as mesh-sshd@.service.
        Accept = true;
        TriggerLimitIntervalSec = 0;
      };
    };

    # Mirror of upstream `services."sshd@"` — same per-connection inetd-style
    # invocation, same `/etc/ssh/sshd_config`. We can't clone via
    # `config.systemd.services."sshd@"` (sibling read inside the same freeform
    # attrset loops the module eval), so we re-derive from `services.openssh.*`
    # public options. Anything the user configures on services.openssh.*
    # applies to both templates because they read the same sshd_config.
    systemd.services."mesh-sshd@" = {
      description = "SSH per-connection Daemon (gravity VRF)";
      after = [
        "network.target"
        "sshd-keygen.service"
      ];
      wants = lib.optional ssh.generateHostKeys "sshd-keygen.service";
      stopIfChanged = false;
      path = [ ssh.package ];
      environment.LD_LIBRARY_PATH = config.system.nssModules.path;

      serviceConfig = {
        ExecStart = lib.concatStringsSep " " [
          # Leading `-` ignores exit failures from the sshd handling a single
          # connection (e.g. authentication denials) — same as upstream.
          "-${lib.getExe' ssh.package "sshd"}"
          "-i"
          "-D"
          "-f /etc/ssh/sshd_config"
        ];
        KillMode = "process";
        StandardInput = "socket";
        StandardError = "journal";
      };
    };
  };
}
