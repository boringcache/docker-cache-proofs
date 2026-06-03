#!/usr/bin/env bash
set -euo pipefail

config="prospects/run-sources.json"
output=""
limit_override=""

usage() {
  cat <<'USAGE'
Usage: scripts/collect-run-data.sh [options]

Collect recent GitHub Actions run durations for configured prospect buckets.

Options:
  --config PATH       Source config JSON (default: prospects/run-sources.json)
  --output PATH       Write Markdown report to this path; stdout when omitted
  --limit N           Override per-source run limit
USAGE
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    --config)
      config="$2"
      shift 2
      ;;
    --output)
      output="$2"
      shift 2
      ;;
    --limit)
      limit_override="$2"
      shift 2
      ;;
    -h | --help)
      usage
      exit 0
      ;;
    *)
      echo "Unknown option: $1" >&2
      usage >&2
      exit 1
      ;;
  esac
done

if ! command -v gh >/dev/null 2>&1; then
  echo "gh is required" >&2
  exit 1
fi

if ! command -v jq >/dev/null 2>&1; then
  echo "jq is required" >&2
  exit 1
fi

repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
config_path="$config"
if [[ "$config_path" != /* ]]; then
  config_path="${repo_root}/${config_path}"
fi

if [[ ! -f "$config_path" ]]; then
  echo "Missing config: $config_path" >&2
  exit 1
fi

fmt_duration() {
  local raw="$1"
  if [[ -z "$raw" || "$raw" == "null" ]]; then
    printf ''
    return 0
  fi
  local seconds
  seconds="$(printf '%.0f' "$raw")"
  printf '%dm %02ds' "$((seconds / 60))" "$((seconds % 60))"
}

markdown_escape() {
  printf '%s' "$1" | sed 's/|/\\|/g'
}

generate_report() {
  local generated_at
  generated_at="$(date -u +%Y-%m-%dT%H:%M:%SZ)"

  echo "# Prospect Run Data"
  echo
  echo "Generated: ${generated_at}"
  echo
  echo "| Bucket | Source | Lead/team | Pain | Proof | Successes | Median | Range | Latest successful run |"
  echo "|---|---|---|---|---|---:|---:|---:|---|"

  jq -c '.sources[]' "$config_path" | while IFS= read -r source_json; do
    id="$(jq -r '.id' <<< "$source_json")"
    bucket="$(jq -r '.bucket' <<< "$source_json")"
    adapter="$(jq -r '.adapter' <<< "$source_json")"
    label="$(jq -r '.label' <<< "$source_json")"
    lead="$(jq -r '.lead // ""' <<< "$source_json")"
    repo="$(jq -r '.repo' <<< "$source_json")"
    workflow="$(jq -r '.workflow' <<< "$source_json")"
    pain_url="$(jq -r '.pain_url // .source_url // ""' <<< "$source_json")"
    proof_url="$(jq -r '.proof_url // .source_url // ""' <<< "$source_json")"
    configured_limit="$(jq -r '.limit // 10' <<< "$source_json")"
    limit="${limit_override:-$configured_limit}"

    runs_json="$(gh run list --repo "$repo" --workflow "$workflow" --status completed --limit "$limit" --json databaseId,displayTitle,headSha,headBranch,event,status,conclusion,createdAt,updatedAt,url 2>/dev/null || printf '[]')"

    summary_tsv="$(
      jq -r --arg id "$id" --arg label "$label" --arg adapter "$adapter" --arg bucket "$bucket" --arg lead "$lead" '
        def duration: ((.updatedAt | fromdateiso8601) - (.createdAt | fromdateiso8601));
        def median:
          sort as $a
          | length as $n
          | if $n == 0 then null
            elif ($n % 2) == 1 then $a[($n / 2 | floor)]
            else (($a[($n / 2 - 1)] + $a[($n / 2)]) / 2)
            end;
        [.[] | select(.conclusion == "success")] as $ok
        | ($ok | map(duration)) as $durations
        | ($ok[0] // {}) as $latest
        | [
            $bucket,
            ($adapter + ": " + $label),
            $lead,
            ($ok | length),
            (if ($durations | length) == 0 then "" else ($durations | median | floor | tostring) end),
            (if ($durations | length) == 0 then "" else (($durations | min | floor | tostring) + "-" + ($durations | max | floor | tostring)) end),
            ($latest.url // ""),
            ($latest.displayTitle // "")
          ]
        | @tsv
      ' <<< "$runs_json"
    )"

    IFS=$'\t' read -r out_bucket out_source out_lead success_count median_seconds range_seconds latest_url latest_title <<< "$summary_tsv"
    median_label="$(fmt_duration "$median_seconds")"
    if [[ -n "$range_seconds" ]]; then
      min_seconds="${range_seconds%-*}"
      max_seconds="${range_seconds#*-}"
      range_label="$(fmt_duration "$min_seconds")-$(fmt_duration "$max_seconds")"
    else
      range_label=""
    fi
    if [[ -n "$latest_url" ]]; then
      latest_link="[run](${latest_url})"
      latest_title="$(markdown_escape "$latest_title")"
      latest_cell="${latest_link} ${latest_title}"
    else
      latest_cell=""
    fi
    pain_cell=""
    if [[ -n "$pain_url" ]]; then
      pain_cell="[pain](${pain_url})"
    fi
    proof_cell=""
    if [[ -n "$proof_url" ]]; then
      proof_cell="[proof](${proof_url})"
    fi

    echo "| $(markdown_escape "$out_bucket") | $(markdown_escape "$out_source") | $(markdown_escape "$out_lead") | ${pain_cell} | ${proof_cell} | ${success_count} | ${median_label} | ${range_label} | ${latest_cell} |"
  done
}

if [[ -n "$output" ]]; then
  output_path="$output"
  if [[ "$output_path" != /* ]]; then
    output_path="${repo_root}/${output_path}"
  fi
  mkdir -p "$(dirname "$output_path")"
  generate_report > "$output_path"
  echo "$output_path"
else
  generate_report
fi
