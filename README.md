# Painful Builds

Public proof runs for projects where repeated build work is visible in CI: Docker/BuildKit first, then compiler, task, and tool-cache adapters as we add them.

This repo is intentionally evidence-first:

- each case pins real upstream commits;
- Docker workflows run BoringCache OCI registry mode and the BoringCache `auto` Docker backend, which keeps OCI restore semantics while using the native accelerator for cache save/export;
- GitHub Actions Cache lanes are optional references because many upstreams already publish those numbers in their own runs;
- every case links the public pain signal separately from the proof run;
- generated artifacts preserve the same benchmark JSON/Markdown shape used by the existing BoringCache benchmark repos.

The GitHub repository is currently `boringcache/docker-cache-proofs`; the aligned slug would be `boringcache/painful-builds`. The product-facing name in this repo is now `Painful Builds` so it can become an adapter-wide proof surface instead of a Docker-only bucket.

## Docker Cases

| Case | Public pain | Proof source |
|---|---|---|
| `phentrieve-api` | [API Docker build exceeded 30-minute GitHub Actions timeout](https://github.com/berntpopp/phentrieve/issues/94); workflow says registry cache is more reliable than `gha` for PyTorch-sized images. | [Official slow API job](https://github.com/berntpopp/phentrieve/actions/runs/26388675097/job/77672942721); BoringCache proof runs in this repo. |
| `wormhole-solana` | Workflow says GHA cache can hang on large Docker uploads. | [Official slow Solana job](https://github.com/wormhole-foundation/native-token-transfers/actions/runs/26104579611/job/76764717136); BoringCache proof runs in this repo. |
| `cardstack-realm-server` | Cardstack workflow/action notes say GHA cache transfer for large pnpm-fetch layers was slower than rerunning fetch, so they moved to ECR registry cache. | [Official deploy sample](https://github.com/cardstack/boxel/actions/runs/25861223646); BoringCache proof runs in this repo. |

## First Manual Runs

Use the Docker lane in the `Docker Cache Proof` workflow with:

- `cache_lane=fresh` for cold plus warm rerun on the same pinned commit;
- `cache_lane=rolling` for a continuous-commit sample on a stable case cache scope;
- `include_gha_reference=false` unless we need an apples-to-apples reference in this repo;
- `build_output=none`, `load`, or `local-registry` depending on the UX surface being measured.

The `auto` lane records native accelerator evidence without switching warm reads away from the OCI registry-cache path.

For ordered fresh + rolling runs, use:

```bash
scripts/dispatch-proof-series.sh --case phentrieve-api --build-output none
```

For current official/proof run buckets, use:

```bash
scripts/collect-run-data.sh --output docs/current-run-data.md
```

See [`docs/prospect-proof-plan.md`](docs/prospect-proof-plan.md) for the Docker-first proof queue and non-Docker adapter leads.
