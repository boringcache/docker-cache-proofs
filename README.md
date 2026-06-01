# Docker Cache Proofs

Public proof runs for Docker/BuildKit projects where cache import/export time, image export time, and runner size materially affect CI latency.

This repo is intentionally evidence-first:

- each case pins real upstream commits;
- workflows run BoringCache OCI registry mode and the BoringCache `auto` Docker backend, which keeps OCI restore semantics while using the native accelerator for cache save/export;
- GitHub Actions Cache lanes are optional references because many upstreams already publish those numbers in their own runs;
- generated artifacts preserve the same benchmark JSON/Markdown shape used by the existing BoringCache benchmark repos.

## Cases

| Case | Why it is here | Source signal |
|---|---|---|
| `phentrieve-api` | ML/PyTorch-sized API image with registry cache preferred over GHA cache and runs on the standard 4 vCPU / 16 GiB GitHub-hosted runner. | `berntpopp/phentrieve` run `26311969942`, job `77462686222`. |
| `wormhole-solana` | Heavy Solana Docker target where the image export/push phase can dominate after compile work. | `wormhole-foundation/native-token-transfers` run `26104579611`, job `76764717136`. |
| `cardstack-realm-server` | ECR image push plus GitHub Actions Cache export tail, useful for showing cache export behavior separately from image push. | `cardstack/boxel` run `25861223646`. |

## First Manual Runs

Use the `Docker Cache Proof` workflow with:

- `cache_lane=fresh` for cold plus warm rerun on the same pinned commit;
- `cache_lane=rolling` for a continuous-commit sample on a stable case cache scope;
- `include_gha_reference=false` unless we need an apples-to-apples reference in this repo;
- `build_output=none`, `load`, or `local-registry` depending on the UX surface being measured.

The `auto` lane records native accelerator evidence without switching warm reads away from the OCI registry-cache path.
