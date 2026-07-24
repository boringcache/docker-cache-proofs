# syntax=docker/dockerfile:1.7

######################## BASE IMAGE ##########################
FROM ubuntu:24.04 AS base

ARG PYTHON_VERSION=3.12

ENV PATH="/root/.local/bin:${PATH}"
ENV DEBIAN_FRONTEND=noninteractive
ENV UV_HTTP_TIMEOUT=500
ENV VIRTUAL_ENV="/opt/venv"
ENV UV_PYTHON_INSTALL_DIR=/opt/uv/python
ENV UV_LINK_MODE="copy"
ENV PATH="$VIRTUAL_ENV/bin:$PATH"

RUN apt update -y \
    && apt install -y curl \
    && rm -rf /var/lib/apt/lists/* \
    && apt clean

RUN curl -LsSf https://astral.sh/uv/install.sh | sh
RUN uv venv --python ${PYTHON_VERSION} --seed ${VIRTUAL_ENV}

FROM scratch AS local_src
COPY . /src

######################### BUILD IMAGE #########################
FROM base AS build-image

ARG SCCACHE_VERSION=v0.15.0
ARG SCCACHE_SHA256_AMD64=782d2b5dd7ae0a55ebe368ab258114d0928d019ac2d949ab85d5d02f3926709e
ENV PATH="/opt/boringcache/bin:/root/.cargo/bin:${PATH}"
ENV CARGO_INCREMENTAL=0
ENV SCCACHE_SERVER_UDS=/tmp/sccache.sock

RUN apt update -y \
    && apt install -y git build-essential libssl-dev pkg-config protobuf-compiler ca-certificates tar \
    && rm -rf /var/lib/apt/lists/* \
    && apt clean

RUN curl --proto '=https' --tlsv1.2 -sSf https://sh.rustup.rs | sh -s -- -y \
    && rustc --version && cargo --version && protoc --version

RUN set -eux; \
    archive="sccache-${SCCACHE_VERSION}-x86_64-unknown-linux-musl.tar.gz"; \
    curl -fsSL "https://github.com/mozilla/sccache/releases/download/${SCCACHE_VERSION}/${archive}" -o "/tmp/${archive}"; \
    printf '%s  %s\n' "$SCCACHE_SHA256_AMD64" "/tmp/${archive}" | sha256sum -c -; \
    tar -xzf "/tmp/${archive}" -C /tmp; \
    install -D -m 0755 "/tmp/sccache-${SCCACHE_VERSION}-x86_64-unknown-linux-musl/sccache" /opt/boringcache/bin/sccache; \
    rm -rf "/tmp/${archive}" "/tmp/sccache-${SCCACHE_VERSION}-x86_64-unknown-linux-musl"; \
    sccache --version

COPY --from=local_src /src /opt/sglang
WORKDIR /opt/sglang/sgl-model-gateway

RUN --mount=type=secret,id=boringcache-tool-cache-env \
    set -eux; \
    . /run/secrets/boringcache-tool-cache-env; \
    export RUSTC_WRAPPER=/opt/boringcache/bin/sccache SCCACHE_SERVER_UDS=/tmp/sccache.sock; \
    test -x "$RUSTC_WRAPPER"; \
    sccache --zero-stats >/dev/null 2>&1 || true; \
    uv pip install maturin; \
    cargo clean; \
    rm -rf bindings/python/dist/; \
    cd bindings/python; \
    ulimit -n 65536; \
    maturin build --release --features vendored-openssl --out dist; \
    cd ../..; \
    echo BEGIN_BORINGCACHE_SCCACHE_STATS; \
    sccache --show-stats; \
    echo END_BORINGCACHE_SCCACHE_STATS; \
    sccache --stop-server || true; \
    rm -rf /root/.cache

######################### ROUTER IMAGE #########################
FROM base AS router-image

COPY --from=build-image /opt/sglang/sgl-model-gateway/bindings/python/dist/*.whl dist/
RUN uv pip install --force-reinstall dist/*.whl
RUN rm -rf /root/.cache dist/ \
    && apt purge -y --auto-remove curl

ENTRYPOINT ["python3", "-m", "sglang_router.launch_router"]
