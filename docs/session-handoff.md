# Painful Builds Session Handoff

Last updated: 2026-06-03.

Use this note to summon the prospect/proof context from another Codex session. The repo is still hosted as `boringcache/docker-cache-proofs`, but the working product frame is `Painful Builds`: Docker/BuildKit first, adapter-wide later.

## Where To Start

- Main proof plan: `docs/prospect-proof-plan.md`.
- Run bucket collector: `scripts/collect-run-data.sh --output docs/current-run-data.md`.
- Ordered proof dispatcher: `scripts/dispatch-proof-series.sh --case phentrieve-api --build-output none`.
- Native BuildKit local debugging: `docs/native-buildkit-local-harness.md`.
- Prospect/source inventory: `prospects/run-sources.json`.

## Phentrieve Proof State

Pain source:

- Issue: https://github.com/berntpopp/phentrieve/issues/94.
- Official heavy API job: https://github.com/berntpopp/phentrieve/actions/runs/26388675097/job/77672942721.
- Workflow cache comment: https://github.com/berntpopp/phentrieve/blob/main/.github/workflows/docker-publish.yml#L113-L117.

BoringCache proof runs:
Note: these proof runs predate the single-phase lane split; current `fresh` runs record one cold build only.

| Proof | Run | Auto | OCI | Read |
|---|---|---:|---:|---|
| Historical fresh main | https://github.com/boringcache/docker-cache-proofs/actions/runs/26833413643 | 409s cold, 4s warm | 689s cold, 3s warm | Pre-split run; current fresh lane records the cold build only. |
| Rolling1 | https://github.com/boringcache/docker-cache-proofs/actions/runs/26842722855 | 368s commit | 537s commit | Heavy rolling delta; pain is cache update/export after import. |
| Rolling2 | https://github.com/boringcache/docker-cache-proofs/actions/runs/26843436399 | 8s commit | 7s commit | Small rolling delta; expected partially warm behavior. |
| Rolling3 | https://github.com/boringcache/docker-cache-proofs/actions/runs/26843568848 | 9s commit | 8s commit | Confirms rolling2 was not a one-off. |

## Rolling1 Materialization Read

User concern: rolling export materialization looked serial/slower than before.

Answer: final export was not accidentally capped to one worker, but the warm rolling online path left most materialization until the final drain.

Key Auto rolling1 log lines:

```text
buildkit-cache online-publish: materialize_policy=warm-active resource lane materialize_jobs=1/2 publish_slots=2/2 stage_target_mib=512.0/1024.0
buildkit-cache online-publish: materialize pass-24 status=1 seconds=60
buildkit-cache online-publish: materialize pass-24 failed: BuildKit overlay materialization stopped because /tmp/.../online-publish.stop exists
buildkit-cache export-local: compression=gzip-fast materialized_overlay_diffs=19 reused_overlay_diffs=1 planned_overlay_diffs=19 selected_overlay_diffs=19 new_overlay_diffs=0 skipped_transient_overlay_diffs=0 materialize_jobs=8 compressed_bytes=7041048466 plan_ms=1 write_ms=64586 index_ms=0 total_ms=64588
buildkit-cache online-publish: final export status=0 seconds=64
buildkit-cache online-publish: final save status=0 seconds=120
```

Artifact metrics for Auto rolling1:

- `command_ms=169801`.
- `cache_save_export_seconds=184`.
- `final_export_seconds=64`.
- `final_export_materialize_total_millis=64588`.
- `final_export_materialize_write_millis=64586`.
- `final_export_materialize_selected_overlay_diffs=19`.
- `final_export_materialize_written_overlay_diffs=19`.
- `final_export_materialize_compressed_bytes=7041048466`.
- `final_save_seconds=120`.
- `final_save_missing_blob_count=18`.
- `final_save_uploaded_blob_bytes=7041074898`.
- `requested_materialize_jobs=8`.
- `resource_lane_materialize_jobs=1`.
- `resource_lane_max_materialize_jobs=2`.
- `materialize_policy=warm-active`.
- `resource_growth_passes=0`.
- `stage_backlog_blob_bytes_max=0`.

Interpretation:

- Online materialization was effectively constrained to `1/2` workers on the hosted runner and did not grow.
- The online passes mostly skipped because BuildKit metadata looked unchanged.
- One real online pass ran for 60s and was stopped by finalization.
- Final export did use `materialize_jobs=8` through the Rayon path, but still had to write about 7.0GB / 19 overlay diffs at the end.
- Backend upload was not the only long pole. The proxy-side summary showed no retry/error story and an upload batch around 49.6s; the larger user-visible delay came from local materialize/export plus final save orchestration.

Compare with older local-registry rolling run `26834044546`:

- Auto did about 133s of materialization during the build.
- Final export was about 2ms because the large layer work had already been overlapped.
- That run used `cold-isolated-active` and saw stage backlog/growth, unlike rolling1 `warm-active`.

Current hypothesis:

- The regression is not "final export parallelism broke".
- The regression is "warm-active rolling did not discover or stage the large final graph early enough, so the parallel final exporter paid the whole materialization bill after the build".
- `output=none` may expose this more than `local-registry` because the BuildKit graph becomes useful to the online materializer later.

## Code Pointers

Relevant BoringCache CLI files live under `/Users/gaurav/boringcache/web/cli`:

- `src/commands/internal/buildkit_cache.rs`: `online_publish_cache`, `OnlineSidecarResourceLane`, final `export_materialized_image`.
- `src/commands/internal/buildkit_export_inspect.rs`: `materialize_missing_overlay_diffs` builds the Rayon worker pool and logs `materialize_jobs`.
- `src/commands/adapters/command/native_buildkit.rs`: default requested materialize jobs is 8 and is passed to the internal command.

Important lines from the current checkout:

- Final export passes `args.materialize_jobs`: `buildkit_cache.rs:1803`.
- Warm-active lane starts at 1 materializer on 4c/16GB runners: `buildkit_cache.rs:3357`.
- Final materializer uses a Rayon pool and `par_iter`: `buildkit_export_inspect.rs:1405`.

## Next Product/Proof Actions

1. Add artifact fields or summary rendering for final export `materialize_jobs`, so this diagnosis is visible without pulling raw logs.
2. Re-run Phentrieve rolling1 after changing warm-active scheduling or materialization discovery to confirm the 64s final export drain shrinks.
3. Consider a warm-active policy tweak: start at 2 materializers on 4c/16GB only when final graph/backlog evidence is large, or add a pre-final materialization drain with growth before final save.
4. Compare `output=none` and `local-registry` on the same rolling commit to prove whether output mode changes when metadata becomes materializable.
5. Keep outreach messaging honest: Phentrieve is strong proof for same-source hot rebuilds, while rolling1 is still a product-readiness issue around heavy cache update/export.
