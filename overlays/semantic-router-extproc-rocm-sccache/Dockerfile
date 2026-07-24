# syntax=docker/dockerfile:1.7

# Benchmark-only toolchain layer for boringcache docker --tool-cache sccache.
FROM rust:1.90 AS rust-sccache

ARG SCCACHE_VERSION=0.14.0
ARG SCCACHE_SHA256_AMD64=8424b38cda4ecce616a1557d81328f3d7c96503a171eab79942fad618b42af44

RUN set -eux; \
    archive="sccache-v${SCCACHE_VERSION}-x86_64-unknown-linux-musl.tar.gz"; \
    curl -fsSL "https://github.com/mozilla/sccache/releases/download/v${SCCACHE_VERSION}/${archive}" -o "/tmp/${archive}"; \
    printf '%s  %s\n' "$SCCACHE_SHA256_AMD64" "/tmp/${archive}" | sha256sum -c -; \
    tar -xzf "/tmp/${archive}" -C /tmp; \
    install -m 0755 "/tmp/sccache-v${SCCACHE_VERSION}-x86_64-unknown-linux-musl/sccache" /usr/local/bin/sccache; \
    rm -rf "/tmp/${archive}" "/tmp/sccache-v${SCCACHE_VERSION}-x86_64-unknown-linux-musl"; \
    sccache --version

ENV CARGO_INCREMENTAL=0 \
    RUSTC_WRAPPER=sccache \
    SCCACHE_DIR=/tmp/sccache

# ============================================================================
# Stage 1: Build candle-binding Rust library (x86_64, CPU-only)
# ============================================================================
FROM rust-sccache AS candle-builder

RUN apt-get update && apt-get install -y \
    build-essential pkg-config lld clang libssl-dev \
    && rm -rf /var/lib/apt/lists/*

ENV CARGO_NET_GIT_FETCH_WITH_CLI=true \
    CARGO_INCREMENTAL=0 \
    CARGO_PROFILE_RELEASE_LTO=thin \
    CARGO_PROFILE_RELEASE_CODEGEN_UNITS=1

WORKDIR /app

COPY candle-binding/Cargo.toml candle-binding/Cargo.loc[k] ./candle-binding/
COPY tools/make/ tools/make/
COPY Makefile ./

RUN --mount=type=secret,id=boringcache-tool-cache-env \
    set -eux; \
    . /run/secrets/boringcache-tool-cache-env; \
    cd candle-binding; \
    mkdir -p src; \
    echo "pub fn _dummy() {}" > src/lib.rs; \
    OPENSSL_LIB_DIR=/usr/lib/x86_64-linux-gnu cargo build --release --no-default-features --target x86_64-unknown-linux-gnu; \
    sccache --stop-server || true; \
    rm -rf /tmp/sccache src

COPY candle-binding/src/ ./candle-binding/src/

RUN --mount=type=secret,id=boringcache-tool-cache-env \
    set -eux; \
    . /run/secrets/boringcache-tool-cache-env; \
    cd candle-binding; \
    find target -name "libcandle_semantic_router.so" -delete 2>/dev/null || true; \
    sccache --zero-stats >/dev/null 2>&1 || true; \
    OPENSSL_LIB_DIR=/usr/lib/x86_64-linux-gnu cargo build --release --no-default-features --target x86_64-unknown-linux-gnu; \
    echo BEGIN_BORINGCACHE_SCCACHE_STATS; \
    sccache --show-stats; \
    echo END_BORINGCACHE_SCCACHE_STATS; \
    sccache --stop-server || true; \
    rm -rf /tmp/sccache

# ============================================================================
# Stage 2: Build onnx-binding Rust library with ROCm support
# ============================================================================
FROM rust-sccache AS onnx-rocm-builder

RUN apt-get update && apt-get install -y \
    build-essential pkg-config lld clang libssl-dev \
    && rm -rf /var/lib/apt/lists/*

ENV CARGO_NET_GIT_FETCH_WITH_CLI=true \
    CARGO_INCREMENTAL=0 \
    CARGO_PROFILE_RELEASE_LTO=thin \
    CARGO_PROFILE_RELEASE_CODEGEN_UNITS=1

WORKDIR /app

COPY onnx-binding/Cargo.toml onnx-binding/Cargo.loc[k] ./onnx-binding/

RUN --mount=type=secret,id=boringcache-tool-cache-env \
    set -eux; \
    . /run/secrets/boringcache-tool-cache-env; \
    cd onnx-binding; \
    mkdir -p src; \
    echo "pub fn _dummy() {}" > src/lib.rs; \
    OPENSSL_LIB_DIR=/usr/lib/x86_64-linux-gnu cargo build --release --features rocm-dynamic --target x86_64-unknown-linux-gnu; \
    sccache --stop-server || true; \
    rm -rf /tmp/sccache src

COPY onnx-binding/src/ ./onnx-binding/src/

RUN --mount=type=secret,id=boringcache-tool-cache-env \
    set -eux; \
    . /run/secrets/boringcache-tool-cache-env; \
    cd onnx-binding; \
    find target -name "libonnx_semantic_router.so" -delete 2>/dev/null || true; \
    find target -name "libonnx_semantic_router.a" -delete 2>/dev/null || true; \
    OPENSSL_LIB_DIR=/usr/lib/x86_64-linux-gnu cargo build --release --features rocm-dynamic --target x86_64-unknown-linux-gnu; \
    echo "=== Verifying ONNX-ROCm library ==="; \
    find target -name "libonnx_semantic_router.so" -type f -exec ls -la {} \;; \
    sccache --stop-server || true; \
    rm -rf /tmp/sccache

# ============================================================================
# Stage 3: Build ml-binding Rust library
# ============================================================================
FROM rust-sccache AS ml-builder

ENV CARGO_NET_GIT_FETCH_WITH_CLI=true

WORKDIR /app

COPY ml-binding/Cargo.toml ml-binding/Cargo.loc[k] ./ml-binding/

RUN --mount=type=secret,id=boringcache-tool-cache-env \
    set -eux; \
    . /run/secrets/boringcache-tool-cache-env; \
    cd ml-binding; \
    mkdir -p src; \
    echo "pub fn _dummy() {}" > src/lib.rs; \
    cargo build --release --target x86_64-unknown-linux-gnu; \
    sccache --stop-server || true; \
    rm -rf /tmp/sccache src

COPY ml-binding/src/ ./ml-binding/src/

RUN --mount=type=secret,id=boringcache-tool-cache-env \
    set -eux; \
    . /run/secrets/boringcache-tool-cache-env; \
    cd ml-binding; \
    find target -name "libml_semantic_router.so" -delete 2>/dev/null || true; \
    cargo build --release --target x86_64-unknown-linux-gnu; \
    sccache --stop-server || true; \
    rm -rf /tmp/sccache

# ============================================================================
# Stage 4: Build nlp-binding Rust library
# ============================================================================
FROM rust-sccache AS nlp-builder

ENV CARGO_NET_GIT_FETCH_WITH_CLI=true

WORKDIR /app

COPY nlp-binding/Cargo.toml nlp-binding/Cargo.loc[k] ./nlp-binding/

RUN --mount=type=secret,id=boringcache-tool-cache-env \
    set -eux; \
    . /run/secrets/boringcache-tool-cache-env; \
    cd nlp-binding; \
    mkdir -p src; \
    echo "pub fn _dummy() {}" > src/lib.rs; \
    cargo build --release --target x86_64-unknown-linux-gnu; \
    sccache --stop-server || true; \
    rm -rf /tmp/sccache src

COPY nlp-binding/src/ ./nlp-binding/src/

RUN --mount=type=secret,id=boringcache-tool-cache-env \
    set -eux; \
    . /run/secrets/boringcache-tool-cache-env; \
    cd nlp-binding; \
    find target -name "libnlp_binding.so" -delete 2>/dev/null || true; \
    cargo build --release --target x86_64-unknown-linux-gnu; \
    sccache --stop-server || true; \
    rm -rf /tmp/sccache

# ============================================================================
# Stage 5: Build CK Flash Attention custom op library (ROCm / gfx942)
# ============================================================================
FROM rocm/dev-ubuntu-22.04:7.0 AS fa-builder

RUN apt-get update && apt-get install -y --no-install-recommends \
        cmake ninja-build composablekernel-dev && \
    rm -rf /var/lib/apt/lists/*

WORKDIR /build/ort-ck-flash-attn
COPY onnx-binding/ort-ck-flash-attn/CMakeLists.txt ./
COPY onnx-binding/ort-ck-flash-attn/include/ include/
COPY onnx-binding/ort-ck-flash-attn/src/ src/
COPY onnx-binding/ort-ck-flash-attn/tests/ tests/

RUN cmake -B build -G Ninja \
        -DCMAKE_BUILD_TYPE=Release \
        -DGPU_TARGETS=gfx942 \
        -DCMAKE_INSTALL_PREFIX=/opt/ort-ck-flash-attn && \
    cmake --build build --target ort_ck_flash_attn --parallel $(nproc) && \
    cmake --install build

# ============================================================================
# Stage 6: Build Go application (both candle and onnx binaries)
# ============================================================================
FROM golang:1.25 AS go-builder

RUN apt-get update && apt-get install -y libssl-dev file && rm -rf /var/lib/apt/lists/*

WORKDIR /app

RUN mkdir -p src/semantic-router
COPY src/semantic-router/go.mod src/semantic-router/go.sum src/semantic-router/
COPY src/semantic-router/go.onnx.mod src/semantic-router/go.onnx.sum src/semantic-router/
COPY candle-binding/go.mod candle-binding/semantic-router.go candle-binding/
COPY onnx-binding/go.mod onnx-binding/semantic-router.go onnx-binding/
COPY ml-binding/go.mod ml-binding/ml_binding.go ml-binding/
COPY nlp-binding/go.mod nlp-binding/nlp_binding.go nlp-binding/nlp_binding_mock.go nlp-binding/
COPY openvino-binding/go.mod openvino-binding/semantic-router.go openvino-binding/

RUN cd src/semantic-router && go mod download

COPY src/semantic-router/ src/semantic-router/

COPY --from=candle-builder /app/candle-binding/target/x86_64-unknown-linux-gnu/release/libcandle_semantic_router.so /app/candle-binding/target/release/
COPY --from=onnx-rocm-builder /app/onnx-binding/target/x86_64-unknown-linux-gnu/release/libonnx_semantic_router.so /app/onnx-binding/target/release/
COPY --from=ml-builder /app/ml-binding/target/x86_64-unknown-linux-gnu/release/libml_semantic_router.so /app/ml-binding/target/release/
COPY --from=nlp-builder /app/nlp-binding/target/x86_64-unknown-linux-gnu/release/libnlp_binding.so /app/nlp-binding/target/release/

ENV CGO_ENABLED=1 \
    LD_LIBRARY_PATH=/app/candle-binding/target/release:/app/onnx-binding/target/release:/app/ml-binding/target/release:/app/nlp-binding/target/release \
    GOOS=linux GOARCH=amd64 \
    GOFLAGS=-buildvcs=false

RUN echo "=== Verifying libraries ===" && \
    file /app/candle-binding/target/release/libcandle_semantic_router.so && \
    file /app/onnx-binding/target/release/libonnx_semantic_router.so && \
    file /app/ml-binding/target/release/libml_semantic_router.so && \
    file /app/nlp-binding/target/release/libnlp_binding.so

RUN mkdir -p bin && cd src/semantic-router && \
    CGO_CFLAGS="-I/app/candle-binding" \
    CGO_LDFLAGS="-L/app/candle-binding/target/release -L/app/ml-binding/target/release -L/app/nlp-binding/target/release -lcandle_semantic_router -lml_semantic_router -lnlp_binding" \
    go build -ldflags="-w -s" -o ../../bin/router-candle ./cmd

RUN cd src/semantic-router && \
    CGO_CFLAGS="-I/app/onnx-binding" \
    CGO_LDFLAGS="-L/app/onnx-binding/target/release -L/app/ml-binding/target/release -L/app/nlp-binding/target/release -lonnx_semantic_router -lml_semantic_router -lnlp_binding" \
    go build -modfile=go.onnx.mod -tags=onnx -ldflags="-w -s" -o ../../bin/router-onnx ./cmd

RUN mkdir -p /app/lib && \
    cp /app/candle-binding/target/release/libcandle_semantic_router.so /app/lib/ && \
    cp /app/onnx-binding/target/release/libonnx_semantic_router.so /app/lib/ && \
    cp /app/ml-binding/target/release/libml_semantic_router.so /app/lib/ && \
    cp /app/nlp-binding/target/release/libnlp_binding.so /app/lib/ && \
    echo "=== Staged libraries ===" && ls -la /app/lib/

# ============================================================================
# Final stage: ROCm 7.0 runtime image with ONNX Runtime ROCm
# ============================================================================
FROM rocm/dev-ubuntu-22.04:7.0

RUN apt-get update && apt-get install -y --no-install-recommends \
    ca-certificates openssl python3-pip \
    hipblas miopen-hip hipfft rccl && \
    apt-get clean && rm -rf /var/lib/apt/lists/*

RUN pip3 install --no-cache-dir \
    https://repo.radeon.com/rocm/manylinux/rocm-rel-7.0/onnxruntime_rocm-1.22.1-cp310-cp310-manylinux_2_27_x86_64.manylinux_2_28_x86_64.whl \
    'huggingface_hub[cli]==1.5.0' && \
    ORT_DIR=/usr/local/lib/python3.10/dist-packages/onnxruntime/capi && \
    ln -sf "$ORT_DIR"/libonnxruntime.so.* "$ORT_DIR/libonnxruntime.so"

WORKDIR /app

COPY --from=go-builder /app/bin/router-candle /app/router-candle
COPY --from=go-builder /app/bin/router-onnx /app/router-onnx
COPY --from=go-builder /app/lib/ /app/lib/
COPY onnx-binding/ort-ck-flash-attn/prebuilt/libort_ck_flash_attn.so* /app/lib/

COPY config/config.yaml /app/config/
COPY config/knowledge_bases/ /app/config/knowledge_bases/
COPY scripts/entrypoint.sh /app/entrypoint.sh
RUN chmod +x /app/entrypoint.sh

ENV ORT_DYLIB_PATH=/usr/local/lib/python3.10/dist-packages/onnxruntime/capi/libonnxruntime.so \
    LD_LIBRARY_PATH=/app/lib:/opt/rocm/lib:/usr/local/lib/python3.10/dist-packages/onnxruntime/capi \
    ORT_CK_FLASH_ATTN_LIB=/app/lib/libort_ck_flash_attn.so \
    AI_BINDING=onnx

EXPOSE 50051

ENTRYPOINT ["/app/entrypoint.sh"]
