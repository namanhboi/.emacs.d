#!/usr/bin/env bash
# Install the JDT version compatible with DSLabs' Lombok configuration.
set -euo pipefail

config_dir=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)
runtime_dir="$config_dir/savefile/jdtls-runtime/1.55.0"
archive_name=jdt-language-server-1.55.0-202601131729.tar.gz
expected_sha256=90627c9f03704dbb404f37651625d0751c078ab7534246023d53adcea1411b91

if [[ -x "$runtime_dir/bin/jdtls" ]]; then
  printf 'JDT LS 1.55.0 is already installed at %s\n' "$runtime_dir"
  exit 0
fi

archive=$(mktemp /tmp/emacs-jdtls.XXXXXX.tar.gz)
trap 'rm -f -- "$archive"' EXIT
curl -L --fail --retry 2 \
  "https://download.eclipse.org/jdtls/milestones/1.55.0/$archive_name" \
  -o "$archive"
printf '%s  %s\n' "$expected_sha256" "$archive" | sha256sum --check -
mkdir -p -- "$runtime_dir"
tar -xzf "$archive" -C "$runtime_dir"
printf 'Installed JDT LS 1.55.0 at %s\n' "$runtime_dir"
