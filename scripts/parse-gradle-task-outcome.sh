#!/usr/bin/env bash
set -euo pipefail

log_path="${1:-}"
phase="${2:-gradle}"

if [[ -z "$log_path" || ! -f "$log_path" ]]; then
  echo "::warning::Gradle log not found: ${log_path}"
  if [[ -n "${GITHUB_OUTPUT:-}" ]]; then
    {
      echo "summary="
      echo "actionable_tasks="
      echo "executed_tasks="
      echo "from_cache_tasks="
      echo "up_to_date_tasks="
      echo "warning=${phase}_log_missing"
    } >> "$GITHUB_OUTPUT"
  fi
  exit 0
fi

summary=""
actionable_tasks=""
executed_tasks=""
from_cache_tasks=""
up_to_date_tasks=""

while IFS= read -r line; do
  if [[ "$line" =~ ([0-9]+)[[:space:]]+actionable[[:space:]]+tasks?:[[:space:]]*(.*)$ ]]; then
    summary="${BASH_REMATCH[0]}"
    actionable_tasks="${BASH_REMATCH[1]}"
    tail="${BASH_REMATCH[2]}"
    executed_tasks="0"
    from_cache_tasks="0"
    up_to_date_tasks="0"

    if [[ "$tail" =~ ([0-9]+)[[:space:]]+executed ]]; then
      executed_tasks="${BASH_REMATCH[1]}"
    fi
    if [[ "$tail" =~ ([0-9]+)[[:space:]]+from[[:space:]]+cache ]]; then
      from_cache_tasks="${BASH_REMATCH[1]}"
    fi
    if [[ "$tail" =~ ([0-9]+)[[:space:]]+up-to-date ]]; then
      up_to_date_tasks="${BASH_REMATCH[1]}"
    fi
  fi
done < "$log_path"

if [[ -z "$summary" ]]; then
  echo "::warning::No Gradle actionable task summary found in ${log_path}"
fi

warning=""
warn_threshold="${GRADLE_EXECUTED_WARN_THRESHOLD:-}"
if [[ -n "$warn_threshold" && "$warn_threshold" =~ ^[0-9]+$ && -n "$executed_tasks" && "$executed_tasks" -ge "$warn_threshold" ]]; then
  warning="${phase}_executed_tasks_high"
  echo "::warning::Gradle ${phase} executed ${executed_tasks}/${actionable_tasks} actionable tasks; remote cache hit behavior needs review"
fi

fail_threshold="${GRADLE_EXECUTED_FAIL_THRESHOLD:-}"
if [[ -n "$fail_threshold" && "$fail_threshold" =~ ^[0-9]+$ && -n "$executed_tasks" && "$executed_tasks" -ge "$fail_threshold" ]]; then
  echo "Gradle ${phase} executed ${executed_tasks}/${actionable_tasks}, meeting fail threshold ${fail_threshold}" >&2
  exit 1
fi

output_file="${GITHUB_OUTPUT:-}"
if [[ -n "$output_file" ]]; then
  {
    echo "summary=${summary}"
    echo "actionable_tasks=${actionable_tasks}"
    echo "executed_tasks=${executed_tasks}"
    echo "from_cache_tasks=${from_cache_tasks}"
    echo "up_to_date_tasks=${up_to_date_tasks}"
    echo "warning=${warning}"
  } >> "$output_file"
else
  printf 'summary=%s\n' "$summary"
  printf 'actionable_tasks=%s\n' "$actionable_tasks"
  printf 'executed_tasks=%s\n' "$executed_tasks"
  printf 'from_cache_tasks=%s\n' "$from_cache_tasks"
  printf 'up_to_date_tasks=%s\n' "$up_to_date_tasks"
  printf 'warning=%s\n' "$warning"
fi
