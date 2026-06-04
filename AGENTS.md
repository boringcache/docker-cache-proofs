# Docker Cache Proofs Agent Notes

- For local native BuildKit or Colima investigations, read `docs/native-buildkit-local-harness.md` before running commands.
- Do not treat `boringcache docker --backend auto` registry fallback as native benchmark scheduler evidence. The product path is native only when the current CLI process can read the BuildKit root; Docker-managed, VM-only, root-only, or remote state uses the registry path.
- The benchmark-native path is `scripts/run-boringcache-native-buildkit-benchmark.sh`, which runs `boringcache buildkit --backend native` in-process with a Linux `boringcache` binary mounted into the CLI container.
- Keep local cache scopes disposable, source tokens from `/Users/gaurav/boringcache/web/.env` without printing them, and leave unrelated Docker or Colima containers alone.
