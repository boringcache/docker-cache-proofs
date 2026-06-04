#!/usr/bin/env bash
set -euo pipefail

repo="boringcache/docker-cache-proofs"
workflow="Tool Cache Proof"
workflow_ref="main"
case_id=""
fresh_ref="main"
rolling_bootstrap_ref="main"
run_fresh="true"
run_rolling="true"
include_rolling_bootstrap="true"
wait_for_runs="true"
dry_run="false"
rolling_refs=()

usage() {
  cat <<'USAGE'
Usage: scripts/dispatch-tool-proof-series.sh --case CASE_ID [options]

Dispatch a Painful Builds tool-cache lane in the public fresh + ordered rolling shape.
By default it runs:
  1. fresh on ref key "main"
  2. rolling on ref key "main" to bootstrap/update the rolling cache scope
  3. rolling1, rolling2, rolling3... from tool-cases/CASE_ID.json in numeric order

Options:
  --case CASE_ID                  Tool case manifest id, e.g. aranya-rust
  --repo OWNER/REPO               Target proof repo (default: boringcache/docker-cache-proofs)
  --workflow NAME_OR_FILE         Workflow name or file (default: Tool Cache Proof)
  --ref GIT_REF                   Workflow ref to dispatch (default: main)
  --fresh-ref REF_KEY             Ref key for fresh run (default: main)
  --rolling-bootstrap-ref REF_KEY Ref key for rolling bootstrap (default: main)
  --rolling-ref REF_KEY           Add one rolling ref key; repeatable
  --rolling-refs A,B,C            Add comma-separated rolling ref keys
  --skip-fresh                    Do not dispatch the fresh lane
  --skip-rolling                  Do not dispatch rolling lanes
  --skip-rolling-bootstrap        Do not dispatch rolling bootstrap/update on main
  --no-wait                       Dispatch and return without waiting
  --dry-run                       Print commands without dispatching
USAGE
}

require_tool() {
  if ! command -v "$1" >/dev/null 2>&1; then
    echo "$1 is required" >&2
    exit 1
  fi
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    --case)
      case_id="$2"
      shift 2
      ;;
    --repo)
      repo="$2"
      shift 2
      ;;
    --workflow)
      workflow="$2"
      shift 2
      ;;
    --ref)
      workflow_ref="$2"
      shift 2
      ;;
    --fresh-ref)
      fresh_ref="$2"
      shift 2
      ;;
    --rolling-bootstrap-ref)
      rolling_bootstrap_ref="$2"
      shift 2
      ;;
    --rolling-ref)
      rolling_refs+=("$2")
      shift 2
      ;;
    --rolling-refs)
      IFS=',' read -r -a parsed_refs <<< "$2"
      for ref_key in "${parsed_refs[@]}"; do
        [[ -n "$ref_key" ]] && rolling_refs+=("$ref_key")
      done
      shift 2
      ;;
    --skip-fresh)
      run_fresh="false"
      shift
      ;;
    --skip-rolling)
      run_rolling="false"
      shift
      ;;
    --skip-rolling-bootstrap)
      include_rolling_bootstrap="false"
      shift
      ;;
    --no-wait)
      wait_for_runs="false"
      shift
      ;;
    --dry-run)
      dry_run="true"
      shift
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

if [[ -z "$case_id" ]]; then
  echo "--case is required" >&2
  usage >&2
  exit 1
fi

require_tool gh
require_tool jq

repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
case_file="${repo_root}/tool-cases/${case_id}.json"

if [[ ! -f "$case_file" ]]; then
  echo "Unknown tool case manifest: ${case_file}" >&2
  exit 1
fi

if [[ "${#rolling_refs[@]}" -eq 0 ]]; then
  while IFS= read -r ref_key; do
    [[ -n "$ref_key" ]] && rolling_refs+=("$ref_key")
  done < <(
    jq -r '
      .refs
      | keys
      | map(select(test("^rolling[0-9]+$")))
      | sort_by(capture("^rolling(?<n>[0-9]+)$").n | tonumber)
      | .[]
    ' "$case_file"
  )
fi

wait_for_run() {
  local title_prefix="$1"
  local started_at="$2"
  local run_id=""
  local run_url=""

  for _ in $(seq 1 30); do
    runs_json="$(gh run list --repo "$repo" --workflow "$workflow" --event workflow_dispatch --limit 50 --json databaseId,displayTitle,createdAt,url,status,conclusion)"
    run_id="$(
      jq -r --arg title "$title_prefix" --arg started "$started_at" '
        [.[] | select(.createdAt >= $started and (.displayTitle | startswith($title)))]
        | sort_by(.createdAt)
        | reverse
        | .[0].databaseId // empty
      ' <<< "$runs_json"
    )"
    run_url="$(
      jq -r --arg title "$title_prefix" --arg started "$started_at" '
        [.[] | select(.createdAt >= $started and (.displayTitle | startswith($title)))]
        | sort_by(.createdAt)
        | reverse
        | .[0].url // empty
      ' <<< "$runs_json"
    )"
    if [[ -n "$run_id" ]]; then
      echo "$run_url"
      gh run watch "$run_id" --repo "$repo" --exit-status
      return 0
    fi
    sleep 5
  done

  echo "Could not find dispatched run for ${title_prefix}" >&2
  exit 1
}

dispatch_one() {
  local ref_key="$1"
  local lane="$2"
  local title_prefix="${case_id} | ${ref_key} | ${lane}"
  local started_at=""
  started_at="$(date -u +%Y-%m-%dT%H:%M:%SZ)"

  cmd=(
    gh workflow run "$workflow"
    --repo "$repo"
    --ref "$workflow_ref"
    -f "case_id=${case_id}"
    -f "ref_key=${ref_key}"
    -f "cache_lane=${lane}"
  )

  printf 'Dispatching:'
  printf ' %q' "${cmd[@]}"
  printf '\n'

  if [[ "$dry_run" == "true" ]]; then
    return 0
  fi

  "${cmd[@]}"
  if [[ "$wait_for_runs" == "true" ]]; then
    wait_for_run "$title_prefix" "$started_at"
  fi
}

if [[ "$run_fresh" == "true" ]]; then
  dispatch_one "$fresh_ref" "fresh"
fi

if [[ "$run_rolling" == "true" ]]; then
  if [[ "$include_rolling_bootstrap" == "true" ]]; then
    dispatch_one "$rolling_bootstrap_ref" "rolling"
  fi
  if [[ "${#rolling_refs[@]}" -gt 0 ]]; then
    for ref_key in "${rolling_refs[@]}"; do
      dispatch_one "$ref_key" "rolling"
    done
  fi
fi
