#!/usr/bin/env bash
set -euo pipefail

source_path="${SOURCE_PATH:?SOURCE_PATH is required}"
working_directory="${TOOL_WORKING_DIRECTORY:-.}"
measured_command="${TOOL_BUILD_COMMAND:?TOOL_BUILD_COMMAND is required}"
metrics_output="${BENCHMARK_METRICS_OUTPUT:-}"
stats_file="${BENCHMARK_SCCACHE_STATS_FILE:-}"
stats_source="${BENCHMARK_SCCACHE_STATS_SOURCE:-host}"
command_log="${BENCHMARK_COMMAND_LOG:-benchmark-native-tool/command.log}"
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

extract_sccache_stats_from_log() {
  local log_path="$1"
  awk '
    /^Compile requests[[:space:]]/ {
      capture = 1
      block = $0 "\n"
      next
    }
    capture {
      block = block $0 "\n"
      if ($0 ~ /^Version \(client\)/) {
        last = block
        capture = 0
      }
    }
    END {
      if (last != "") {
        printf "%s", last
      } else if (capture && block != "") {
        printf "%s", block
      }
    }
  ' "$log_path"
}

mkdir -p "${SCCACHE_DIR:-$HOME/.cache/sccache}"
sccache --zero-stats >/dev/null 2>&1 || true

started_at="$(date +%s)"
set +e
if [[ "$stats_source" == "command-output" ]]; then
  mkdir -p "$(dirname "$command_log")"
  (
    cd "$workdir"
    bash -euo pipefail -c "$measured_command"
  ) 2>&1 | tee "$command_log"
  status="${PIPESTATUS[0]}"
else
  (
    cd "$workdir"
    bash -euo pipefail -c "$measured_command"
  )
  status="$?"
fi
set -e
finished_at="$(date +%s)"

if [[ -n "$stats_file" ]]; then
  mkdir -p "$(dirname "$stats_file")"
  if [[ "$stats_source" == "command-output" ]]; then
    extract_sccache_stats_from_log "$command_log" > "$stats_file" || true
    if [[ ! -s "$stats_file" ]]; then
      echo "No sccache stats found in command output; falling back to host sccache stats" >&2
      sccache --show-stats | tee "$stats_file" || true
    fi
  else
    sccache --show-stats | tee "$stats_file" || true
  fi
else
  sccache --show-stats || true
fi

write_metric "build_seconds" "$((finished_at - started_at))"
write_metric "status" "$status"

exit "$status"
