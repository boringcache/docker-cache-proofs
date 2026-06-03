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
- Fresh `main` run [`26833413643`](https://github.com/boringcache/docker-cache-proofs/actions/runs/26833413643): Auto cold 409s, Auto warm1 4s; OCI cold 689s, OCI warm1 3s. The fresh workflow wall time is slow because it includes intentional cold cache population, not because the same-source warm path is slow.
- Rolling1 run [`26842722855`](https://github.com/boringcache/docker-cache-proofs/actions/runs/26842722855): Auto commit build 368s with 100% read hit rate, 0.3s cache restore, 184s cache save/export, and about 7.0GB of new OCI blobs. OCI commit build 537s with 67.3% hit rate, 0.1s cache restore, 380.2s cache save/export, and about 6.5GB of new OCI blobs. This is the current continuous-commit pain: large cache update/export after a cache import, not hot same-source rebuild time.
- Rolling2 run [`26843436399`](https://github.com/boringcache/docker-cache-proofs/actions/runs/26843436399): Auto commit build 8s with 100% read hit rate and 0 new OCI blobs. OCI commit build 7s with 97.6% hit rate, 0.1s cache restore, 1.0s cache save/export, and one 16KB new OCI blob. This is the partially warm/small-delta case we needed beside the heavier rolling1 run.
- Rolling3 run [`26843568848`](https://github.com/boringcache/docker-cache-proofs/actions/runs/26843568848): Auto commit build 9s with 100% read hit rate and 0 new OCI blobs. OCI commit build 8s with 97.6% hit rate, 0.1s cache restore, 1.1s cache save/export, and one 16KB new OCI blob.

Phentrieve proof table:

| Proof | Link | Auto result | OCI result | Readiness read |
|---|---|---:|---:|---|
| Official heavy API run | [`26388675097`](https://github.com/berntpopp/phentrieve/actions/runs/26388675097/job/77672942721) | n/a | Build/push step 12m08s | Strong public pain: API Docker build hit 30-minute timeout before registry-cache fix. |
| Fresh `main` | [`26833413643`](https://github.com/boringcache/docker-cache-proofs/actions/runs/26833413643) | 409s cold, 4s warm1 | 689s cold, 3s warm1 | Ready for same-source hot proof; explain that fresh includes cold cache population. |
| Rolling1 | [`26842722855`](https://github.com/boringcache/docker-cache-proofs/actions/runs/26842722855) | 368s commit build | 537s commit build | Heavy rolling delta; product story is cache-update/export tax. |
| Rolling2 | [`26843436399`](https://github.com/boringcache/docker-cache-proofs/actions/runs/26843436399) | 8s commit build | 7s commit build | Small rolling delta; shows expected partially warm behavior. |
| Rolling3 | [`26843568848`](https://github.com/boringcache/docker-cache-proofs/actions/runs/26843568848) | 9s commit build | 8s commit build | Small rolling delta; confirms rolling2 was not a one-off. |

## Dispatch Shape

Use the dispatcher for a complete ordered proof series:

```bash
scripts/dispatch-proof-series.sh --case phentrieve-api --build-output none
```

For a single rolling commit after the rolling scope has already been seeded:

```bash
gh workflow run "Docker Cache Proof" \
  --repo boringcache/docker-cache-proofs \
  --ref main \
  -f case_id=phentrieve-api \
  -f ref_key=rolling1 \
  -f cache_lane=rolling \
  -f build_output=none \
  -f include_gha_reference=false \
  -f cli_ref=
```

Rolling runs must be ordered. Dispatching `rolling1`, `rolling2`, and `rolling3` concurrently turns the result into cache contention, not continuous-commit evidence.

## Current Run Data

Generate the latest bucketed table with:

```bash
scripts/collect-run-data.sh --output docs/current-run-data.md
```

The source config lives in [`prospects/run-sources.json`](../prospects/run-sources.json).

## Non-Docker Leads

| Rank | Adapter | Lead/team | Source | Why not in `docker-cache-proofs` | Next proof path |
|---:|---|---|---|---|---|
| 1 | Rust/sccache | `aranya-project/aranya` maintainers | [`aranya#135`](https://github.com/aranya-project/aranya/issues/135) | The pain is Rust compile/test cache on GHA runners, not image layer cache. | sccache adapter proof; compare GHA sccache/GHA cache versus BoringCache WebDAV/native. |
| 2 | Rust/sccache | `josh-project/josh` / Christian Schilling | [`josh#2025`](https://github.com/josh-project/josh/pull/2025) | The PR is R2 sccache sidecar glue for build containers with no direct internet. | sccache proof/content: "remove bespoke R2 sidecar cache glue." |
| 3 | Rust/sccache | `icook/tiny-congress` | [`tiny-congress#683`](https://github.com/icook/tiny-congress/pull/683) | The improvement is ARC runner parallelism plus Garage S3-backed sccache. | Content/reference; less urgent because they already built an in-cluster solution. |
| 4 | Turbo | `vercel/turborepo` commenters | [`turborepo#863`](https://github.com/vercel/turborepo/issues/863) | The pain is task-cache growth, not Docker cache export. | Turbo/Nx adapter proof and cleanup/growth content. |
| 5 | Gradle | `cloudshiftchris`, Kotest-shaped reusable workflow users | [`gradle/actions#316`](https://github.com/gradle/actions/issues/316) | The pain is Gradle User Home/cache-key behavior on reusable workflows. | Gradle adapter proof; OpenTelemetry Java remains the stronger benchmark anchor. |

## Outreach Order

1. Phentrieve after fresh + rolling proof lands: lead with "registry cache helped, but the slow run still spent 12m in API build/push."
2. Cardstack after a clean fresh/rolling run: lead with "cache export should not be slower than rerunning pnpm fetch."
3. Aranya: lead with their own S3-backed sccache comments; offer a focused sccache proof, not Docker.
4. Josh: content-led, because the PR already expresses the workaround in detail.
5. Tiny Congress: content/reference more than direct first-wave outreach.
