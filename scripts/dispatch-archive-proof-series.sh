#!/usr/bin/env bash
set -euo pipefail

repo="boringcache/docker-cache-proofs"
workflow="Archive Cache Proof"
workflow_ref="main"
case_id=""
ref_key="main"
wait_for_runs="true"
dry_run="false"

usage() {
  cat <<'USAGE'
Usage: scripts/dispatch-archive-proof-series.sh --case CASE_ID [options]

Dispatch an archive/cache proof. It records current GitHub Actions cache
keys/sizes, then runs a small BoringCache archive restore/save smoke for the
case's representative cache classes. The smoke proves product wiring and
checksum restore behavior; it is not a scale or wall-clock proof.

Options:
  --case CASE_ID           Archive case manifest id, e.g. brightdigit-syntaxkit
  --repo OWNER/REPO        Target proof repo (default: boringcache/docker-cache-proofs)
  --workflow NAME_OR_FILE  Workflow name or file (default: Archive Cache Proof)
  --ref GIT_REF            Workflow ref to dispatch (default: main)
  --case-ref REF_KEY       Ref key from archive-cases/CASE_ID.json (default: main)
  --no-wait                Dispatch and return without waiting
  --dry-run                Print command without dispatching
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
    --case-ref)
      ref_key="$2"
      shift 2
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
case_file="${repo_root}/archive-cases/${case_id}.json"
if [[ ! -f "$case_file" ]]; then
  echo "Unknown archive case manifest: ${case_file}" >&2
  exit 1
fi

title_prefix="${case_id} | ${ref_key} | inventory"
started_at="$(date -u +%Y-%m-%dT%H:%M:%SZ)"
cmd=(
  gh workflow run "$workflow"
  --repo "$repo"
  --ref "$workflow_ref"
  -f "case_id=${case_id}"
  -f "ref_key=${ref_key}"
)

printf 'Dispatching:'
printf ' %q' "${cmd[@]}"
printf '\n'

if [[ "$dry_run" == "true" ]]; then
  exit 0
fi

"${cmd[@]}"

if [[ "$wait_for_runs" != "true" ]]; then
  exit 0
fi

for _ in $(seq 1 30); do
  runs_json="$(gh run list --repo "$repo" --workflow "$workflow" --event workflow_dispatch --limit 50 --json databaseId,displayTitle,createdAt,url)"
  run_id="$(
    jq -r --arg title "$title_prefix" --arg started "$started_at" '
      [.[] | select(.createdAt >= $started and (.displayTitle | startswith($title)))]
      | sort_by(.createdAt)
      | reverse
      | .[0].databaseId // empty
    ' <<< "$runs_json"
  )"
  if [[ -n "$run_id" ]]; then
    gh run watch "$run_id" --repo "$repo" --exit-status
    exit 0
  fi
  sleep 5
done

echo "Could not find dispatched run for ${title_prefix}" >&2
exit 1
