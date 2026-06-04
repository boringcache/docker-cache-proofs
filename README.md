# Painful Builds

Public proof runs for projects where repeated build work is visible in CI: Docker/BuildKit first, then compiler, task, and tool-cache adapters as we add them.

This repo is intentionally evidence-first:

- each case pins real upstream commits;
- Docker workflows run BoringCache OCI registry mode and the BoringCache `auto` Docker backend, which keeps OCI restore semantics while using the native accelerator for cache save/export;
- GitHub Actions Cache references stay in the linked upstream evidence instead of sharing a proof run;
- every case links the public pain signal separately from the proof run;
- generated artifacts preserve the same benchmark JSON/Markdown shape used by the existing BoringCache benchmark repos.

The GitHub repository is currently `boringcache/docker-cache-proofs`; the aligned slug would be `boringcache/painful-builds`. The product-facing name in this repo is now `Painful Builds` so it can become an adapter-wide proof surface instead of a Docker-only bucket.

The live BoringCache workspace used by both proof workflows is `boringcache/docker-cache-proof` singular. Keep that slug aligned until a future `painful-builds` workspace is provisioned.

## Docker Cases

| Case | Public pain | Proof source |
|---|---|---|
| `phentrieve-api` | [API Docker build exceeded 30-minute GitHub Actions timeout](https://github.com/berntpopp/phentrieve/issues/94); workflow says registry cache is more reliable than `gha` for PyTorch-sized images. | [Official slow API job](https://github.com/berntpopp/phentrieve/actions/runs/26388675097/job/77672942721); BoringCache proof runs in this repo. |
| `wormhole-solana` | Workflow says GHA cache can hang on large Docker uploads. | [Official slow Solana job](https://github.com/wormhole-foundation/native-token-transfers/actions/runs/26104579611/job/76764717136); BoringCache proof runs in this repo. |
| `cardstack-realm-server` | Cardstack workflow/action notes say GHA cache transfer for large pnpm-fetch layers was slower than rerunning fetch, so they moved to ECR registry cache. | [Official deploy sample](https://github.com/cardstack/boxel/actions/runs/25861223646); BoringCache proof runs in this repo. |

## Tool Cache Cases

Use the `Tool Cache Proof` workflow for prospect-shaped adapter runs that are not Docker image builds.

| Case | Adapter | Public pain | Readiness |
|---|---|---|---|
| `aranya-rust` | Rust/sccache | [Aranya CI compile-time issue](https://github.com/aranya-project/aranya/issues/135): open issue, GHA cache called not ideal, S3-backed sccache considered. | Pitch-ready first Rust proof. |
| `tiny-congress-rust` | Rust/sccache | [Tiny Congress PR](https://github.com/icook/tiny-congress/pull/683): ARC runners plus Garage S3-backed sccache. | Reference proof; they already built a workaround. |

## First Manual Runs

Use the Docker lane in the `Docker Cache Proof` workflow with:

- `cache_lane=fresh` for one cold build on the pinned commit;
- `cache_lane=rolling` for one continuous-commit build on a stable case cache scope;
- `build_output=none`, `load`, or `local-registry` depending on the UX surface being measured.

Fresh lanes may export cache for storage accounting, but they do not run a second build. Rolling lanes own prior-cache import/update evidence.

Use the tool-cache lane in the `Tool Cache Proof` workflow with:

- `cache_lane=fresh` for one pinned source build with a per-run cache tag;
- `cache_lane=rolling` for one commit build against a stable rolling cache tag;
- `case_id=aranya-rust` first, because its pain is current and directly addressed by the Rust/sccache adapter.

For ordered fresh + rolling runs, use:

```bash
scripts/dispatch-proof-series.sh --case phentrieve-api --build-output none
scripts/dispatch-tool-proof-series.sh --case aranya-rust
```

For current official/proof run buckets, use:

```bash
scripts/collect-run-data.sh --output docs/current-run-data.md
```

See [`docs/prospect-proof-plan.md`](docs/prospect-proof-plan.md) for the Docker-first proof queue and non-Docker adapter leads. For cross-session context, start with [`docs/session-handoff.md`](docs/session-handoff.md).
