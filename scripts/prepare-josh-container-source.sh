#!/usr/bin/env bash
set -euo pipefail

source_path="${SOURCE_PATH:?SOURCE_PATH is required}"
source_dir="${source_path%/}"

if [[ ! -f "$source_dir/compose.josh" ]]; then
  echo "Missing Josh source checkout at $source_dir" >&2
  exit 1
fi

mkdir -p "$source_dir/images/boringcache-sccache-proxy"

cat > "$source_dir/images/boringcache-sccache-proxy.josh" <<'JOSH'
context = :/images/boringcache-sccache-proxy
JOSH

cat > "$source_dir/images/boringcache-sccache-proxy/Dockerfile" <<'DOCKERFILE'
FROM alpine:3.22
RUN apk add --no-cache socat
COPY entrypoint.sh /entrypoint.sh
RUN chmod +x /entrypoint.sh
ENTRYPOINT ["/entrypoint.sh"]
DOCKERFILE

cat > "$source_dir/images/boringcache-sccache-proxy/entrypoint.sh" <<'SH'
#!/bin/sh
set -eu

host="${BORINGCACHE_PROXY_HOST:-host.containers.internal}"
port="${BORINGCACHE_PROXY_PORT:-5000}"

exec socat \
  "TCP-LISTEN:3000,fork,reuseaddr" \
  "TCP:${host}:${port}"
SH

if [[ -f "$source_dir/ws/sccache-proxy.josh" ]]; then
  cat > "$source_dir/ws/sccache-proxy.josh" <<'JOSH'
:#image[:+images/boringcache-sccache-proxy]

env = :[
    :$BORINGCACHE_PROXY_HOST="host.containers.internal"
    :$BORINGCACHE_PROXY_PORT="5001"
]

env_passthrough = :[
]

inject = :[
    :$SCCACHE_WEBDAV_ENDPOINT="http://{SIDECAR_IP}:3000"
    :$SCCACHE_IDLE_TIMEOUT="0"
]
JOSH

  cat > "$source_dir/compose.josh" <<'JOSH'
:+ws/test
JOSH
else
  cat > "$source_dir/compose.josh" <<'JOSH'
:#sidecar_image[:+images/boringcache-sccache-proxy]

sidecar_env = :[
    :$BORINGCACHE_PROXY_HOST="host.containers.internal"
    :$BORINGCACHE_PROXY_PORT="5001"
]

sidecar_passthrough = :[
]

sidecar_inject = :[
    :$SCCACHE_WEBDAV_ENDPOINT="http://{SIDECAR_IP}:3000"
    :$SCCACHE_IDLE_TIMEOUT="0"
]

:+ws/test
JOSH
fi

cat > "$source_dir/run-cargo-test-with-stats.sh" <<'SH'
#!/bin/sh
set +e

cargo test --workspace --offline --locked
status="$?"
sccache --show-stats
exit "$status"
SH

test_ws="$source_dir/ws/test.josh"
if ! grep -q 'run-cargo-test-with-stats.sh' "$test_ws"; then
  perl -0pi -e 's#:\$cmd="cargo test --workspace --offline --locked"#:\$cmd="sh run-cargo-test-with-stats.sh"#' "$test_ws"
  perl -0pi -e 's#(::rust-toolchain\.toml\n)#${1}            ::run-cargo-test-with-stats.sh\n#' "$test_ws"
fi

if ! grep -q 'run-cargo-test-with-stats.sh' "$test_ws"; then
  echo "Failed to patch Josh test workspace with sccache stats command" >&2
  exit 1
fi
