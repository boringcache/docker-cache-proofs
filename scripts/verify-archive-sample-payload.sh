#!/usr/bin/env bash
set -euo pipefail

case_id="${1:?case id is required}"
ref_key="${2:?case ref key is required}"
entry_name="${3:?archive sample entry name is required}"
entry_path="${4:?archive sample entry path is required}"
output_dir="${5:-archive-results}"

if ! command -v jq >/dev/null 2>&1; then
  echo "jq is required" >&2
  exit 1
fi

sha256_file() {
  if command -v sha256sum >/dev/null 2>&1; then
    sha256sum "$1" | awk '{print $1}'
  else
    shasum -a 256 "$1" | awk '{print $1}'
  fi
}

file_size() {
  stat -c%s "$1" 2>/dev/null || stat -f%z "$1"
}

manifest_path="${entry_path}/.boringcache-archive-sample.json"
if [[ ! -f "$manifest_path" ]]; then
  echo "Missing restored archive sample manifest: ${manifest_path}" >&2
  exit 1
fi

manifest_case_id="$(jq -r '.case_id' "$manifest_path")"
manifest_ref_key="$(jq -r '.ref_key' "$manifest_path")"
manifest_entry_name="$(jq -r '.entry_name' "$manifest_path")"
payload_relpath="$(jq -r '.payload_path' "$manifest_path")"
expected_bytes="$(jq -r '.payload_bytes' "$manifest_path")"
expected_sha256="$(jq -r '.payload_sha256' "$manifest_path")"

if [[ "$manifest_case_id" != "$case_id" ]]; then
  echo "Restored manifest case mismatch: expected ${case_id}, got ${manifest_case_id}" >&2
  exit 1
fi

if [[ "$manifest_ref_key" != "$ref_key" ]]; then
  echo "Restored manifest ref mismatch: expected ${ref_key}, got ${manifest_ref_key}" >&2
  exit 1
fi

if [[ "$manifest_entry_name" != "$entry_name" ]]; then
  echo "Restored manifest entry mismatch: expected ${entry_name}, got ${manifest_entry_name}" >&2
  exit 1
fi

payload_path="${entry_path}/${payload_relpath}"
if [[ ! -f "$payload_path" ]]; then
  echo "Missing restored archive sample payload: ${payload_path}" >&2
  exit 1
fi

actual_bytes="$(file_size "$payload_path")"
actual_sha256="$(sha256_file "$payload_path")"
if [[ "$actual_bytes" != "$expected_bytes" ]]; then
  echo "Restored payload size mismatch: expected ${expected_bytes}, got ${actual_bytes}" >&2
  exit 1
fi

if [[ "$actual_sha256" != "$expected_sha256" ]]; then
  echo "Restored payload checksum mismatch: expected ${expected_sha256}, got ${actual_sha256}" >&2
  exit 1
fi

mkdir -p "$output_dir"
jq -n \
  --arg schema_version "archive_sample_restore.v1" \
  --arg case_id "$case_id" \
  --arg ref_key "$ref_key" \
  --arg entry_name "$entry_name" \
  --arg entry_path "$entry_path" \
  --arg payload_sha256 "$actual_sha256" \
  --arg verified_at "$(date -u +%Y-%m-%dT%H:%M:%SZ)" \
  --argjson payload_bytes "$actual_bytes" \
  '{
    schema_version: $schema_version,
    case_id: $case_id,
    ref_key: $ref_key,
    entry_name: $entry_name,
    entry_path: $entry_path,
    payload_bytes: $payload_bytes,
    payload_sha256: $payload_sha256,
    verified_at: $verified_at,
    restored: true
  }' > "${output_dir}/${case_id}-${ref_key}-${entry_name}-restore.json"

jq . "${output_dir}/${case_id}-${ref_key}-${entry_name}-restore.json"
