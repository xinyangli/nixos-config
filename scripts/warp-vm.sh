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
readonly DISK=${WARP_VM_DISK:-"$VM_DIR/jammy.qcow2"}
readonly LUKS_KEY=${WARP_VM_LUKS_KEY:-"$VM_DIR/jammy-luks.key"}
readonly PID_FILE=$VM_DIR/jammy.pid
readonly SERIAL_SOCKET=$VM_DIR/jammy-serial.sock
readonly SERIAL_LOG=$VM_DIR/jammy-serial.log
readonly MONITOR_SOCKET=$VM_DIR/jammy-monitor.sock
readonly SSH_PORT=${WARP_VM_SSH_PORT:-22222}
readonly PROXY_PORT=${WARP_PROXY_PORT:-10808}
readonly MEMORY=${WARP_VM_MEMORY:-4096}
readonly CPUS=${WARP_VM_CPUS:-1}
readonly HOST_CPU=${WARP_VM_CPU:-4}
readonly START_TIMEOUT=${WARP_VM_START_TIMEOUT:-120}

usage() {
  cat <<EOF
Usage: $SCRIPT_NAME {start|stop|status|console}

Environment:
  WARP_VM_DIR           VM state directory (default: $REPO_VM_DIR)
  WARP_VM_MEMORY        RAM in MiB (default: $MEMORY)
  WARP_VM_CPUS          vCPU count (default: $CPUS)
  WARP_VM_CPU           host CPU affinity (default: $HOST_CPU, an E-core)
  WARP_VM_SSH_PORT      host SSH port (default: $SSH_PORT)
  WARP_PROXY_PORT       host SOCKS port (default: $PROXY_PORT)
  WARP_VM_START_TIMEOUT boot timeout in seconds (default: $START_TIMEOUT)
EOF
}

die() {
  printf 'error: %s\n' "$*" >&2
  exit 1
}

vm_pid() {
  [[ -r $PID_FILE ]] || return 1
  local pid
  read -r pid < "$PID_FILE"
  [[ $pid =~ ^[0-9]+$ ]] || return 1
  printf '%s\n' "$pid"
}

is_running() {
  local pid
  pid=$(vm_pid) || return 1
  kill -0 "$pid" 2>/dev/null || return 1
  [[ -r /proc/$pid/cmdline ]] || return 1
  tr '\0' '\n' < "/proc/$pid/cmdline" | grep -Fq "file=$DISK,"
}

port_is_open() {
  nc -z -w 1 127.0.0.1 "$1" >/dev/null 2>&1
}

ssh_is_ready() {
  ssh-keyscan -T 2 -p "$SSH_PORT" 127.0.0.1 2>/dev/null \
    | grep -q '^\[127\.0\.0\.1\]'
}

socks_is_ready() {
  local response
  response=$(printf '\005\001\000' \
    | nc -N -w 2 127.0.0.1 "$PROXY_PORT" 2>/dev/null \
    | od -An -tx1 \
    | tr -d ' \n' || true)
  [[ $response == 0500* ]]
}

wait_for_file() {
  local path=$1
  local remaining=$2
  while ((remaining > 0)); do
    [[ -S $path ]] && return 0
    sleep 1
    ((remaining -= 1))
  done
  return 1
}

unlock_grub() {
  local passphrase character key

  [[ -r $LUKS_KEY ]] || die "missing LUKS key: $LUKS_KEY"
  wait_for_file "$MONITOR_SOCKET" 10 || die "QEMU monitor socket was not created"
  IFS= read -r passphrase < "$LUKS_KEY" || [[ -n $passphrase ]]
  [[ $passphrase =~ ^[0-9a-fA-F]+$ ]] \
    || die 'the automatic GRUB unlock currently supports hexadecimal passphrases only'

  # SeaBIOS and GRUB display the cryptodisk prompt on VGA rather than ttyS0.
  sleep 3
  {
    for ((index = 0; index < ${#passphrase}; index += 1)); do
      character=${passphrase:index:1}
      if [[ $character == [A-F] ]]; then
        key=shift-${character,,}
      else
        key=$character
      fi
      printf 'sendkey %s 10\n' "$key"
      sleep 0.03
    done
    printf 'sendkey ret 10\n'
  } | nc -U -N -w 10 "$MONITOR_SOCKET" >/dev/null 2>&1 \
    || die 'failed to send the encrypted-disk passphrase to GRUB'

  unset passphrase character key
}

unlock_luks() {
  local log_offset=$1
  local deadline=$((SECONDS + START_TIMEOUT))

  [[ -r $LUKS_KEY ]] || die "missing LUKS key: $LUKS_KEY"
  wait_for_file "$SERIAL_SOCKET" 10 || die "QEMU serial socket was not created"

  while ((SECONDS < deadline)); do
    if ssh_is_ready || socks_is_ready; then
      return 0
    fi

    if tail -c "+$((log_offset + 1))" "$SERIAL_LOG" 2>/dev/null \
      | grep -Fq 'Please unlock disk '; then
      {
        cat "$LUKS_KEY"
        printf '\n'
      } | nc -U -N -w 2 "$SERIAL_SOCKET" >/dev/null 2>&1 || true
      return 0
    fi

    is_running || die "QEMU exited during boot; inspect $SERIAL_LOG"
    sleep 1
  done

  die "timed out waiting for the LUKS prompt; inspect $SERIAL_LOG"
}

start_vm() {
  command -v qemu-system-x86_64 >/dev/null || die 'qemu-system-x86_64 is not installed'
  command -v taskset >/dev/null || die 'taskset is not installed'
  command -v nc >/dev/null || die 'nc is not installed'
  command -v ssh-keyscan >/dev/null || die 'ssh-keyscan is not installed'
  [[ -c /dev/kvm ]] || die '/dev/kvm is unavailable'
  [[ $CPUS =~ ^[1-9][0-9]*$ ]] || die 'WARP_VM_CPUS must be a positive integer'
  [[ $HOST_CPU =~ ^[0-9]+$ ]] || die 'WARP_VM_CPU must be a non-negative integer'
  [[ -d /sys/devices/system/cpu/cpu$HOST_CPU ]] || die "host CPU $HOST_CPU does not exist"
  [[ $(cat "/sys/devices/system/cpu/cpu$HOST_CPU/online" 2>/dev/null || printf 1) == 1 ]] \
    || die "host CPU $HOST_CPU is offline"
  [[ -r $DISK ]] || die "missing VM disk: $DISK"

  if is_running; then
    if socks_is_ready; then
      printf 'warp VM and gost proxy are ready at socks5h://127.0.0.1:%s\n' "$PROXY_PORT"
      return 0
    fi
    if ssh_is_ready; then
      printf 'warp VM is already running (pid %s); gost is not listening yet\n' "$(vm_pid)"
      return 0
    fi
    die "warp VM process $(vm_pid) is running, but the guest is not ready; inspect $SERIAL_LOG"
  fi

  if port_is_open "$SSH_PORT"; then
    die "host port $SSH_PORT is already in use"
  fi
  if port_is_open "$PROXY_PORT"; then
    die "host port $PROXY_PORT is already in use"
  fi

  install -d -m 700 "$VM_DIR"
  rm -f -- "$PID_FILE" "$SERIAL_SOCKET" "$MONITOR_SOCKET"
  touch "$SERIAL_LOG"
  chmod 600 "$DISK" "$SERIAL_LOG" "$LUKS_KEY"
  local log_offset
  log_offset=$(stat -c '%s' "$SERIAL_LOG")

  taskset --cpu-list "$HOST_CPU" qemu-system-x86_64 \
    -name warp-jammy \
    -machine q35,accel=kvm \
    -cpu host \
    -smp "$CPUS" \
    -m "$MEMORY" \
    -device virtio-rng-pci,addr=0x4 \
    -drive "file=$DISK,format=qcow2,if=none,id=osdisk,discard=unmap" \
    -device virtio-blk-pci,drive=osdisk,addr=0x3 \
    -netdev "user,id=net0,hostfwd=tcp:127.0.0.1:$SSH_PORT-:22,hostfwd=tcp:127.0.0.1:$PROXY_PORT-:10808" \
    -device virtio-net-pci,netdev=net0,addr=0x2 \
    -chardev "socket,id=serial0,path=$SERIAL_SOCKET,server=on,wait=off,logfile=$SERIAL_LOG,logappend=on" \
    -serial chardev:serial0 \
    -monitor "unix:$MONITOR_SOCKET,server=on,wait=off" \
    -display none \
    -daemonize \
    -pidfile "$PID_FILE"

  unlock_grub
  unlock_luks "$log_offset"

  local deadline=$((SECONDS + START_TIMEOUT))
  while ((SECONDS < deadline)); do
    if socks_is_ready; then
      printf 'warp VM and gost proxy are ready at socks5h://127.0.0.1:%s\n' "$PROXY_PORT"
      return 0
    fi
    if ssh_is_ready; then
      local gost_deadline=$((SECONDS + 15))
      while ((SECONDS < gost_deadline && SECONDS < deadline)); do
        if socks_is_ready; then
          printf 'warp VM and gost proxy are ready at socks5h://127.0.0.1:%s\n' "$PROXY_PORT"
          return 0
        fi
        is_running || die "QEMU exited during boot; inspect $SERIAL_LOG"
        sleep 1
      done
      printf 'warp VM is ready for SSH on 127.0.0.1:%s; gost is not listening yet\n' "$SSH_PORT"
      printf 'run scripts/warp-proxy.sh install once, then scripts/warp-proxy.sh check\n'
      return 0
    fi
    is_running || die "QEMU exited during boot; inspect $SERIAL_LOG"
    sleep 1
  done

  die "VM boot timed out; inspect $SERIAL_LOG"
}

stop_vm() {
  if ! is_running; then
    printf 'warp VM is not running\n'
    return 0
  fi

  [[ -S $MONITOR_SOCKET ]] || die "missing QEMU monitor socket: $MONITOR_SOCKET"
  printf 'system_powerdown\n' | nc -U -N -w 2 "$MONITOR_SOCKET" >/dev/null 2>&1 || true

  local deadline=$((SECONDS + 60))
  while ((SECONDS < deadline)); do
    if ! is_running; then
      rm -f -- "$PID_FILE" "$SERIAL_SOCKET" "$MONITOR_SOCKET"
      printf 'warp VM stopped\n'
      return 0
    fi
    sleep 1
  done

  die 'the guest did not shut down within 60 seconds; refusing to force-stop it'
}

status_vm() {
  printf 'VM directory: %s\n' "$VM_DIR"
  if is_running; then
    printf 'VM: running (pid %s, vCPUs %s, host CPU %s)\n' "$(vm_pid)" "$CPUS" \
      "$(taskset -pc "$(vm_pid)" 2>/dev/null | sed 's/.*: //' || printf unknown)"
  else
    printf 'VM: stopped\n'
  fi

  if ssh_is_ready; then
    printf 'SSH: 127.0.0.1:%s open\n' "$SSH_PORT"
  else
    printf 'SSH: unavailable\n'
  fi

  if socks_is_ready; then
    printf 'SOCKS: socks5h://127.0.0.1:%s ready\n' "$PROXY_PORT"
  else
    printf 'SOCKS: unavailable\n'
  fi
}

console_vm() {
  is_running || die 'warp VM is not running'
  [[ -S $SERIAL_SOCKET ]] || die "missing QEMU serial socket: $SERIAL_SOCKET"
  exec nc -U "$SERIAL_SOCKET"
}

case ${1:-} in
  start) start_vm ;;
  stop) stop_vm ;;
  status) status_vm ;;
  console) console_vm ;;
  -h | --help | help) usage ;;
  *) usage >&2; exit 2 ;;
esac
