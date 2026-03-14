FROM debian:bookworm-slim AS builder

RUN apt-get update && apt-get install -y --no-install-recommends \
    build-essential git ca-certificates curl && \
    rm -rf /var/lib/apt/lists/*

# sjasmplus — build from main (v1.22.0+)
RUN git clone --depth 1 --recurse-submodules https://github.com/z00m128/sjasmplus.git /tmp/sjasmplus && \
    cd /tmp/sjasmplus && \
    make clean && make -j$(nproc) && \
    cp sjasmplus /usr/local/bin/

# iz-cpm — pre-built binary v1.3.4
RUN curl -sL https://github.com/ivanizag/iz-cpm/releases/download/v1.3.4/iz-cpm-linux-v1.3.4.tar.gz | \
    tar xz -C /tmp && \
    cp /tmp/iz-cpm-linux-v1.3.4/iz-cpm /usr/local/bin/

# --- runtime image ---
FROM debian:bookworm-slim

RUN apt-get update && apt-get install -y --no-install-recommends \
    make cpmtools && \
    rm -rf /var/lib/apt/lists/*

COPY --from=builder /usr/local/bin/sjasmplus /usr/local/bin/
COPY --from=builder /usr/local/bin/iz-cpm /usr/local/bin/

WORKDIR /workspace
ENTRYPOINT ["make"]
