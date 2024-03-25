# Temporary workaround
{ config, pkgs, lib, ... }:
let
  cfg = config.services.ssh-tpm-agent;
in
{
  options = {
    services.ssh-tpm-agent.enable = lib.mkEnableOption "TPM supported ssh agent in go";
  };
  config = lib.mkIf cfg.enable {
    systemd.user.services.ssh-tpm-agent = {
      enable = true;
      unitConfig = {
        Description = "SSH TPM agent service";
        Documentation = "man:ssh-agent(1) man:ssh-add(1) man:ssh(1)";
        Requires = "ssh-tpm-agent.socket";
        ConditionEnvironment = "!SSH_AGENT_PID";
      };
      serviceConfig = {
        Environment = "SSH_AUTH_SOCK=%t/ssh-tpm-agent.socket";
        ExecStart = "${pkgs.ssh-tpm-agent}/bin/ssh-tpm-agent";
        PassEnvironment = "SSH_AGENT_PID";
        SuccessExitStatus = 2;
        Type = "simple";
      };
      wants = [ "ssh-tpm-agent.socket" ];
    };

    systemd.user.sockets.ssh-tpm-agent = {
      enable = true;
      description = "SSH TPM agent socket";
      socketConfig = {
        ListenStream = "%t/ssh-tpm-agent.sock";
        SocketMode = "0600";
        Service = "ssh-tpm-agent.service";
      };

      wantedBy = [ "sockets.target" ];
    };

    environment = {
      systemPackages = [ pkgs.ssh-tpm-agent ];
      extraInit = ''
        export SSH_AUTH_SOCK="$XDG_RUNTIME_DIR/ssh-tpm-agent.sock"
      '';
    };
  };
}
