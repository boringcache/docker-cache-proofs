#!/usr/bin/env bash
set -euo pipefail

dockerfile="${1:-Dockerfile}"

if [[ ! -f "$dockerfile" ]]; then
  echo "Windmill Dockerfile does not exist: ${dockerfile}" >&2
  exit 2
fi

if [[ "$(grep -Fxc 'RUN cargo install sccache --version ^0.8' "$dockerfile")" -ne 1 ]]; then
  echo "Unsupported Windmill Dockerfile: expected the sccache 0.8 install exactly once." >&2
  exit 1
fi

# This is the literal Dockerfile command we replace, not a shell expansion.
# shellcheck disable=SC2016
compile_command='    CARGO_NET_GIT_FETCH_WITH_CLI=true cargo build --release --features "$features"'
if [[ "$(grep -Fxc "$compile_command" "$dockerfile")" -ne 1 ]]; then
  echo "Unsupported Windmill Dockerfile: expected the release workspace compile exactly once." >&2
  exit 1
fi

rendered_dockerfile="$(mktemp "$(dirname "$dockerfile")/windmill-sccache.Dockerfile.XXXXXX")"
trap 'rm -f "$rendered_dockerfile"' EXIT

awk '
  BEGIN {
    install_steps = 0
    removed_install_steps = 0
    compile_steps = 0
  }
  $0 == "RUN rustup component add rustfmt" {
    print "# Benchmark-only prerequisite for boringcache docker --tool-cache sccache."
    print "# Install it before the first Rust command because BoringCache injects"
    print "# RUSTC_WRAPPER into every RUN, including cargo install cargo-chef."
    print "ARG BORINGCACHE_SCCACHE_VERSION=0.16.0"
    print "ARG BORINGCACHE_SCCACHE_SHA256_AMD64=aec995a83ad3dff3d14b6314e08858b7b73d35ca85a5bcf3d3a9ec07dee35588"
    print "ARG BORINGCACHE_SCCACHE_SHA256_ARM64=f73a5c39f96bb6ebb89cc7915cf182260d4cbf30765322c5e793d0fe8bd80784"
    print "RUN <<SCCACHE_INSTALL"
    print "set -eux"
    print "case \"$(uname -m)\" in"
    print "  x86_64) sccache_target=x86_64-unknown-linux-musl; sccache_sha256=\"$BORINGCACHE_SCCACHE_SHA256_AMD64\" ;;"
    print "  aarch64) sccache_target=aarch64-unknown-linux-musl; sccache_sha256=\"$BORINGCACHE_SCCACHE_SHA256_ARM64\" ;;"
    print "  *) echo \"Unsupported architecture: $(uname -m)\" >&2; exit 1 ;;"
    print "esac"
    print "sccache_archive=\"sccache-v${BORINGCACHE_SCCACHE_VERSION}-${sccache_target}.tar.gz\""
    print "curl -fsSL \"https://github.com/mozilla/sccache/releases/download/v${BORINGCACHE_SCCACHE_VERSION}/${sccache_archive}\" -o \"/tmp/${sccache_archive}\""
    print "printf \"%s  %s\\n\" \"$sccache_sha256\" \"/tmp/${sccache_archive}\" | sha256sum -c -"
    print "tar -xzf \"/tmp/${sccache_archive}\" -C /tmp"
    print "install -m 0755 \"/tmp/sccache-v${BORINGCACHE_SCCACHE_VERSION}-${sccache_target}/sccache\" /usr/local/bin/sccache"
    print "rm -rf \"/tmp/${sccache_archive}\" \"/tmp/sccache-v${BORINGCACHE_SCCACHE_VERSION}-${sccache_target}\""
    print "sccache --version"
    print "SCCACHE_INSTALL"
    print $0
    install_steps += 1
    next
  }
  $0 == "RUN cargo install sccache --version ^0.8" {
    removed_install_steps += 1
    next
  }
  $0 == "    CARGO_NET_GIT_FETCH_WITH_CLI=true cargo build --release --features \"$features\"" {
    print "    sccache --zero-stats >/dev/null 2>&1 || true; CARGO_NET_GIT_FETCH_WITH_CLI=true cargo build --release --features \"$features\" && echo BEGIN_BORINGCACHE_SCCACHE_STATS && sccache --show-stats && echo END_BORINGCACHE_SCCACHE_STATS"
    compile_steps += 1
    next
  }
  { print }
  END {
    if (install_steps != 1 || removed_install_steps != 1 || compile_steps != 1) {
      printf "Unsupported Windmill Dockerfile: rendered %d installs, removed %d legacy installs, and rendered %d compile probes.\n", install_steps, removed_install_steps, compile_steps > "/dev/stderr"
      exit 1
    }
  }
' "$dockerfile" > "$rendered_dockerfile"

mv "$rendered_dockerfile" "$dockerfile"
