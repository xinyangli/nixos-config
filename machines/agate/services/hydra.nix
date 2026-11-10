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

    buildDescription="$(${pkgs.jq}/bin/jq -r '"build \(.id): \(.project)/\(.jobset)/\(.job)"' "$HYDRA_JSON")"

    export XDG_CONFIG_HOME=/var/lib/hydra/queue-runner/attic
    loginOutput="$(${attic} login attic "https://pek-0.cache.xiny.li:8443/" "$HYDRA_ATTIC_TOKEN" 2>&1)" || {
      status=$?
      printf 'Attic login failed for %s (exit %d):\n%s\n' \
        "$buildDescription" "$status" "$loginOutput" >&2
      exit "$status"
    }
    pushOutput="$(
      ${pkgs.jq}/bin/jq -r '.outputs[].path' "$HYDRA_JSON" 2>&1 |
        ${attic} push --stdin general 2>&1
    )" || {
      status=$?
      printf 'Attic push failed for %s (exit %d):\n%s\n' \
        "$buildDescription" "$status" "$pushOutput" >&2
      exit "$status"
    }
  '';
in
{
  sops.secrets = {
    "hydra/attic_token" = { };
  };
  sops.templates."hydra/env".content = ''
    HYDRA_ATTIC_TOKEN=${config.sops.placeholder."hydra/attic_token"}
  '';
  sops.templates."hydra/github-auth.conf" = {
    group = "hydra";
    mode = "0440";
    content = ''
      <github_authorization>
        xinyangli = token ${config.sops.placeholder."nix/github_public_token"}
      </github_authorization>
    '';
  };
  services.hydra = {
    enable = true;
    hydraURL = "https://hydra.u.xiny.li/";
    notificationSender = "hydra@localhost";
    useSubstitutes = true;
    minimumDiskFreeEvaluator = 5;
    minimumDiskFree = 5;
    extraConfig = ''
      allow_import_from_derivation = true
      Include ${config.sops.templates."hydra/github-auth.conf".path}
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
