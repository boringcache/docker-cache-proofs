# Painful Builds

Runnable proof workflows for public build-cache cases.

Each case pins real upstream commits, links the public pain signal, and emits the same benchmark JSON/Markdown artifact shape used by the BoringCache benchmark repos.

The GitHub repository is `boringcache/docker-cache-proofs`. The live BoringCache workspace used by both proof workflows is `boringcache/docker-cache-proof` singular.

## Lane Rules

Docker proof lanes should stay simple by default: build the upstream Dockerfile with BoringCache's Docker cache path and keep the case runnable. If the upstream pain is Docker plus real compile or task work inside `RUN` steps, add a separate static hybrid lane such as `*-sccache` that uses `docker.tool_cache`; do not make tool-cache a manual dispatch knob and do not fold speculative tooling into the base Docker lane.

The `Docker Cache Proof` workflow runs each case against GitHub Actions Cache, ECR registry cache in `us-east-1`, BoringCache OCI proxy cache, and the managed BoringCache BuildKit backend so every Docker case has the same cold/rolling comparison surface.

## Docker Cases

`Reported pain` means the project has explicitly documented the Docker/cache problem. `Observed tax` is still a promising outreach signal when a current public job spends at least 200 seconds preparing or exporting cache, even without a matching issue. Keep sub-200-second observed cases as product proofs or watchlist entries unless another pain signal makes them relevant.

| Case | Signal | Public pain | Proof source |
|---|---|---|---|
| `phentrieve-api` | Reported pain | [API Docker build exceeded 30-minute GitHub Actions timeout](https://github.com/berntpopp/phentrieve/issues/94); workflow says registry cache is more reliable than `gha` for PyTorch-sized images. | [Official slow API job](https://github.com/berntpopp/phentrieve/actions/runs/26388675097/job/77672942721); BoringCache proof runs in this repo. |
| `wormhole-solana` | Reported in workflow | Workflow says GHA cache can hang on large Docker uploads. | [Official slow Solana job](https://github.com/wormhole-foundation/native-token-transfers/actions/runs/26104579611/job/76764717136); BoringCache proof runs in this repo. |
| `cardstack-realm-server` | Reported in workflow | Cardstack workflow/action notes say GHA cache transfer for large pnpm-fetch layers was slower than rerunning fetch, so they moved to ECR registry cache. | [Official deploy sample](https://github.com/cardstack/boxel/actions/runs/25861223646); BoringCache proof runs in this repo. |
| `dependabot-updater-core` | Reported pain | [Dependabot smoke issue](https://github.com/dependabot/dependabot-core/issues/14914): smoke matrix jobs independently rebuild deterministic updater images on separate runners; the issue calls out `go_modules` rebuilding the same ecosystem image up to 11 times per PR. | [Recent smoke run](https://github.com/dependabot/dependabot-core/actions/runs/27011845235); BoringCache proof runs the upstream updater core Dockerfile in this repo. |
| `iggy-rust-server` | Observed workflow cost | Apache Iggy ships Rust server Docker images through a sophisticated Buildx stack with registry cache, inline cache, and scoped GHA caches; current CI changes also call out runner disk pressure and per-job cleanup cost. | [Official Docker publish sample](https://github.com/apache/iggy/actions/runs/24415263274) plus current master CI churn; BoringCache proof runs the upstream server Dockerfile in this repo. |
| `kvrocks-docker` | Reported pain | [Kvrocks CI optimization issue](https://github.com/apache/kvrocks/issues/2642): active discussion says native build/compile time is a large CI cost; the official workflow also builds and tests Docker images. | [Official CI sample](https://github.com/apache/kvrocks/actions/runs/26924643510); BoringCache proof runs in this repo. |
| `kvrocks-docker-sccache` | Reported pain | Same Kvrocks pain, using a proof Dockerfile overlay that keeps the upstream image shape while opting the build stage into BoringCache-backed `sccache`. | [Official CI sample](https://github.com/apache/kvrocks/actions/runs/26924643510); BoringCache proof runs in this repo. |
| `nmisp-nightly` | Reported pain | [nmisp nightly test image issue](https://github.com/kangwonlee/nmisp/issues/370): the nightly conda/ML image build was profiled at ~24m versus ~7m for the 2023.09 variant. | [Official slow nightly image job](https://github.com/kangwonlee/nmisp/actions/runs/24956177996/job/73074709808); BoringCache proof runs in this repo. |
| `mozilla-bedrock-release` | Reported pain | [Bedrock cache investigation](https://github.com/mozilla/bedrock/issues/16941): restoring GHA cache took about three minutes and saving it took another three to five minutes. | The proof builds the upstream `release` target. Bedrock's separate five-image Compose publication tax is intentionally reported outside the cache-backend comparison. |
| `mozilla-fxa-mono` | Reported pain | [Firefox Accounts removed GHA Docker caching](https://github.com/mozilla/fxa/pull/19848) after repeated runner disk exhaustion. | The proof uses the upstream monorepo Dockerfile and its pinned public localization input; no Dockerfile overlay is applied. |
| `pythonitalia-pycon-pretix` | Reported pain | [Python Italia is evaluating S3-backed Docker caching](https://github.com/pythonitalia/pycon/issues/4536); Pretix still uses `type=gha,mode=max`. | The proof runs the upstream Pretix Dockerfile on a native GitHub-hosted ARM64 runner. |
| `chatwoot-docker` | Observed tax | Consecutive PR runs spent 203–297 seconds exporting the AMD64 GHA cache; native ARM64 exports took 245–252 seconds. | [Public two-platform Docker run](https://github.com/chatwoot/chatwoot/actions/runs/29762401159); the proof runs the upstream production Dockerfile on native AMD64. This case is sidelined because cold native gRPC compilation dominates and BoringCache did not win the rolling registry comparison. |
| `ghostfolio-docker` | Observed tax | Consecutive PRs spent 228 and 283 seconds exporting GHA cache from the three-platform image build. | [Public multi-platform Docker run](https://github.com/ghostfolio/ghostfolio/actions/runs/29765006006); the proof preserves the upstream AMD64, ARMv7, and ARM64 QEMU build. |
| `open-webui-ollama` | Observed tax | The AMD64 Ollama image spent 123 seconds exporting registry cache; adjacent CUDA variants also exceeded 100 seconds. | [Public ten-job Docker matrix](https://github.com/open-webui/open-webui/actions/runs/29719425583); the proof runs the upstream Ollama build arguments on AMD64. Keep as a product proof, but below the 200-second no-complaint outreach threshold. |
| `auto-mobile-docker` | Reported pain | [The project measured a 692-second GHA cache export](https://github.com/kaeawc/auto-mobile/issues/640), then disabled cache export to recover the publish time. | [Official slow publish job](https://github.com/kaeawc/auto-mobile/actions/runs/20904260051/job/60055768837); the proof uses the exact pre-mitigation source commit. |
| `supabase-studio` | Observed tax | The current weekly AMD64 Studio image spent 332.6 seconds sending its `type=gha,mode=max` cache export. | [Official 4-vCPU Studio job](https://github.com/supabase/supabase/actions/runs/29718726330/job/88276984110); the proof preserves the upstream production target on AMD64. |
| `prefect-conda` | Observed tax | The Python 3.12 conda image spent 345.3 seconds exporting its GHA cache: 73.1 seconds preparing and 272.2 seconds transferring. | [Official two-platform conda job](https://github.com/PrefectHQ/prefect/actions/runs/29637767387/job/88062987619); the proof preserves the upstream AMD64/ARM64 QEMU build and conda flavor. |
| `teable-community` | Observed tax | The current native AMD64 community app spent 475.2 seconds exporting its GHA cache: 199.5 seconds preparing and 275.7 seconds transferring. | [Official native AMD64 app job](https://github.com/teableio/teable/actions/runs/29639339391/job/88067090491); the proof preserves the upstream community Dockerfile and changing build-version input. |
| `formbricks-web` | Observed tax | Four current PR/merge-queue runs spent 218.8–353.3 seconds exporting the GHA cache; the measured job runs throughout the day. | [Official merge-queue job](https://github.com/formbricks/formbricks/actions/runs/29744679758/job/88359620840); the proof uses the upstream web Dockerfile and its fork-safe build-time fallbacks. |
| `umami-release` | Reported in commit | A release failed after 230.5 seconds of GHA cache work with `error writing layer blob: not_found`; the follow-up [“Fix Docker release cache export” commit](https://github.com/umami-software/umami/commit/6061bcf14b24bb1dca52c065e6033a7a6c4f8a9b) made both exports best-effort. Its successful rerun still spent 388.1 seconds on the first cache export. | [Failed release job](https://github.com/umami-software/umami/actions/runs/28136102295/job/83323168828); the proof preserves the upstream AMD64/ARM64 QEMU build. |
| `hoppscotch-backend` | Observed tax | The release's backend cache export took 227.8 seconds on AMD64 and 246.3 seconds on ARM64 before three additional image/cache exports per architecture. | [Official AMD64 release job](https://github.com/hoppscotch/hoppscotch/actions/runs/29410411043/job/87335877154); the proof isolates the upstream backend target on native AMD64. |
| `typebot-builder` | Observed tax | The current release spent 477.2 seconds exporting the AMD64 builder cache; its other app/architecture jobs independently spent 294.7–486.1 seconds exporting cache. | [Official AMD64 builder job](https://github.com/baptisteArno/typebot.io/actions/runs/27695467686/job/81917369215); the proof preserves the upstream builder scope on native AMD64. |
| `stirling-pdf-embedded` | Observed tax | A current main-branch publication spent 863.8 seconds exporting the GHA cache: 183.8 seconds preparing and 680.0 seconds transferring. | [Official multi-platform publication job](https://github.com/Stirling-Tools/Stirling-PDF/actions/runs/29758033815/job/88405425988); the proof isolates the upstream embedded Dockerfile on native AMD64 so cache behavior is not obscured by QEMU. |
| `heyform-community` | Observed tax | The current two-platform community release spent 223.3 seconds exporting its GHA cache. | [Official release job](https://github.com/HeyForm/heyform/actions/runs/29302628301/job/86989382002); the proof preserves the upstream Dockerfile on native AMD64. |
| `grist-oss` | Observed tax | The daily two-image workflow currently spends 350–381 seconds exporting GHA cache per job. | [Official daily OSS job](https://github.com/gristlabs/grist-core/actions/runs/29722168278/job/88287251647); the proof isolates the upstream open-source Dockerfile on native AMD64, outside the workflow's test and QEMU overhead. |

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
scripts/dispatch-proof-series.sh --case mozilla-bedrock-release --fresh-ref seed --rolling-bootstrap-ref seed --lane-filter gha-buildkit --warm-replay
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
