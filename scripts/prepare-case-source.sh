#!/usr/bin/env bash
set -euo pipefail

case_id="${1:?case id is required}"
ref_key="${2:?case ref key is required}"
repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
case_file="${repo_root}/cases/${case_id}.json"

if [[ ! -f "$case_file" ]]; then
  echo "Unknown case: ${case_id}" >&2
  exit 1
fi

if ! command -v jq >/dev/null 2>&1; then
  echo "jq is required" >&2
  exit 1
fi

project_repo="$(jq -er '.source.repo' "$case_file")"
project_ref="$(jq -er --arg key "$ref_key" '.refs[$key]' "$case_file")"
source_dir="${repo_root}/.work/${case_id}/source"
clone_url="https://github.com/${project_repo}.git"

rm -rf "${repo_root}/.work/${case_id}"
mkdir -p "$source_dir"
git init "$source_dir"
git -C "$source_dir" remote add origin "$clone_url"
git -C "$source_dir" -c protocol.version=2 fetch --depth=1 origin "$project_ref"
git -C "$source_dir" checkout --detach FETCH_HEAD

actual_ref="$(git -C "$source_dir" rev-parse HEAD)"
if [[ "$actual_ref" != "$project_ref" ]]; then
  echo "Prepared ${actual_ref}, expected ${project_ref}" >&2
  exit 1
fi

if [[ -n "${GITHUB_OUTPUT:-}" ]]; then
  {
    echo "source_path=.work/${case_id}/source"
    echo "project_ref=${actual_ref}"
  } >> "$GITHUB_OUTPUT"
fi

