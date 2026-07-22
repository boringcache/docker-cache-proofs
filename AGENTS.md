# Docker Cache Proofs Agent Notes

- The Docker cache product path is `boringcache docker` publishing `type=boringcache` from the managed BuildKit daemon. Do not treat historical registry/OCI cache runs as managed-backend evidence.
- The managed path lets the CLI create its BuildKit builder by default, including when Docker tool cache is enabled. Do not pass backend selectors or a user-selected builder into the managed lifecycle.
- Keep local cache scopes disposable, source tokens from `/Users/gaurav/boringcache/web/.env` without printing them, and leave unrelated Docker or Colima containers alone.
