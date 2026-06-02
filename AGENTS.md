# Docker Cache Proofs Agent Notes

- For local native BuildKit or Colima investigations, read `docs/native-buildkit-local-harness.md` before running commands.
- Do not treat `boringcache docker --backend auto` sidecar failures as native benchmark scheduler evidence. That product path needs the versioned native sidecar image, or `BORINGCACHE_NATIVE_SIDECAR_IMAGE`.
- The benchmark-native path is `scripts/run-boringcache-native-buildkit-benchmark.sh`, which runs `boringcache buildkit --backend native` in-process with a Linux `boringcache` binary mounted into the CLI container.
- Keep local cache scopes disposable, source tokens from `/Users/gaurav/boringcache/web/.env` without printing them, and leave unrelated Docker or Colima containers alone.
