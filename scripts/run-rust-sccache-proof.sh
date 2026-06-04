#!/usr/bin/env bash
set -euo pipefail

source_path="${SOURCE_PATH:?SOURCE_PATH is required}"
working_directory="${TOOL_WORKING_DIRECTORY:-.}"
measured_command="${TOOL_BUILD_COMMAND:?TOOL_BUILD_COMMAND is required}"
metrics_output="${BENCHMARK_METRICS_OUTPUT:-}"
stats_file="${BENCHMARK_SCCACHE_STATS_FILE:-}"
workdir="${source_path%/}/${working_directory#./}"

if [[ "$working_directory" == "." ]]; then
  workdir="${source_path%/}"
fi

if [[ ! -d "$workdir" ]]; then
  echo "Missing working directory: $workdir" >&2
  exit 1
fi

if [[ -n "$metrics_output" ]]; then
  : > "$metrics_output"
fi

write_metric() {
  if [[ -n "$metrics_output" ]]; then
    printf '%s=%s\n' "$1" "$2" >> "$metrics_output"
  fi
}

mkdir -p "${SCCACHE_DIR:-$HOME/.cache/sccache}"
sccache --zero-stats >/dev/null 2>&1 || true

started_at="$(date +%s)"
set +e
(
  cd "$workdir"
  bash -euo pipefail -c "$measured_command"
)
status="$?"
set -e
finished_at="$(date +%s)"

if [[ -n "$stats_file" ]]; then
  mkdir -p "$(dirname "$stats_file")"
  sccache --show-stats | tee "$stats_file" || true
else
  sccache --show-stats || true
fi

write_metric "build_seconds" "$((finished_at - started_at))"
write_metric "status" "$status"

exit "$status"
