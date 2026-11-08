{ config, pkgs, ... }:
let
  attic = "${pkgs.attic-client}/bin/attic";
  atticPush = pkgs.writeShellScript "hydra-attic-push" ''
    set -euo pipefail

    if ! ${pkgs.jq}/bin/jq -e '
      .buildStatus == 0 and (.job | startswith("tests.") | not)
    ' "$HYDRA_JSON" > /dev/null; then
      exit 0
    fi

    export XDG_CONFIG_HOME=/var/lib/hydra/queue-runner/attic
    ${attic} login attic "https://pek-0.cache.xiny.li:8443/" "$HYDRA_ATTIC_TOKEN"
    ${pkgs.jq}/bin/jq -r '.outputs[].path' "$HYDRA_JSON" |
      ${attic} push --stdin general
  '';
in
{
  sops.secrets = {
    "hydra/attic_token" = { };
  };
  sops.templates."hydra/env".content = ''
    HYDRA_ATTIC_TOKEN=${config.sops.placeholder."hydra/attic_token"}
  '';
  services.hydra = {
    enable = true;
    hydraURL = "https://hydra.u.xiny.li/";
    notificationSender = "hydra@localhost";
    useSubstitutes = true;
    minimumDiskFreeEvaluator = 20;
    minimumDiskFree = 20;
    extraConfig = ''
      allow_import_from_derivation = true
      <runcommand>
        command = ${atticPush}
      </runcommand>
    '';
  };

  # hydra.u.xiny.li resolves (via public DNS) to agate's mesh ULA,
  # so this vhost is reachable only from inside the gravity VRF.
  # TLS via deSEC DNS-01 (token in env), per-vhost binding to the
  # systemd-passed mesh socket created by custom.mesh-network.caddy.
  services.caddy.virtualHosts."hydra.u.xiny.li".extraConfig = ''
    bind ${config.custom.mesh-network.caddy.fdRefs."443"}
    tls {
      dns desec {
        token {env.DESEC_TOKEN}
      }
    }
    reverse_proxy 127.0.0.1:3000
  '';

  systemd.services.hydra-notify = {
    serviceConfig.EnvironmentFile = config.sops.templates."hydra/env".path;
  };
}
