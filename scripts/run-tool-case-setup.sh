#!/usr/bin/env bash
set -euo pipefail

if [[ -n "${TOOL_SETUP_APT_PACKAGES:-}" ]]; then
  mapfile -t apt_packages < <(printf '%s\n' "$TOOL_SETUP_APT_PACKAGES" | sed '/^$/d')
  if [[ "${#apt_packages[@]}" -gt 0 ]]; then
    sudo apt-get update
    sudo apt-get install -y --no-install-recommends "${apt_packages[@]}"
  fi
fi

if [[ -n "${TOOL_SETUP_COMMANDS:-}" ]]; then
  while IFS= read -r setup_command; do
    [[ -n "$setup_command" ]] || continue
    bash -euo pipefail -c "$setup_command"
  done <<< "$TOOL_SETUP_COMMANDS"
fi
