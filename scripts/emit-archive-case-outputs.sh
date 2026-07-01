#!/usr/bin/env bash
set -euo pipefail

case_id="${1:?case id is required}"
ref_key="${2:?case ref key is required}"
repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
case_file="${repo_root}/archive-cases/${case_id}.json"

if [[ ! -f "$case_file" ]]; then
  echo "Unknown archive case: ${case_id}" >&2
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

manifest_id="$(jq -r '.id' "$case_file")"
if [[ "$manifest_id" != "$case_id" ]]; then
  echo "Archive case file id mismatch: expected ${case_id}, got ${manifest_id}" >&2
  exit 1
fi

project_ref="$(jq -r --arg key "$ref_key" '.refs[$key] // ""' "$case_file")"
project_repo="$(jq -er '.source.repo' "$case_file")"
pain_url="$(jq -r '.source.pain_url // ""' "$case_file")"
proof_url="$(jq -r '.source.proof_url // ""' "$case_file")"
evidence_run="$(jq -r '.source.evidence_run // ""' "$case_file")"
secondary_evidence_run="$(jq -r '.source.secondary_evidence_run // ""' "$case_file")"
readiness="$(jq -r '.source.readiness // ""' "$case_file")"
expected_total_bytes="$(jq -r '.inventory.expected_total_bytes // 0' "$case_file")"
archive_sample_entries="$(jq -c '[.proof.archive_sample.entries[]? | {name, label, path, size_mib}]' "$case_file")"
archive_sample_entry_count="$(jq -r '.proof.archive_sample.entries | length // 0' "$case_file")"

write_output "case_id" "$case_id"
write_output "case_ref_key" "$ref_key"
write_output "benchmark_id" "${case_id}-${ref_key}"
write_output "project_repo" "$project_repo"
write_output "project_ref" "$project_ref"
write_output "pain_url" "$pain_url"
write_output "proof_url" "$proof_url"
write_output "evidence_run" "$evidence_run"
write_output "secondary_evidence_run" "$secondary_evidence_run"
write_output "readiness" "$readiness"
write_output "expected_total_bytes" "$expected_total_bytes"
write_output "archive_sample_entries" "$archive_sample_entries"
write_output "archive_sample_entry_count" "$archive_sample_entry_count"
