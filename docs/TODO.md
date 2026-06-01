# TODO

- [x] Scaffold public proof repo with benchmark-style scripts and pinned case manifests.
- [x] Add BC OCI and BC auto workflow lanes from the existing Docker benchmark harness.
- [x] Add optional GHA reference lane for apples-to-apples claims when we choose to pay the runtime.
- [x] Wire local registry push emulation for registry mode and auto mode with comparable output semantics.
- [ ] Add a rolling-sequence workflow that runs `main`, `rolling1`, `rolling2`, and `rolling3` in order for each case.
- [ ] Publish a first proof table from successful artifacts, not from pasted upstream logs.

## Output Emulation Notes

For registry-mode Buildx, `build_output=load` and `build_output=local-registry` are straightforward: add `--load` or `--push` to the same `docker buildx build` invocation.

For auto mode, the wrapper still runs the normal `docker buildx build` command, so `--load` and local-registry `--push` stay on the same Docker UX surface while BoringCache removes the registry `cache-to` export and records native accelerator evidence.
