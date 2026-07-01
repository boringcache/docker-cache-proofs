#!/usr/bin/env bash
set -euo pipefail

case_id="${1:?case id is required}"
ref_key="${2:?case ref key is required}"
entry_name="${3:?archive sample entry name is required}"
entry_path="${4:?archive sample entry path is required}"
size_mib="${5:?archive sample size in MiB is required}"
output_dir="${6:-archive-results}"

if ! command -v jq >/dev/null 2>&1; then
  echo "jq is required" >&2
  exit 1
fi

if [[ ! "$entry_name" =~ ^[A-Za-z0-9._-]+$ ]]; then
  echo "Unsafe archive sample entry name: ${entry_name}" >&2
  exit 1
fi

case "$entry_path" in
  archive-samples/*) ;;
  *)
    echo "Archive sample path must live under archive-samples/: ${entry_path}" >&2
    exit 1
    ;;
esac

case "$entry_path" in
  *..* | /*)
    echo "Unsafe archive sample path: ${entry_path}" >&2
    exit 1
    ;;
esac

if [[ ! "$size_mib" =~ ^[0-9]+$ ]] || [[ "$size_mib" -le 0 ]] || [[ "$size_mib" -gt 1024 ]]; then
  echo "Archive sample size must be 1-1024 MiB: ${size_mib}" >&2
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

rm -rf "$entry_path"
mkdir -p "$entry_path" "$output_dir"

payload_path="${entry_path}/payload.bin"
manifest_path="${entry_path}/.boringcache-archive-sample.json"
started_at="$(date -u +%Y-%m-%dT%H:%M:%SZ)"

dd if=/dev/urandom of="$payload_path" bs=1048576 count="$size_mib" 2>/dev/null

payload_bytes="$(file_size "$payload_path")"
payload_sha256="$(sha256_file "$payload_path")"
generated_at="$(date -u +%Y-%m-%dT%H:%M:%SZ)"

jq -n \
  --arg schema_version "archive_sample_payload.v1" \
  --arg case_id "$case_id" \
  --arg ref_key "$ref_key" \
  --arg entry_name "$entry_name" \
  --arg entry_path "$entry_path" \
  --arg payload_path "payload.bin" \
  --arg payload_sha256 "$payload_sha256" \
  --arg started_at "$started_at" \
  --arg generated_at "$generated_at" \
  --argjson size_mib "$size_mib" \
  --argjson payload_bytes "$payload_bytes" \
  '{
    schema_version: $schema_version,
    case_id: $case_id,
    ref_key: $ref_key,
    entry_name: $entry_name,
    entry_path: $entry_path,
    payload_path: $payload_path,
    requested_size_mib: $size_mib,
    payload_bytes: $payload_bytes,
    payload_sha256: $payload_sha256,
    started_at: $started_at,
    generated_at: $generated_at
  }' > "$manifest_path"

cp "$manifest_path" "${output_dir}/${case_id}-${ref_key}-${entry_name}-seed.json"
jq . "$manifest_path"
