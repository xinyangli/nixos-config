#!/usr/bin/env bash
set -euo pipefail

repo_root="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)"
secret_file="$repo_root/machines/secrets.yaml"

for command in sops oathtool qrencode head od; do
  if ! command -v "$command" >/dev/null; then
    printf 'Missing required command: %s\n' "$command" >&2
    printf 'Run: nix shell nixpkgs#sops nixpkgs#oath-toolkit nixpkgs#qrencode\n' >&2
    exit 1
  fi
done

secret="$(head -c 20 /dev/urandom | od -An -v -tx1 | tr -d ' \n')"
if [[ ! "$secret" =~ ^[0-9a-f]{40}$ ]]; then
  printf 'Failed to generate a 20-byte hexadecimal seed.\n' >&2
  exit 1
fi

base32=""
while read -r label colon value _; do
  if [[ "$label" == "Base32" && "$colon" == "secret:" ]]; then
    base32="$value"
  fi
done < <(oathtool --totp -v "$secret")
if [[ -z "$base32" ]]; then
  printf 'Failed to derive the Base32 authenticator secret.\n' >&2
  exit 1
fi

sops set "$secret_file" '["oath"]["users.oath"]' \
  "\"HOTP/T30/6 xin@auth.xiny.li - $secret\""
unset secret

otpauth="otpauth://totp/run0:xin%40auth.xiny.li?secret=$base32&issuer=run0&algorithm=SHA1&digits=6&period=30"
printf '\nAuthenticator secret: %s\n' "$base32"
printf 'Settings: 6-digit, 30-second SHA-1 TOTP\n\n'
qrencode -t ANSIUTF8 -l M "$otpauth"
printf '\nUpdated machines/secrets.yaml with the encrypted seed.\n'
printf 'After deployment, reset the writable OATH file on each enabled host as described in note.md.\n'
