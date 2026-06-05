# Docker Cache Proofs Agent Notes

- Do not treat registry/OCI cache runs as native benchmark scheduler evidence. The product path is native only when `boringcache docker --backend native` publishes from inside the BuildKit daemon container.
- The benchmark-native path lets the CLI create its managed BuildKit builder by default, then runs the native publisher in that builder container without host-side ACL, chown, chmod, or sudo state repair.
- Keep local cache scopes disposable, source tokens from `/Users/gaurav/boringcache/web/.env` without printing them, and leave unrelated Docker or Colima containers alone.
