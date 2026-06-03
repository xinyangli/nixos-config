{
  config,
  pkgs,
  lib,
  ...
}:
let
  inherit (lib)
    mkEnableOption
    mkIf
    mkOption
    types
    makeBinPath
    ;

  cfg = config.commonSettings.comin;

  ntfyUrl = config.my-lib.settings.ntfyUrl;
  topic = "comin-reboot";

  envPath = config.sops.templates."comin-reboot.env".path;

  publisher = pkgs.writeShellScript "comin-post-deploy" ''
    set -euo pipefail
    export PATH=${
      makeBinPath [
        pkgs.coreutils
        pkgs.curl
        pkgs.openssl
      ]
    }

    [ "''${COMIN_STATUS:-}" = "done" ] || exit 0

    needs_reboot() {
      for c in kernel initrd kernel-modules systemd; do
        b=$(readlink -f "/run/booted-system/$c" 2>/dev/null) || return 0
        n=$(readlink -f "/run/current-system/$c" 2>/dev/null) || return 0
        [ "$b" = "$n" ] || return 0
      done
      return 1
    }

    needs_reboot || { echo "comin-post-deploy: no reboot needed"; exit 0; }

    if [ ! -r ${envPath} ]; then
      echo "comin-post-deploy: ${envPath} unreadable; skipping ntfy" >&2
      exit 0
    fi
    set -a; . ${envPath}; set +a

    token=$(openssl rand -hex 16)
    umask 0077
    printf '%s' "$token" > /run/comin-reboot-token
    chmod 0600 /run/comin-reboot-token

    auth=$(printf '%s:%s' "$NTFY_USER" "$NTFY_PASSWORD" | base64 -w0)
    host=''${COMIN_HOSTNAME:-unknown}
    short=''${COMIN_GIT_SHA:0:8}
    body="generation ''${COMIN_GENERATION:-?}, commit ''${short:-?}"
    actions="http, Reboot, $NTFY_URL/$NTFY_TOPIC, method=POST, body=confirm:$token, headers.Authorization=Basic $auth, clear=true"

    curl -fsSL --max-time 30 \
      -u "$NTFY_USER:$NTFY_PASSWORD" \
      -H "Title: $host reboot needed" \
      -H "Actions: $actions" \
      -d "$body" \
      "$NTFY_URL/$NTFY_TOPIC" >/dev/null \
      || echo "comin-post-deploy: ntfy publish failed" >&2
  '';

  subscriber = pkgs.writeShellScript "comin-reboot-subscriber" ''
    set -uo pipefail
    export PATH=${
      makeBinPath [
        pkgs.coreutils
        pkgs.ntfy-sh
        pkgs.jq
        pkgs.systemd
      ]
    }

    : "''${NTFY_URL:?}" "''${NTFY_TOPIC:?}" "''${NTFY_USER:?}" "''${NTFY_PASSWORD:?}"

    ntfy subscribe --user "$NTFY_USER:$NTFY_PASSWORD" "$NTFY_URL/$NTFY_TOPIC" \
      | while IFS= read -r line; do
          msg=$(jq -r '.message // empty' <<<"$line") || continue
          case "$msg" in
            confirm:*) token=''${msg#confirm:} ;;
            *) continue ;;
          esac

          [[ "$token" =~ ^[a-f0-9]{32}$ ]] || { echo "subscriber: bad token"; continue; }
          [ -r /run/comin-reboot-token ] || { echo "subscriber: no pending token"; continue; }

          expected=$(cat /run/comin-reboot-token)
          if [ "$token" != "$expected" ]; then
            echo "subscriber: token mismatch"
            continue
          fi

          echo "subscriber: confirmed; rebooting"
          rm -f /run/comin-reboot-token
          systemctl reboot
          break
        done
  '';
in
{
  options.commonSettings.comin = {
    enable = mkEnableOption "auto updater with comin";
    executor = mkOption {
      type = types.enum [
        "nix"
        "garnix"
        "hydra"
      ];
      default = "garnix";
      description = ''
        Which backend comin uses to evaluate + build.
        `nix` builds locally (used by agate, which runs the Hydra, and by
        hafnon, the build worker — both avoid depending on something they
        themselves provide).
        `garnix` pulls from garnix.io; suitable for low-power hosts.
        `hydra` pulls from the local Hydra on agate (jobset
        `nixos-config-deploy`); only valid for hosts in `hydraJobs`.
      '';
    };
  };

  config = mkIf cfg.enable {
    services.comin = {
      enable = true;
      remotes = [
        {
          name = "origin";
          url = "https://github.com/xinyangli/nixos-config.git";
          branches.main.name = "deploy";
          branches.testing.name = "deploy-test";
        }
        {
          name = "forgejo";
          url = "https://git.xiny.li/xin/nixos-config.git";
          branches.main.name = "deploy";
          branches.testing.name = "deploy-test";
        }
      ];
      hostname = config.networking.hostName;
      executor.type = cfg.executor;
      executor.hydra = lib.mkIf (cfg.executor == "hydra") {
        base_url = "http://agate.coho-tet.ts.net:3000";
        project = "nixos-config";
      };
      postDeploymentCommand = publisher;
    };

    sops.secrets."ntfy/comin_password" = {
      sopsFile = ../../../machines/secrets.yaml;
    };

    sops.templates."comin-reboot.env".content = ''
      NTFY_URL=${ntfyUrl}
      NTFY_TOPIC=${topic}
      NTFY_USER=comin
      NTFY_PASSWORD=${config.sops.placeholder."ntfy/comin_password"}
    '';

    systemd.services.comin-reboot-subscriber = {
      description = "comin reboot confirmation listener";
      wantedBy = [ "multi-user.target" ];
      after = [ "network-online.target" ];
      wants = [ "network-online.target" ];
      serviceConfig = {
        EnvironmentFile = envPath;
        ExecStart = subscriber;
        Restart = "always";
        RestartSec = 10;
      };
    };
  };
}
