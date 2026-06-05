# Painful Builds

Runnable proof workflows for public build-cache cases.

Each case pins real upstream commits, links the public pain signal, and emits the same benchmark JSON/Markdown artifact shape used by the BoringCache benchmark repos.

The GitHub repository is `boringcache/docker-cache-proofs`. The live BoringCache workspace used by both proof workflows is `boringcache/docker-cache-proof` singular.

## Docker Cases

| Case | Public pain | Proof source |
|---|---|---|
| `phentrieve-api` | [API Docker build exceeded 30-minute GitHub Actions timeout](https://github.com/berntpopp/phentrieve/issues/94); workflow says registry cache is more reliable than `gha` for PyTorch-sized images. | [Official slow API job](https://github.com/berntpopp/phentrieve/actions/runs/26388675097/job/77672942721); BoringCache proof runs in this repo. |
| `wormhole-solana` | Workflow says GHA cache can hang on large Docker uploads. | [Official slow Solana job](https://github.com/wormhole-foundation/native-token-transfers/actions/runs/26104579611/job/76764717136); BoringCache proof runs in this repo. |
| `cardstack-realm-server` | Cardstack workflow/action notes say GHA cache transfer for large pnpm-fetch layers was slower than rerunning fetch, so they moved to ECR registry cache. | [Official deploy sample](https://github.com/cardstack/boxel/actions/runs/25861223646); BoringCache proof runs in this repo. |
| `kvrocks-docker` | [Kvrocks CI optimization issue](https://github.com/apache/kvrocks/issues/2642): active discussion says native build/compile time is a large CI cost; the official workflow also builds and tests Docker images. | [Official CI sample](https://github.com/apache/kvrocks/actions/runs/26924643510); BoringCache proof runs in this repo. |
| `kvrocks-docker-sccache` | Same Kvrocks pain, using a proof Dockerfile overlay that keeps the upstream image shape while opting the build stage into BoringCache-backed `sccache`. | [Official CI sample](https://github.com/apache/kvrocks/actions/runs/26924643510); BoringCache proof runs in this repo. |

## Tool Cache Cases

Use the `Tool Cache Proof` workflow for prospect-shaped adapter runs that are not Docker image builds.

| Case | Adapter | Public pain | Readiness |
|---|---|---|---|
| `aranya-rust` | Rust/sccache | [Aranya CI compile-time issue](https://github.com/aranya-project/aranya/issues/135): open issue, GHA cache called not ideal, S3-backed sccache considered. | Pitch-ready first Rust proof. |
| `josh-rust-container` | Rust/sccache inside Podman containers | [Josh sidecar PR](https://github.com/josh-project/josh/pull/2025): build containers have no internet, so sccache needed an R2-signing sidecar. | Strategic sidecar proof; run singly before any ordered series. |
| `kvrocks-cpp-sccache` | C++/sccache plus Go integration tail | [Kvrocks CI optimization issue](https://github.com/apache/kvrocks/issues/2642): started from slow Go tests, then active comments called out C++ build and third-party dependency compile cost. | Multi-tool candidate; compiler-cache proof first, Docker proof adjacent. |
| `tiny-congress-rust` | Rust/sccache | [Tiny Congress PR](https://github.com/icook/tiny-congress/pull/683): ARC runners plus Garage S3-backed sccache. | Reference proof; they already built a workaround. |

## Manual Runs

Use the Docker lane in the `Docker Cache Proof` workflow with:

- `cache_lane=fresh` for one cold build on the pinned commit;
- `cache_lane=rolling` for one continuous-commit build on a stable case cache scope;
- `build_output=none`, `load`, or `local-registry` depending on the UX surface being measured;
- `case_id=kvrocks-docker-sccache` for the Docker + container-side `sccache` proof lane.

Fresh lanes may export cache for storage accounting, but they do not run a second build. Rolling lanes own prior-cache import/update evidence.

Use the tool-cache lane in the `Tool Cache Proof` workflow with:

- `cache_lane=fresh` for one pinned source build with a per-run cache tag;
- `cache_lane=rolling` for one commit build against a stable rolling cache tag;
- `case_id=aranya-rust`, `josh-rust-container`, `kvrocks-cpp-sccache`, or `tiny-congress-rust`.

For ordered fresh + rolling runs:

```bash
scripts/dispatch-proof-series.sh --case phentrieve-api --build-output none
scripts/dispatch-tool-proof-series.sh --case aranya-rust
```
