#!/usr/bin/env bash

set -Eeuo pipefail

readonly SCRIPT_NAME=${0##*/}
readonly SCRIPT_DIR=$(cd -- "$(dirname -- "$0")" && pwd)
readonly REPO_VM_DIR=$(cd -- "$SCRIPT_DIR/.." && pwd)/.warp-vm

if [[ -n ${WARP_VM_DIR:-} ]]; then
  VM_DIR=$WARP_VM_DIR
else
  VM_DIR=$REPO_VM_DIR
fi

readonly VM_DIR
readonly SSH_PORT=${WARP_VM_SSH_PORT:-22222}
readonly PROXY_PORT=${WARP_PROXY_PORT:-10808}
readonly GUEST_PROXY_PORT=10808
readonly SSH_USER=${WARP_VM_SSH_USER:-codex}
readonly KNOWN_HOSTS=${WARP_VM_KNOWN_HOSTS:-"$VM_DIR/known_hosts"}
readonly ASKPASS=${WARP_VM_ASKPASS:-"$VM_DIR/jammy-askpass"}
readonly GOST_VERSION=3.2.6
readonly GOST_ARCHIVE=gost_${GOST_VERSION}_linux_amd64.tar.gz
readonly GOST_URL=https://github.com/go-gost/gost/releases/download/v${GOST_VERSION}/${GOST_ARCHIVE}
readonly GOST_SHA256=b39037b0380ea001fb3c0c28441c2e10bfc694f90682739a65b53e55dce5238b
readonly PROXY_URL=socks5h://127.0.0.1:$PROXY_PORT
WORK_DIR=

usage() {
  cat <<EOF
Usage: $SCRIPT_NAME {install|start|stop|status|check}

  install  Install pinned gost $GOST_VERSION and its systemd service in the VM.
           SSH is used only for this one-time provisioning step.
  start    Start the VM; gost starts automatically inside the guest.
  stop     Gracefully stop the VM.
  status   Show VM and local proxy status.
  check    Verify traffic exits through Cloudflare WARP.

Environment:
  WARP_VM_DIR       VM state directory
  WARP_VM_SSH_USER  guest SSH user (default: $SSH_USER)
  WARP_VM_SSH_PORT  host SSH port (default: $SSH_PORT)
  WARP_PROXY_PORT   host SOCKS port (default: $PROXY_PORT)
EOF
}

die() {
  printf 'error: %s\n' "$*" >&2
  exit 1
}

common_ssh_args=(
  -o ConnectTimeout=10
  -o NumberOfPasswordPrompts=1
  -o ServerAliveInterval=15
  -o UserKnownHostsFile="$KNOWN_HOSTS"
  -o StrictHostKeyChecking=yes
)

run_with_askpass() {
  if [[ -x $ASKPASS ]]; then
    DISPLAY=:0 SSH_ASKPASS="$ASKPASS" SSH_ASKPASS_REQUIRE=force setsid -w "$@"
  else
    "$@"
  fi
}

install_guest_files() {
  local remote_command
  remote_command="sudo -S -p '' sh -c 'install -m 0755 /tmp/gost /usr/local/bin/gost &&
    install -m 0644 /tmp/warp-gost.service /etc/systemd/system/warp-gost.service &&
    systemctl daemon-reload &&
    systemctl enable --now warp-svc &&
    systemctl enable warp-gost &&
    systemctl restart warp-gost' &&
    rm -f /tmp/gost /tmp/warp-gost.service"

  if [[ -x $ASKPASS ]]; then
    {
      "$ASKPASS"
      printf '\n'
    } | run_with_askpass ssh -p "$SSH_PORT" "${common_ssh_args[@]}" \
      "$SSH_USER@127.0.0.1" "$remote_command"
  else
    ssh -t -p "$SSH_PORT" "${common_ssh_args[@]}" \
      "$SSH_USER@127.0.0.1" "$remote_command"
  fi
}

ensure_vm_started() {
  "$SCRIPT_DIR/warp-vm.sh" start
}

install_gost() {
  ensure_vm_started
  command -v curl >/dev/null || die 'curl is not installed'
  command -v tar >/dev/null || die 'tar is not installed'
  command -v sha256sum >/dev/null || die 'sha256sum is not installed'
  command -v scp >/dev/null || die 'scp is not installed'
  command -v ssh >/dev/null || die 'ssh is not installed'

  WORK_DIR=$(mktemp -d)
  trap 'rm -rf -- "$WORK_DIR"' EXIT

  curl --fail --location --proto '=https' --tlsv1.2 \
    --output "$WORK_DIR/$GOST_ARCHIVE" "$GOST_URL"
  printf '%s  %s\n' "$GOST_SHA256" "$WORK_DIR/$GOST_ARCHIVE" | sha256sum --check --status \
    || die 'gost archive checksum verification failed'
  tar -xzf "$WORK_DIR/$GOST_ARCHIVE" -C "$WORK_DIR"
  [[ -x $WORK_DIR/gost ]] || die 'gost binary is missing from the release archive'

  cat > "$WORK_DIR/warp-gost.service" <<EOF
[Unit]
Description=SOCKS5 proxy through Cloudflare WARP
After=network-online.target warp-svc.service
Wants=network-online.target warp-svc.service

[Service]
ExecStart=/usr/local/bin/gost -L socks5://0.0.0.0:$GUEST_PROXY_PORT
Restart=on-failure
RestartSec=2
DynamicUser=true
NoNewPrivileges=true
PrivateTmp=true
ProtectHome=true
ProtectSystem=strict

[Install]
WantedBy=multi-user.target
EOF

  run_with_askpass scp -P "$SSH_PORT" "${common_ssh_args[@]}" \
    "$WORK_DIR/gost" "$WORK_DIR/warp-gost.service" \
    "$SSH_USER@127.0.0.1:/tmp/"

  install_guest_files

  printf 'gost installed; proxy endpoint: %s\n' "$PROXY_URL"
}

check_proxy() {
  command -v curl >/dev/null || die 'curl is not installed'
  command -v nc >/dev/null || die 'nc is not installed'
  nc -z -w 2 127.0.0.1 "$PROXY_PORT" >/dev/null 2>&1 \
    || die "SOCKS port 127.0.0.1:$PROXY_PORT is not listening"

  local trace
  trace=$(curl --fail --silent --show-error --max-time 20 \
    --proxy "$PROXY_URL" https://www.cloudflare.com/cdn-cgi/trace)
  printf '%s\n' "$trace" | grep -E '^(ip|loc|warp|gateway)='
  printf '%s\n' "$trace" | grep -Fxq 'warp=on' \
    || die 'Cloudflare trace did not report warp=on'

  printf 'WARP proxy check passed\n'
}

case ${1:-} in
  install) install_gost ;;
  start) ensure_vm_started; check_proxy ;;
  stop) "$SCRIPT_DIR/warp-vm.sh" stop ;;
  status) "$SCRIPT_DIR/warp-vm.sh" status ;;
  check) check_proxy ;;
  -h | --help | help) usage ;;
  *) usage >&2; exit 2 ;;
esac
