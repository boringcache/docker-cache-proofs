#!/usr/bin/env bash
set -euo pipefail

export CARGO_TERM_COLOR="${CARGO_TERM_COLOR:-always}"
export JOSH_EXPERIMENTAL_FEATURES="${JOSH_EXPERIMENTAL_FEATURES:-1}"

if [[ ! -x target/release/josh ]]; then
  echo "Missing target/release/josh; run the Josh setup command before measuring" >&2
  exit 1
fi

proxy_port="${BORINGCACHE_PROXY_PORT:-5000}"
forward_port="${BORINGCACHE_HOST_FORWARD_PORT:-5001}"

socat "TCP-LISTEN:${forward_port},bind=0.0.0.0,fork,reuseaddr" "TCP:127.0.0.1:${proxy_port}" &
forward_pid="$!"
trap 'kill "$forward_pid" 2>/dev/null || true' EXIT
sleep 1
if ! kill -0 "$forward_pid" 2>/dev/null; then
  echo "Failed to start BoringCache host forwarder on port ${forward_port}" >&2
  wait "$forward_pid" || true
  exit 1
fi

target/release/josh compose run
