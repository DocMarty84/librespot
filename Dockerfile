# Build environment for compiling librespot targeting Ubuntu 22.04.
#
# This image holds only the toolchain (Rust + system deps). The source and the
# compile output stay OUTSIDE the image, mounted at run time, so:
#   - pulling new source needs NO image rebuild (only editing this file does)
#   - rebuilds are incremental: target/ persists, only changed crates recompile
#   - downloaded crates are cached in a named volume
#
# Build the env image ONCE (or after editing this file):
#   podman build -t librespot-build .
#
# Compile — re-run this every time you pull; the binary lands on the host at
# ./target-2204/release/librespot:
#   podman run --rm \
#       -v "$PWD:/src" \
#       -v "$PWD/target-2204:/src/target" \
#       -v librespot-registry:/usr/local/cargo/registry \
#       librespot-build \
#       cargo build --release --no-default-features \
#           --features alsa-backend,with-avahi,native-tls
#
# target-2204/ is used instead of the normal target/ so these 22.04 build
# artifacts don't collide with a native `cargo build` on the host.

FROM ubuntu:22.04

ENV DEBIAN_FRONTEND=noninteractive

# System dependencies:
#   build-essential  - C compiler and friends (required)
#   pkg-config       - locate system libraries at build time
#   libasound2-dev   - ALSA / Rodio audio backend
#   libssl-dev       - OpenSSL, for the default native-tls backend
#   ca-certificates + curl - to fetch the Rust toolchain over HTTPS
RUN apt-get update && apt-get install -y --no-install-recommends \
        build-essential \
        pkg-config \
        libasound2-dev \
        libssl-dev \
        ca-certificates \
        curl \
    && rm -rf /var/lib/apt/lists/*

# Install Rust via rustup, defaulting to the latest stable toolchain.
# Ubuntu 22.04's packaged rustc is too old: librespot requires Rust 1.85
# (edition 2024), which any recent stable release satisfies.
ENV RUSTUP_HOME=/usr/local/rustup \
    CARGO_HOME=/usr/local/cargo \
    PATH=/usr/local/cargo/bin:$PATH
RUN curl --proto '=https' --tlsv1.2 -sSf https://sh.rustup.rs \
        | sh -s -- -y --profile minimal

WORKDIR /src

# Default command if none is given: build with the usual feature set. The source
# is expected to be mounted at /src (see the header for the full run command).
CMD ["cargo", "build", "--release", "--no-default-features", \
     "--features", "alsa-backend,with-avahi,native-tls"]
