{ config, pkgs, ... }:

let
  inherit (config.my-lib.settings) idpUrl;

  accountName = "nix_access_hydra";
  spn = "${accountName}@${idpUrl}";
  homeDir = "/home/${spn}";
  sshDir = "${homeDir}/.ssh";
  sshKey = "${sshDir}/id_ed25519";
  sshKeyPub = "${sshKey}.pub";
  sshKeyVerified = "${sshKey}.verified";

  builderAlias = "hafnon-builder";
  hafnonHost = "homo.j8.network";
  hafnonPort = 27200;
in
{
  # Token authenticates as `nix_provisioner` (a kanidm service account in
  # the `nix_access_hydra_admins` group), NOT as nix_access_hydra itself —
  # SAs cannot self-write ssh_publickey. Generate with
  #   kanidm service-account api-token generate nix_provisioner agate --rw
  sops.secrets."nix/builder_account_idm_token" = { };

  nix.distributedBuilds = true;
  nix.buildMachines = [
    {
      hostName = builderAlias;
      sshUser = accountName;
      inherit sshKey;
      protocol = "ssh-ng";
      systems = [ "x86_64-linux" ];
      maxJobs = 4;
      speedFactor = 2;
      supportedFeatures = [
        "kvm"
        "nixos-test"
        "big-parallel"
        "benchmark"
      ];
    }
  ];

  # nix.buildMachines.hostName is fed directly to ssh, which has no
  # `host:port` syntax. Use ssh_config to hide the non-default port.
  programs.ssh.extraConfig = ''
    Host ${builderAlias}
      HostName ${hafnonHost}
      Port ${toString hafnonPort}
  '';

  # known_hosts uses the bracketed `[host]:port` form for non-default ports.
  programs.ssh.knownHosts.${builderAlias} = {
    hostNames = [ "[${hafnonHost}]:${toString hafnonPort}" ];
    publicKey = "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIEwCkBq3yNVaxFbD8cTNybL0x9FHbwcupHdOhIN81Tde";
  };

  systemd.services.nix-access-hydra-keygen = {
    description = "Bootstrap and register SSH keypair for ${accountName}";
    wantedBy = [ "multi-user.target" ];
    before = [ "nix-daemon.service" ];
    after = [
      "network-online.target"
      "kanidm-unixd.service"
    ];
    wants = [
      "network-online.target"
      "kanidm-unixd.service"
    ];
    path = with pkgs; [
      coreutils
      curl
      jq
      openssh
      util-linux
    ];
    serviceConfig = {
      Type = "oneshot";
      RemainAfterExit = true;
    };
    script = ''
      set -eu

      # Once ssh-ng dispatch has ever round-tripped, subsequent boots are
      # no-ops. Remove the marker to force re-keygen + re-verification.
      if [ -e '${sshKeyVerified}' ]; then
        exit 0
      fi

      TOKEN_FILE='${config.sops.secrets."nix/builder_account_idm_token".path}'
      KANIDM_BASE='https://${idpUrl}/v1/service_account/${accountName}/_ssh_pubkeys'
      KEY_TAG='${config.networking.hostName}'

      for _ in $(seq 1 60); do
        if id ${accountName} >/dev/null 2>&1; then
          break
        fi
        sleep 1
      done
      if ! id ${accountName} >/dev/null 2>&1; then
        echo "${accountName} is not visible via NSS after 60s — kanidm-unixd may not be reachable." >&2
        exit 1
      fi

      if [ ! -e '${sshKey}' ]; then
        install -d -o ${accountName} -g nix-builders -m 0700 '${homeDir}' '${sshDir}'
        runuser -u ${accountName} -- \
          ssh-keygen -t ed25519 -N "" -C "${accountName}@$KEY_TAG" -f '${sshKey}'
      fi

      if [ ! -r "$TOKEN_FILE" ]; then
        echo "Service-account token not readable at $TOKEN_FILE; populate via 'sops edit machines/$KEY_TAG/secrets.yaml'." >&2
        exit 1
      fi

      TOKEN=$(cat "$TOKEN_FILE")
      PUBKEY=$(cat '${sshKeyPub}')
      PAYLOAD=$(jq -nc --arg tag "$KEY_TAG" --arg key "$PUBKEY" '[$tag, $key]')

      # Replace any previous entry under this tag; 404 means the tag was
      # already absent which is fine.
      DELETE_STATUS=$(curl --silent --output /dev/null --write-out '%{http_code}' \
        --request DELETE \
        --header "Authorization: Bearer $TOKEN" \
        "$KANIDM_BASE/$KEY_TAG" || true)
      echo "kanidm DELETE $KEY_TAG -> $DELETE_STATUS"

      curl --fail --silent --show-error \
        --request POST \
        --header "Authorization: Bearer $TOKEN" \
        --header "Content-Type: application/json" \
        --data "$PAYLOAD" \
        "$KANIDM_BASE" \
        >/dev/null
      echo "Registered ${accountName} $KEY_TAG pubkey on kanidm."

      echo "Verifying SSH access to ${builderAlias} (10 min cap)..."
      DEADLINE=$(( $(date +%s) + 600 ))
      ATTEMPT=0
      while [ "$(date +%s)" -lt "$DEADLINE" ]; do
        ATTEMPT=$((ATTEMPT + 1))
        if ssh -o BatchMode=yes -o ConnectTimeout=10 \
              -i '${sshKey}' \
              ${accountName}@${builderAlias} true; then
          : >'${sshKeyVerified}'
          echo "SSH access verified after $ATTEMPT attempt(s)."
          exit 0
        fi
        echo "Attempt $ATTEMPT failed; retrying in 15s..."
        sleep 15
      done

      echo "Could not verify SSH access to ${builderAlias} within 10 minutes." >&2
      exit 1
    '';
  };
}
