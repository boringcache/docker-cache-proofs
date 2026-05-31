# TODO

- [x] Scaffold public proof repo with benchmark-style scripts and pinned case manifests.
- [x] Add BC OCI and BC native workflow lanes from the existing Docker benchmark harness.
- [x] Add optional GHA reference lane for apples-to-apples claims when we choose to pay the runtime.
- [ ] Wire local registry push emulation for registry mode and native mode with comparable output semantics.
- [ ] Add a rolling-sequence workflow that runs `main`, `rolling1`, `rolling2`, and `rolling3` in order for each case.
- [ ] Publish a first proof table from successful artifacts, not from pasted upstream logs.

## Output Emulation Notes

For registry-mode Buildx, `build_output=load` and `build_output=local-registry` are straightforward: add `--load` or `--push` to the same `docker buildx build` invocation.

For native mode, we need a real local registry reachable from the BuildKit container and the BoringCache wrapper container, then use a native BuildKit image output such as `type=image,name=...,push=true`. Until that is wired and verified, native proof runs should use `build_output=none`.

