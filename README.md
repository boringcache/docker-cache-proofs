# docker-cache-proofs

Public benchmark runner for comparing Docker and build caches on real upstream projects.

Each case pins an upstream repository and source revision so fresh and rolling runs remain reproducible.

## Source Model

- Docker cases live in [`cases/`](cases/).
- Tool-cache cases live in [`tool-cases/`](tool-cases/).
- Archive-cache cases live in [`archive-cases/`](archive-cases/).
- Cases use upstream Dockerfiles and build contexts unless an explicit proof overlay is part of the case.

## What It Measures

Docker cases compare:

- GitHub Actions Cache
- BoringCache OCI cache
- BoringCache BuildKit backend

The ECR proof lane is retired. Its historical workflow runs and published
benchmark evidence remain available, but no active workflow can create or use
an ECR cache.

Fresh runs seed an isolated cache from the pinned source. Rolling runs build a later pinned revision against the same stable cache scope.

## Workflows

- [`Docker Cache Proof`](.github/workflows/docker-cache-proofs.yml)
- [`Tool Cache Proof`](.github/workflows/tool-cache-proofs.yml)
- [`Archive Cache Proof`](.github/workflows/archive-cache-proofs.yml)

## Output

Each run uploads machine-readable JSON and Markdown summaries using the same artifact shape as the other BoringCache benchmark repositories.
