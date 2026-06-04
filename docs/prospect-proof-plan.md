# Painful Builds Proof Plan

This repo is now framed as `painful-builds` / `Painful Builds`: Docker-first today, adapter-wide over time. Use the existing Docker lane for BuildKit/image-cache prospects, then add sccache, Turbo/Nx, Gradle, Maven, Go, and Bazel lanes when the proof harness exists.

Public pain signals below are market context, not customer proof or endorsements.

Cross-session handoff: [`docs/session-handoff.md`](session-handoff.md) has the latest Phentrieve run links, rolling materialization diagnosis, artifact metrics, and next proof actions.

## Docker Proof Queue

| Rank | Case | Lead/team | Pain link | Proof link | Current proof action |
|---:|---|---|---|---|---|
| 1 | `phentrieve-api` | `berntpopp` / Phentrieve | [`phentrieve#94`](https://github.com/berntpopp/phentrieve/issues/94), plus [workflow cache comment](https://github.com/berntpopp/phentrieve/blob/main/.github/workflows/docker-publish.yml#L113-L117). | [Official slow API job](https://github.com/berntpopp/phentrieve/actions/runs/26388675097/job/77672942721), [BoringCache fresh run](https://github.com/boringcache/docker-cache-proofs/actions/runs/26833413643), [rolling1 run](https://github.com/boringcache/docker-cache-proofs/actions/runs/26842722855), [rolling2 run](https://github.com/boringcache/docker-cache-proofs/actions/runs/26843436399), [rolling3 run](https://github.com/boringcache/docker-cache-proofs/actions/runs/26843568848). | Fresh + rolling1/2/3 complete; publish the proof table from artifacts. |
| 2 | `cardstack-realm-server` | Cardstack team | [Workflow/action notes](https://github.com/cardstack/boxel/blob/main/.github/workflows/manual-deploy.yml) around GHA cache transfer versus ECR registry cache. | [Official deploy sample](https://github.com/cardstack/boxel/actions/runs/25861223646), [BoringCache fresh run](https://github.com/boringcache/docker-cache-proofs/actions/runs/26833413589). | Run fresh + ordered rolling with `output=none`; add `local-registry` only when comparing image-output UX. |
| 3 | `wormhole-solana` | Wormhole NTT team | [Tilt Images workflow](https://github.com/wormhole-foundation/native-token-transfers/blob/main/.github/workflows/tilt-images.yml) says GHA cache can hang on large Docker uploads. | [Official slow Solana job](https://github.com/wormhole-foundation/native-token-transfers/actions/runs/26104579611/job/76764717136), [BoringCache fresh run](https://github.com/boringcache/docker-cache-proofs/actions/runs/26833413570). | Run fresh + ordered rolling, but expect long/heavy jobs. |

## Phentrieve Setup Notes

Official workflow: [`Build and Push Docker Images to GHCR`](https://github.com/berntpopp/phentrieve/blob/main/.github/workflows/docker-publish.yml).

Pain source:
- [`phentrieve#94`](https://github.com/berntpopp/phentrieve/issues/94) says the API Docker image build timed out at 30 minutes in GitHub Actions, with heavy ML dependencies taking 20-30+ minutes and `type=gha` reliability/export-timeout issues for large images.
- [`docker-publish.yml` lines 113-117](https://github.com/berntpopp/phentrieve/blob/main/.github/workflows/docker-publish.yml#L113-L117) says registry cache is more reliable than `gha` for large ML images.

API image:
- `docker/build-push-action@v7`
- context `.`
- Dockerfile `api/Dockerfile`
- registry cache from `ghcr.io/berntpopp/phentrieve/api:buildcache`
- registry cache to same ref with `mode=max` on non-PR runs
- `linux/amd64`
- build args include the HPO/BioLORD data bundle and `BUILD_INDEXES=false`
- upstream comment says registry cache is more reliable than GHA cache for large ML images

Representative official runs:
- Hotter sample: [`26311969942`](https://github.com/berntpopp/phentrieve/actions/runs/26311969942/job/77462686222), API job 8m55s, API build/push 2m32s.
- Heavier sample: [`26388675097`](https://github.com/berntpopp/phentrieve/actions/runs/26388675097/job/77672942721), API job 19m21s, API build/push 12m08s.

Current BoringCache proof readout:
Note: these proof runs predate the single-phase lane split; current `fresh` runs record one cold build only, and same-source rebuild evidence belongs outside the fresh lane.

- Fresh `main` run [`26833413643`](https://github.com/boringcache/docker-cache-proofs/actions/runs/26833413643): Auto cold 409s with a historical same-source rebuild at 4s; OCI cold 689s with a historical same-source rebuild at 3s. The fresh workflow wall time is slow because it includes intentional cold cache population, not because the same-source rebuild path is slow.
- Rolling1 run [`26842722855`](https://github.com/boringcache/docker-cache-proofs/actions/runs/26842722855): Auto commit build 368s with 100% read hit rate, 0.3s cache restore, 184s cache save/export, and about 7.0GB of new OCI blobs. OCI commit build 537s with 67.3% hit rate, 0.1s cache restore, 380.2s cache save/export, and about 6.5GB of new OCI blobs. This is the current continuous-commit pain: large cache update/export after a cache import, not hot same-source rebuild time.
- Rolling2 run [`26843436399`](https://github.com/boringcache/docker-cache-proofs/actions/runs/26843436399): Auto commit build 8s with 100% read hit rate and 0 new OCI blobs. OCI commit build 7s with 97.6% hit rate, 0.1s cache restore, 1.0s cache save/export, and one 16KB new OCI blob. This is the small-delta rolling case we needed beside the heavier rolling1 run.
- Rolling3 run [`26843568848`](https://github.com/boringcache/docker-cache-proofs/actions/runs/26843568848): Auto commit build 9s with 100% read hit rate and 0 new OCI blobs. OCI commit build 8s with 97.6% hit rate, 0.1s cache restore, 1.1s cache save/export, and one 16KB new OCI blob.

Phentrieve proof table:

| Proof | Link | Auto result | OCI result | Readiness read |
|---|---|---:|---:|---|
| Official heavy API run | [`26388675097`](https://github.com/berntpopp/phentrieve/actions/runs/26388675097/job/77672942721) | n/a | Build/push step 12m08s | Strong public pain: API Docker build hit 30-minute timeout before registry-cache fix. |
| Historical fresh `main` | [`26833413643`](https://github.com/boringcache/docker-cache-proofs/actions/runs/26833413643) | 409s cold, 4s historical rebuild | 689s cold, 3s historical rebuild | Pre-split run; current fresh lane records the cold build only. |
| Rolling1 | [`26842722855`](https://github.com/boringcache/docker-cache-proofs/actions/runs/26842722855) | 368s commit build | 537s commit build | Heavy rolling delta; product story is cache-update/export tax. |
| Rolling2 | [`26843436399`](https://github.com/boringcache/docker-cache-proofs/actions/runs/26843436399) | 8s commit build | 7s commit build | Small rolling delta; shows expected cache-hit behavior. |
| Rolling3 | [`26843568848`](https://github.com/boringcache/docker-cache-proofs/actions/runs/26843568848) | 9s commit build | 8s commit build | Small rolling delta; confirms rolling2 was not a one-off. |

## Dispatch Shape

Use the dispatcher for a complete ordered proof series:

```bash
scripts/dispatch-proof-series.sh --case phentrieve-api --build-output none
```

For a single rolling commit after the rolling scope has already been bootstrapped:

```bash
gh workflow run "Docker Cache Proof" \
  --repo boringcache/docker-cache-proofs \
  --ref main \
  -f case_id=phentrieve-api \
  -f ref_key=rolling1 \
  -f cache_lane=rolling \
  -f build_output=none
```

Rolling runs must be ordered. Dispatching `rolling1`, `rolling2`, and `rolling3` concurrently turns the result into cache contention, not continuous-commit evidence.

## Current Run Data

Generate the latest bucketed table with:

```bash
scripts/collect-run-data.sh --output docs/current-run-data.md
```

The source config lives in [`prospects/run-sources.json`](../prospects/run-sources.json).

Dispatch a complete ordered tool-cache proof with:

```bash
scripts/dispatch-tool-proof-series.sh --case aranya-rust
```

The tool-cache workflow saves to the live workspace `boringcache/docker-cache-proof` singular, shared with the Docker proof lane. Do not switch it to `boringcache/tool-cache-proof` unless that workspace has been provisioned; run [`26956862006`](https://github.com/boringcache/docker-cache-proofs/actions/runs/26956862006) proved the measured Aranya command could run, but cache save failed with a workspace 404 and the sccache proxy timed out with pending entries.

## Tool Cache Proof Queue

| Rank | Case | Adapter | Lead/team | Source | Current pain read | Proof action |
|---:|---|---|---|---|---|---|
| 1 | `aranya-rust` | Rust/sccache | `aranya-project/aranya` maintainers | [`aranya#135`](https://github.com/aranya-project/aranya/issues/135), [recent unit-test run](https://github.com/aranya-project/aranya/actions/runs/26174641840), [failed-save proof run](https://github.com/boringcache/docker-cache-proofs/actions/runs/26956862006) | Open issue; maintainers say GHA sccache is not ideal and discuss S3-backed sccache. Recent unit-test runs are still about 14-22m. First proof command succeeded but saved to the wrong workspace. | Re-run fresh after the workspace fix, verify cache save, then dispatch ordered rolling refs. |
| 2 | TODO `josh-rust-container` | Rust/sccache inside build container | `josh-project/josh` / Christian Schilling | [`josh#2025`](https://github.com/josh-project/josh/pull/2025), [recent Rust run](https://github.com/josh-project/josh/actions/runs/26950392659) | PR merged 2026-06-04; pain is very current. Their build containers run with `--network none`, so they added an `aws-sigv4-proxy` sidecar on a shared Podman network for R2 sccache without exposing credentials. Recent Rust runs are often 50-100m. | Add a dedicated container-side proof, not the generic host Rust lane: build container can reach only the BoringCache proxy/sidecar, no direct internet or credentials. This should also inform the Docker `--tool-cache` story for Rust inside containers. |
| 3 | `tiny-congress-rust` | Rust/sccache | `icook/tiny-congress` | [`tiny-congress#683`](https://github.com/icook/tiny-congress/pull/683), [recent CI run](https://github.com/icook/tiny-congress/actions/runs/24946974229) | The pain was real, but the team already added ARC parallelism plus Garage S3-backed sccache. Recent CI is about 7-8m. | Runnable now as a reference proof, not first-wave outreach. |
| 4 | pending Bazel case | Bazel | `qobilidop/z3wire` | [`z3wire#28`](https://github.com/qobilidop/z3wire/issues/28), [Bazel workflow](https://github.com/qobilidop/z3wire/actions?query=workflow%3ABazel) | Open issue; PR builds rebuilt hundreds of external dependency actions while main was cached. Direct remote-cache/cache-retention pain with runnable public CI. | Strong next adapter lane after Rust: add a Bazel proof only if we model `--remote_cache` rather than archiving Bazel internals. |
| 5 | pending compiler-cache case | sccache/ccache | Apache Kvrocks maintainers | [`kvrocks#2642`](https://github.com/apache/kvrocks/issues/2642), [CI workflow](https://github.com/apache/kvrocks/actions?query=workflow%3ACI) | Open issue; comments say Go tests are often >30m and about half of CI time is compilation/building, much of it third-party C++ deps. | Good C/C++ compiler-cache lead, but not a Go-only lane. Wire when we support ccache/sccache for mixed C++ builds. |
| 6 | pending Turbo case | Turbo | `galligan/xmtp-signet` | [`xmtp-signet#367`](https://github.com/galligan/xmtp-signet/issues/367), [CI workflow](https://github.com/galligan/xmtp-signet/actions?query=workflow%3ACI) | Open issue says CI is cold every run and asks for Turbo remote cache. Current runs are only around a minute, so pain is real but not high-dollar. | Keep as a lightweight Turbo reference; not first outreach unless we find heavier public runs. |
| 7 | pending Maven case | Maven | Camunda maintainers | [`camunda#19539`](https://github.com/camunda/camunda/issues/19539), [CI workflow](https://github.com/camunda/camunda/actions?query=workflow%3ACI) | Open issue asks to investigate Maven build-cache extension for incremental Java pipelines. Strategic adapter fit, but current public run extraction needs a tighter workflow filter. | Qualified lead; add a Maven lane after selecting a stable command/workflow slice. |
| 8 | pending Gradle case | Gradle | `cloudshiftchris`, Kotest-shaped reusable workflow users | [`gradle/actions#316`](https://github.com/gradle/actions/issues/316) | Open issue; pain is Gradle User Home/cache-key collision in reusable workflows. BoringCache Gradle remote cache helps build outputs, but does not automatically fix GitHub's missing full job identity for dependency/User Home cache keys. | Keep as qualified lead; add a Gradle proof only when we model the reusable-workflow collision or find a repo where remote build cache is the direct bottleneck. |

Tool-cache proof rules:

- Add a runnable case only when the public pain is current and the BoringCache adapter directly addresses it.
- Keep prospect proof lanes smaller than canonical benchmarks: one pinned command, fresh/rolling refs, and artifacts using the benchmark JSON/Markdown writer.
- Do not claim we fix workaround-specific infrastructure unless the proof models that shape. Josh is a good fit for BoringCache's sidecar/proxy model, but the proof must model Podman/build-container networking instead of host-side sccache.
- Use existing benchmark repos as product-readiness anchors, but do not add benchmark repos themselves as prospects.

## Wider Fan-Out Leads

These are sourceable public pain signals found while the Aranya/Tiny fresh proofs were running. Keep them in the run-data collector, but do not promote them to runnable proof lanes until the command shape is clear.

| Lead | Adapter | Pain | Qualification |
|---|---|---|---|
| Linera Rust CI | Rust/sccache | [`linera-protocol#5475`](https://github.com/linera-io/linera-protocol/issues/5475) says Rust cache has a 100% miss rate across PR, merge queue, and push; each workflow burns about 150 CPU-minutes. | Strong direct sccache prospect, but Rust overlaps Aranya/Josh. Add after Aranya if we want another Rust proof. |
| MapLibre Native FFI | sccache | [`maplibre-native-ffi#7`](https://github.com/maplibre/maplibre-native-ffi/issues/7) proposes R2 public-read sccache for heavy native/vendor compiles across CI and contributors. | Strong sidecar/shared-cache story; more contributor-local than CI proof, so measure carefully. |
| Vercel AI | Turbo | [`vercel/ai#15393`](https://github.com/vercel/ai/issues/15393) reports Turbo CI test jobs with 0/111 hits and about 6.5m rebuild/retest per matrix job. | Strongest current Turbo lead; good next non-Rust proof candidate if we can pin a repeatable `test_matrix` slice. |
| BambuStudio release | sccache/ccache | [`BambuStudio#452`](https://github.com/BenJule/BambuStudio/issues/452) says Linux/macOS ccache dropped warm builds, but Windows x64 remains about 60m with 0% sccache hit-rate history. | Good compiler-cache pain, but Windows/MSVC/PDB shape is not our first portable proof. |
| Besu integration tests | Gradle | [`besu#10427`](https://github.com/besu-eth/besu/issues/10427) asks to enable consistent Gradle caching across workflows. | Qualified Gradle lead; current public integration workflow runs are short, so needs a better slow slice. |
| toolchains_llvm sysroot | Bazel | [`toolchains_llvm#740`](https://github.com/bazel-contrib/toolchains_llvm/issues/740) shows remote/disk cache invalidation after Bazel server restart with a small repro. | Useful Bazel correctness content, but likely a rule/toolchain issue, not a BoringCache onboarding proof. |

## Outreach Order

1. Phentrieve after fresh + rolling proof lands: lead with "registry cache helped, but the slow run still spent 12m in API build/push."
2. Cardstack after a clean fresh/rolling run: lead with "cache export should not be slower than rerunning pnpm fetch."
3. Aranya: lead with their own S3-backed sccache comments; offer a focused sccache proof, not Docker.
4. Josh: strong follow-up after a container-side proof exists; lead with the no-internet build-container sidecar fit.
5. Tiny Congress: content/reference more than direct first-wave outreach.
