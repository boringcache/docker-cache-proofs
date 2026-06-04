#!/usr/bin/env bash
set -euo pipefail

case_id="${1:?case id is required}"
ref_key="${2:?case ref key is required}"
repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
case_file="${repo_root}/tool-cases/${case_id}.json"

if [[ ! -f "$case_file" ]]; then
  echo "Unknown tool case: ${case_id}" >&2
  exit 1
fi

if ! command -v jq >/dev/null 2>&1; then
  echo "jq is required" >&2
  exit 1
fi

write_output() {
  local key="$1"
  local value="$2"
  echo "${key}=${value}" >> "$GITHUB_OUTPUT"
}

write_multiline_output() {
  local key="$1"
  local value="$2"
  local delimiter="tool_case_${key}_$(date +%s%N)"
  {
    echo "${key}<<${delimiter}"
    printf '%s\n' "$value"
    echo "${delimiter}"
  } >> "$GITHUB_OUTPUT"
}

manifest_id="$(jq -r '.id' "$case_file")"
if [[ "$manifest_id" != "$case_id" ]]; then
  echo "Tool case file id mismatch: expected ${case_id}, got ${manifest_id}" >&2
  exit 1
fi

project_ref="$(jq -er --arg key "$ref_key" '.refs[$key]' "$case_file")"
project_repo="$(jq -er '.source.repo' "$case_file")"
adapter="$(jq -er '.adapter' "$case_file")"
rust_toolchain="$(jq -r '.tool.rust_toolchain // ""' "$case_file")"
working_directory="$(jq -r '.tool.working_directory // "."' "$case_file")"
measured_command="$(jq -er '.tool.measured_command' "$case_file")"
runner_label="$(jq -r '.workflow.runner_label // "ubuntu-latest"' "$case_file")"
free_disk_space="$(jq -r '.workflow.free_disk_space // false' "$case_file")"
timeout_minutes="$(jq -r '.workflow.timeout_minutes // 180' "$case_file")"
source_path=".work/${case_id}/source"
setup_apt_packages="$(jq -r '.tool.setup_apt_packages[]?' "$case_file" | sed '/^$/d')"
setup_commands="$(jq -r '.tool.setup_commands[]?' "$case_file" | sed '/^$/d')"
pain_url="$(jq -r '.source.pain_url // ""' "$case_file")"
evidence_run="$(jq -r '.source.evidence_run // ""' "$case_file")"
readiness="$(jq -r '.source.readiness // ""' "$case_file")"

write_output "case_id" "$case_id"
write_output "case_ref_key" "$ref_key"
write_output "adapter" "$adapter"
write_output "benchmark_id" "${case_id}-${ref_key}"
write_output "cache_id" "$case_id"
write_output "project_repo" "$project_repo"
write_output "project_ref" "$project_ref"
write_output "source_path" "$source_path"
write_output "rust_toolchain" "$rust_toolchain"
write_output "working_directory" "$working_directory"
write_output "runner_label" "$runner_label"
write_output "free_disk_space" "$free_disk_space"
write_output "timeout_minutes" "$timeout_minutes"
write_output "pain_url" "$pain_url"
write_output "evidence_run" "$evidence_run"
write_output "readiness" "$readiness"
write_multiline_output "measured_command" "$measured_command"
write_multiline_output "setup_apt_packages" "$setup_apt_packages"
write_multiline_output "setup_commands" "$setup_commands"
