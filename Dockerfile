FROM rust:1.86 AS base

ARG FEATURES

RUN cargo install sccache --version ^0.9
RUN cargo install cargo-chef --version ^0.1

RUN apt-get update \
    && apt-get install -y clang libclang-dev gcc

ENV CARGO_HOME=/usr/local/cargo
ENV RUSTC_WRAPPER=sccache
ENV SCCACHE_DIR=/sccache

FROM base AS planner
WORKDIR /app

COPY . .

RUN --mount=type=cache,target=/usr/local/cargo/registry \
    --mount=type=cache,target=/usr/local/cargo/git \
    --mount=type=cache,target=$SCCACHE_DIR,sharing=locked \
    cargo chef prepare --recipe-path recipe.json

FROM base AS builder
WORKDIR /app

ARG WORLD_CHAIN_BUILDER_BIN="world-chain-builder"
COPY --from=planner /app/recipe.json recipe.json

RUN --mount=type=cache,target=$SCCACHE_DIR,sharing=locked \
    cargo chef cook --release --bin ${WORLD_CHAIN_BUILDER_BIN} --recipe-path recipe.json

COPY . .

RUN --mount=type=cache,target=/usr/local/cargo/registry \
    --mount=type=cache,target=/usr/local/cargo/git \
    --mount=type=cache,target=$SCCACHE_DIR,sharing=locked \
    cargo build --release --bin ${WORLD_CHAIN_BUILDER_BIN}

# Deployments depend on sh and wget
FROM debian:bookworm-slim
WORKDIR /app

# Install wget in the final image
RUN apt-get update && \
    apt-get install -y wget netcat-traditional && \
    rm -rf /var/lib/apt/lists/*


ARG WORLD_CHAIN_BUILDER_BIN="world-chain-builder"
COPY --from=builder /app/target/release/${WORLD_CHAIN_BUILDER_BIN} /usr/local/bin/

EXPOSE 30303 30303/udp 9001 8545 8546

ENTRYPOINT ["/usr/local/bin/world-chain-builder"]
