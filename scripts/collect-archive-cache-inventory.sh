#!/usr/bin/env bash
set -euo pipefail

case_id="${1:?case id is required}"
ref_key="${2:?case ref key is required}"
output_dir="${3:-archive-results}"
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

if ! command -v gh >/dev/null 2>&1; then
  echo "gh is required" >&2
  exit 1
fi

project_repo="$(jq -er '.source.repo' "$case_file")"
project_ref="$(jq -r --arg key "$ref_key" '.refs[$key] // ""' "$case_file")"
expected_total_bytes="$(jq -r '.inventory.expected_total_bytes // 0' "$case_file")"

mkdir -p "$output_dir"
raw_path="${output_dir}/${case_id}-${ref_key}-gha-caches.json"
summary_path="${output_dir}/${case_id}-${ref_key}-archive-inventory.json"

gh_args=(
  cache list
  --repo "$project_repo"
  --limit 1000
  --json id,key,ref,sizeInBytes,createdAt,lastAccessedAt,version
)
if [[ -n "$project_ref" ]]; then
  gh_args+=(--ref "$project_ref")
fi

if ! gh "${gh_args[@]}" > "$raw_path"; then
  cat >&2 <<ERROR
Could not read GitHub Actions cache inventory for ${project_repo} ${project_ref}.
For external repositories, provide a token with Actions read access via GH_TOKEN
or BENCHMARK_GITHUB_TOKEN.
ERROR
  exit 1
fi

jq -n \
  --arg case_id "$case_id" \
  --arg ref_key "$ref_key" \
  --arg project_repo "$project_repo" \
  --arg project_ref "$project_ref" \
  --arg generated_at "$(date -u +%Y-%m-%dT%H:%M:%SZ)" \
  --argjson expected_total_bytes "$expected_total_bytes" \
  --slurpfile caches "$raw_path" \
  --slurpfile case "$case_file" '
    def cache_rows: ($caches[0] // []);
    def categories: ($case[0].inventory.categories // []);
    def category_rows($category):
      [cache_rows[] | select(.key | test($category.key_regex))];
    def category_summary($category):
      (category_rows($category)) as $rows
      | {
          name: $category.name,
          label: $category.label,
          key_regex: $category.key_regex,
          count: ($rows | length),
          size_in_bytes: (($rows | map(.sizeInBytes // 0) | add) // 0),
          keys: ($rows | map({key, ref, sizeInBytes, createdAt, lastAccessedAt}))
        };
    (categories | map(category_summary(.))) as $category_summaries
    | {
        schema_version: "archive_cache_inventory.v1",
        generated_at: $generated_at,
        case_id: $case_id,
        ref_key: $ref_key,
        project_repo: $project_repo,
        project_ref: $project_ref,
        expected_total_bytes: $expected_total_bytes,
        total_count: (cache_rows | length),
        total_size_in_bytes: ((cache_rows | map(.sizeInBytes // 0) | add) // 0),
        categorized_size_in_bytes: (($category_summaries | map(.size_in_bytes) | add) // 0),
        categories: $category_summaries,
        uncategorized: (
          [cache_rows[] as $cache
            | select(
                categories
                | map(.key_regex as $regex | ($cache.key | test($regex)))
                | any
                | not
              )
            | {key: $cache.key, ref: $cache.ref, sizeInBytes: $cache.sizeInBytes, createdAt: $cache.createdAt, lastAccessedAt: $cache.lastAccessedAt}
          ]
        )
      }
  ' > "$summary_path"

if [[ "${ARCHIVE_INVENTORY_QUIET:-0}" != "1" ]]; then
  cat "$summary_path"
fi
