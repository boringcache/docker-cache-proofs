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
  setup_workdir=""
  if [[ -n "${SOURCE_PATH:-}" ]]; then
    working_directory="${TOOL_WORKING_DIRECTORY:-.}"
    if [[ "$working_directory" == "." ]]; then
      setup_workdir="${SOURCE_PATH%/}"
    else
      setup_workdir="${SOURCE_PATH%/}/${working_directory#./}"
    fi

    if [[ ! -d "$setup_workdir" ]]; then
      echo "Missing setup working directory: $setup_workdir" >&2
      exit 1
    fi
  fi

  while IFS= read -r setup_command; do
    [[ -n "$setup_command" ]] || continue
    if [[ -n "$setup_workdir" ]]; then
      (cd "$setup_workdir" && bash -euo pipefail -c "$setup_command")
    else
      bash -euo pipefail -c "$setup_command"
    fi
  done <<< "$TOOL_SETUP_COMMANDS"
fi
