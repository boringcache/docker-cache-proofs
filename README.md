# Painful Builds

Runnable proof workflows for public build-cache cases.

Each case pins real upstream commits, links the public pain signal, and emits the same benchmark JSON/Markdown artifact shape used by the BoringCache benchmark repos.

The GitHub repository is `boringcache/docker-cache-proofs`. The live BoringCache workspace used by both proof workflows is `boringcache/docker-cache-proof` singular.

## Lane Rules

Docker proof lanes should stay simple by default: build the upstream Dockerfile with BoringCache's Docker cache path and keep the case runnable. If the upstream pain is Docker plus real compile or task work inside `RUN` steps, add a separate static hybrid lane such as `*-sccache` that uses `docker.tool_cache`; do not make tool-cache a manual dispatch knob and do not fold speculative tooling into the base Docker lane.

The `Docker Cache Proof` workflow runs each case against GitHub Actions Cache, ECR registry cache in `us-east-1`, BoringCache OCI proxy cache, and the managed BoringCache BuildKit backend so every Docker case has the same cold/rolling comparison surface.

## Docker Cases

| Case | Public pain | Proof source |
|---|---|---|
| `phentrieve-api` | [API Docker build exceeded 30-minute GitHub Actions timeout](https://github.com/berntpopp/phentrieve/issues/94); workflow says registry cache is more reliable than `gha` for PyTorch-sized images. | [Official slow API job](https://github.com/berntpopp/phentrieve/actions/runs/26388675097/job/77672942721); BoringCache proof runs in this repo. |
| `wormhole-solana` | Workflow says GHA cache can hang on large Docker uploads. | [Official slow Solana job](https://github.com/wormhole-foundation/native-token-transfers/actions/runs/26104579611/job/76764717136); BoringCache proof runs in this repo. |
| `cardstack-realm-server` | Cardstack workflow/action notes say GHA cache transfer for large pnpm-fetch layers was slower than rerunning fetch, so they moved to ECR registry cache. | [Official deploy sample](https://github.com/cardstack/boxel/actions/runs/25861223646); BoringCache proof runs in this repo. |
| `dependabot-updater-core` | [Dependabot smoke issue](https://github.com/dependabot/dependabot-core/issues/14914): smoke matrix jobs independently rebuild deterministic updater images on separate runners; the issue calls out `go_modules` rebuilding the same ecosystem image up to 11 times per PR. | [Recent smoke run](https://github.com/dependabot/dependabot-core/actions/runs/27011845235); BoringCache proof runs the upstream updater core Dockerfile in this repo. |
| `iggy-rust-server` | Apache Iggy ships Rust server Docker images through a sophisticated Buildx stack with registry cache, inline cache, and scoped GHA caches; current CI changes also call out runner disk pressure and per-job cleanup cost. | [Official Docker publish sample](https://github.com/apache/iggy/actions/runs/24415263274) plus current master CI churn; BoringCache proof runs the upstream server Dockerfile in this repo. |
| `kvrocks-docker` | [Kvrocks CI optimization issue](https://github.com/apache/kvrocks/issues/2642): active discussion says native build/compile time is a large CI cost; the official workflow also builds and tests Docker images. | [Official CI sample](https://github.com/apache/kvrocks/actions/runs/26924643510); BoringCache proof runs in this repo. |
| `kvrocks-docker-sccache` | Same Kvrocks pain, using a proof Dockerfile overlay that keeps the upstream image shape while opting the build stage into BoringCache-backed `sccache`. | [Official CI sample](https://github.com/apache/kvrocks/actions/runs/26924643510); BoringCache proof runs in this repo. |
| `nmisp-nightly` | [nmisp nightly test image issue](https://github.com/kangwonlee/nmisp/issues/370): the nightly conda/ML image build was profiled at ~24m versus ~7m for the 2023.09 variant. | [Official slow nightly image job](https://github.com/kangwonlee/nmisp/actions/runs/24956177996/job/73074709808); BoringCache proof runs in this repo. |

## Tool Cache Cases

Use the `Tool Cache Proof` workflow for prospect-shaped adapter runs that are not Docker image builds.

| Case | Adapter | Public pain | Readiness |
|---|---|---|---|
| `aranya-rust` | Rust/sccache | [Aranya CI compile-time issue](https://github.com/aranya-project/aranya/issues/135): open issue, GHA cache called not ideal, S3-backed sccache considered. | Pitch-ready first Rust proof. |
| `besu-gradle` | Gradle remote cache | [Besu Gradle cache issue](https://github.com/besu-eth/besu/issues/10427): current request to enable Gradle caching across workflows; pre-review compile disables the Gradle action cache while running the real Gradle build. | Current product Gradle proof; compare task outcomes before claiming. |
| `josh-rust-container` | Rust/sccache inside Podman containers | [Josh sidecar PR](https://github.com/josh-project/josh/pull/2025): build containers have no internet, so sccache needed an R2-signing sidecar. | Strategic sidecar proof; run singly before any ordered series. |
| `kvrocks-cpp-sccache` | C++/sccache plus Go integration tail | [Kvrocks CI optimization issue](https://github.com/apache/kvrocks/issues/2642): started from slow Go tests, then active comments called out C++ build and third-party dependency compile cost. | Multi-tool candidate; compiler-cache proof first, Docker proof adjacent. |
| `therock-prim-sccache` | C++/CMake sccache | [TheRock ccache miss issue](https://github.com/ROCm/TheRock/issues/5009): current ROCm build pain around restaged headers causing downstream compiler-cache misses; TheRock also tracks HIP/sccache integration. | High-value compiler-cache proof; not a generic Docker lane. |
| `tiny-congress-rust` | Rust/sccache | [Tiny Congress PR](https://github.com/icook/tiny-congress/pull/683): ARC runners plus Garage S3-backed sccache. | Reference proof; they already built a workaround. |

## Archive Cache Cases

Use the `Archive Cache Proof` workflow for suite/cache-retention prospects whose
pain is GitHub's 10 GB cache pressure, low-value saves, or large tool/runtime
blobs rather than a Docker image build. The workflow first inventories current
GitHub Actions cache keys and sizes, then runs a small BoringCache archive
restore/save smoke with representative cache classes. The smoke proves archive
product wiring and checksum restore behavior; it is not a scale, ccache, or
wall-clock proof.

| Case | Public pain | Proof source | Readiness |
|---|---|---|---|
| `brightdigit-syntaxkit` | [brightdigit/swift-build#114](https://github.com/brightdigit/swift-build/issues/114): Swift/Android matrix caches exceed GitHub's 10 GiB repo cache limit even after cleanup workflows. | [SyntaxKit PR #106](https://github.com/brightdigit/SyntaxKit/pull/106); inventory tracks SPM, Android emulator, Swift toolchain, and Xcode cache classes. | Inventory + archive smoke only; full promotion needs BC restore/save timings at realistic sizes and matrix stability. |
| `cupy-pretest-cache` | [cupy/cupy#10059](https://github.com/cupy/cupy/issues/10059): pretest and CUDA toolkit caches have low hit value and consume the 10 GB repo cache limit. | [CuPy PR #10049](https://github.com/cupy/cupy/pull/10049); inventory tracks `mini-ctk-*`, `build-cuda-*`, and `static-checks` cache classes. | Inventory + archive smoke only; full promotion needs CUDA/pretest restore/save timing and ccache hit/miss evidence. |

## Manual Runs

Use the Docker lane in the `Docker Cache Proof` workflow with:

- `cache_lane=fresh` for one cold build on the pinned commit;
- `cache_lane=rolling` for one continuous-commit build on a stable case cache scope;
- `build_output=none`, `load`, or `local-registry` depending on the UX surface being measured;
- `case_id=kvrocks-docker-sccache` for the Docker + container-side `sccache` proof lane.
- `case_id=dependabot-updater-core` for the Dependabot smoke-image proof lane.
- `case_id=iggy-rust-server` for Apache Iggy's Rust server Docker image lane.

Fresh lanes may export cache for storage accounting, but they do not run a second build. Rolling lanes own prior-cache import/update evidence.

The ECR lane assumes the `BENCHMARK_ECR_ROLE_ARN` GitHub organization variable through GitHub Actions OIDC and writes BuildKit registry cache manifests to `BENCHMARK_ECR_REGISTRY/BENCHMARK_ECR_REPOSITORY`. No long-lived AWS access keys are required in GitHub.

Use the tool-cache lane in the `Tool Cache Proof` workflow with:

- `cache_lane=fresh` for one pinned source build with a per-run cache tag;
- `cache_lane=rolling` for one commit build against a stable rolling cache tag;
- `case_id=aranya-rust`, `besu-gradle`, `josh-rust-container`, `kvrocks-cpp-sccache`, `therock-prim-sccache`, or `tiny-congress-rust`.

For ordered fresh + rolling runs:

```bash
scripts/dispatch-proof-series.sh --case phentrieve-api --build-output none
scripts/dispatch-tool-proof-series.sh --case aranya-rust
```

For canary Docker proof sweeps, run the `Canary Docker Proof Dispatch`
workflow. By default it dispatches the cases in `.canary/candidates.txt` with
the moving CLI release tag `vcli-canary` and BuildKit image
`ghcr.io/boringcache/buildkit:canary`; override `cli_version` or
`prewarm_buildkit_image` only when isolating a specific experiment.

For archive inventory plus BoringCache archive smoke:

```bash
scripts/dispatch-archive-proof-series.sh --case brightdigit-syntaxkit
scripts/dispatch-archive-proof-series.sh --case cupy-pretest-cache
```
