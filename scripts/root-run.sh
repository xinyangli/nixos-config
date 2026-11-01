#!/usr/bin/env bash
# Run a command as root on a u.xiny.li host over SSH, answering the
# polkit OATH (TOTP) prompt with a fresh code from rbw.
#
# Usage: root-run.sh <host> [cmd...]   (default cmd: whoami)
#
# Examples:
#   root-run.sh agate
#   root-run.sh agate systemctl status comin
set -euo pipefail

host=${1:?usage: root-run.sh <host> [cmd...]}
shift
cmd=${*:-"whoami"}

case $host in
  *.*) target=$host ;;
  *) target=$host.u.xiny.li ;;
esac

code=$(rbw code 362ba7eb-a179-456a-a61a-0d37ad3cdab6)

# The OATH prompt appears on the SSH TTY after a short delay (polkit);
# feed the code then, and give sudo a moment to finish before the pipe closes.
{ sleep 3; printf '%s\n' "$code"; sleep 3; } | ssh -tt "$target" "sudo $cmd"
