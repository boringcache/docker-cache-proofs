#!/usr/bin/env bash
set -euo pipefail

source_path="${SOURCE_PATH:?SOURCE_PATH is required}"
source_dir="${source_path%/}"
devcontainer_json="$source_dir/.devcontainer/devcontainer.json"

if [[ ! -f "$devcontainer_json" ]]; then
  echo "Missing Z3Wire devcontainer config at $devcontainer_json" >&2
  exit 1
fi

if grep -q '"runArgs"' "$devcontainer_json"; then
  exit 0
fi

perl -0pi -e 's#("workspaceFolder":\s*"/workspace",\n)#$1  "runArgs": ["--network=host"],\n#' "$devcontainer_json"

if ! grep -q '"runArgs": \["--network=host"\]' "$devcontainer_json"; then
  echo "Failed to add host networking to Z3Wire devcontainer config" >&2
  exit 1
fi
