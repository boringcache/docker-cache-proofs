# Native BuildKit Local Harness

Use this note when debugging native BuildKit publish, materialize, or save behavior from a local checkout.

## Two Paths

There are two native-looking Docker paths, and they answer different questions.

### Product path

`boringcache docker --backend native` and `boringcache docker --backend auto` are the user-facing product path. This path starts the publisher as a separate sidecar container.

The sidecar image is version matched:

```text
ghcr.io/boringcache/base:bookworm-v<CARGO_PKG_VERSION>
```

`BORINGCACHE_NATIVE_SIDECAR_IMAGE` can override it.

If the matching image has not been published, the sidecar cannot start. With `--backend auto`, the product path can fall back to the registry/non-native path. That is a packaging or rollout signal, not proof that the native BuildKit scheduler or exporter is broken.

Use this path when testing customer-facing native/auto UX, sidecar packaging, fallback behavior, and image release alignment.

### Benchmark harness path

`scripts/run-boringcache-native-buildkit-benchmark.sh` is the local and CI benchmark-native path. It runs a CLI container, starts BuildKit, and invokes:

```bash
boringcache buildkit --backend native --buildkit-cache-root /cache -- buildctl ...
```

The publisher runs in-process with the mounted `boringcache` binary. It does not pull `ghcr.io/boringcache/base:bookworm-v...`, so a missing sidecar image does not invalidate this path.

Use this path when investigating native benchmark behavior: online materialization, online publish scheduling, final export backlog, final save time, and OCI proxy publish behavior.

## Required Binary

The harness runs inside a Linux container, so the mounted `boringcache` must be a Linux binary. A macOS `target/debug/boringcache` will not run there.

On local arm64 Colima, build a Linux arm64 CLI from `/Users/gaurav/boringcache/web`:

```bash
cd /Users/gaurav/boringcache/web
set -a
source /Users/gaurav/boringcache/web/.env
set +a

bin/build-cli-linux \
  --platform linux/arm64 \
  --libc gnu \
  --profile release \
  --skip-image-build \
  --output /Users/gaurav/boringcache/.tmp/native-bin/boringcache
```

Verify it through Docker:

```bash
docker run --rm \
  -v /Users/gaurav/boringcache/.tmp/native-bin/boringcache:/usr/local/bin/boringcache:ro \
  buildpack-deps:noble-curl \
  /usr/local/bin/boringcache --version
```

For exact GitHub-hosted runner parity, use a Linux amd64 binary and `--platform=linux/amd64` in the build args. On local arm64 Colima, that runs under emulation and absolute times are not comparable. Prefer arm64 for scheduler diagnosis unless the exact amd64 layer graph is the point of the run.

## Colima Mount Rules

Keep bind-mounted files and temporary harness output under `/Users/gaurav/boringcache`, not `/private/tmp`.

Set:

```bash
BENCHMARK_HOST_TMPDIR=/Users/gaurav/boringcache/.tmp/<run-name>
PATH=/Users/gaurav/boringcache/.tmp/native-bin:$PATH
```

Using `/private/tmp` can make Colima see mounted files as missing directories. The usual symptom is a container error such as `Permission denied` when spawning `buildctl` or the mounted CLI.

## Tokens And Workspace

Source `/Users/gaurav/boringcache/web/.env`, but never print token values.

Use a disposable `CACHE_SCOPE` for local runs. Make sure `BENCHMARK_WORKSPACE` matches the token and API surface being tested.

The GitHub repository is `boringcache/docker-cache-proofs` plural, but the workflow currently uses the BoringCache workspace `boringcache/docker-cache-proof` singular. Keep local harness runs aligned with the workflow unless you are intentionally testing a different workspace and token.

If OCI proxy blob checks fail with a response like:

```text
Failed to check blob existence: Resource not found: .../caches/blobs/check
```

treat that first as a workspace, token, API, or environment mismatch. It is not materialization-scheduler evidence by itself.

## Minimal Local Shape

From `/Users/gaurav/boringcache/benchmarks-repos/docker-cache-proofs`:

```bash
./scripts/prepare-case-source.sh phentrieve-api main

set -a
source /Users/gaurav/boringcache/web/.env
set +a

env \
  PATH=/Users/gaurav/boringcache/.tmp/native-bin:$PATH \
  CACHE_LANE=rolling \
  BENCHMARK_WORKSPACE=boringcache/docker-cache-proof \
  CACHE_SCOPE=phentrieve-api-native-local-$(date +%y%m%d-%H%M) \
  BENCHMARK_ID=phentrieve-api-main-local-native \
  IMAGE_TAG=cache-proof/phentrieve-api:main-native-local \
  DOCKERFILE_PATH=.work/phentrieve-api/source/api/Dockerfile \
  BENCHMARK_DOCKER_CONTEXT=.work/phentrieve-api/source/. \
  DOCKER_BUILD_EXTRA_ARGS=$'--build-arg=BUNDLE_URL=https://github.com/berntpopp/phentrieve/releases/download/data-v2026-02-16/phentrieve-data-v2026-02-16-biolord-multivec.tar.gz\n--build-arg=BUILD_INDEXES=false\n--platform=linux/arm64' \
  BENCHMARK_BUILD_OUTPUT=none \
  BENCHMARK_HOST_TMPDIR=/Users/gaurav/boringcache/.tmp/phentrieve-native-local \
  BENCHMARK_METRICS_OUTPUT=/Users/gaurav/boringcache/.tmp/phentrieve-native-local/metrics.env \
  BENCHMARK_DIAGNOSTICS_OUTPUT=/Users/gaurav/boringcache/.tmp/phentrieve-native-local/diagnostics.txt \
  ./scripts/run-boringcache-native-buildkit-benchmark.sh rolling
```

Use the same `CACHE_SCOPE` for the follow-up commit if testing rolling behavior:

```bash
./scripts/prepare-case-source.sh phentrieve-api rolling1
```

Then rerun the harness with a new `BENCHMARK_ID`, `IMAGE_TAG`, metrics path, and diagnostics path.

## Evidence To Read

The important signal is whether online materialize and publish keep up before the final reconcile.

Look in the build log and diagnostics for:

```text
Native BuildKit publish policy: auto -> active
materialize_policy=... materialize_jobs=... publish_slots=...
materialize pass-N skipped; BuildKit metadata unchanged
materialize pass-N deferred; reason=ResourcePressure
buildkit-cache export-local: ... materialized_overlay_diffs=... compressed_bytes=...
online upload pass-N queued blobs=...
final export status=... seconds=...
final save status=... seconds=...
```

The native evidence JSON is also useful:

```bash
jq -c '{restore, publisher, command, publish}' /path/to/native-tool.json
```

Pay special attention to:

- `publisher.final_export_seconds`
- `publisher.final_save_seconds`
- `publisher.final_save_uploaded_blob_count`
- `publisher.final_save_already_present_blob_count`
- `publisher.final_save_missing_blob_bytes`

Interpretation:

- If final materialization reports high `materialize_jobs`, final export parallelism exists.
- If final export still has many diffs or many GiB left of missing bytes, online materialization did not get enough usable layer state or runway.
- If final save is long/large but final export is small, inspect the OCI proxy upload path and blob concurrency.
- Blob-level proxy concurrency does not prove multipart or intra-blob concurrency. A run dominated by one multi-GB blob can still be gated by one upload stream.

## Cleanup

Only stop containers that belong to the run you started. The harness names them with a `bc-native-<slug>` prefix.

```bash
docker ps --format '{{.ID}} {{.Names}} {{.Image}} {{.Status}}' | rg 'bc-native-|bc-phentrieve'
docker stop <matching-owned-container-ids>
```

If you created a temporary product-path buildx builder, remove only that named builder:

```bash
docker buildx rm --force <builder-name>
```

Leave unrelated benchmark or PostHog containers alone unless the user explicitly asks to stop them.
