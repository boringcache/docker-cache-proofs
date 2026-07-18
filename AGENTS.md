# Docker Cache Proofs Agent Notes

- Do not treat registry/OCI cache runs as managed-exporter scheduler evidence. The product path is native only when `boringcache docker --backend boringcache` publishes `type=boringcache` from inside the managed BuildKit daemon container.
- The managed-exporter path lets the CLI create its BuildKit builder by default, including when Docker tool cache is enabled. Do not hardcode the tool-cache composition to `--backend registry` or pass a user-selected builder into the managed lifecycle.
- Keep local cache scopes disposable, source tokens from `/Users/gaurav/boringcache/web/.env` without printing them, and leave unrelated Docker or Colima containers alone.
