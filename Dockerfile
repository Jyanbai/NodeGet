# syntax=docker/dockerfile:1
# Modified Dockerfile: use Debian-based Rust image for compilation
# to avoid musl libc renameat2 issue on Alpine 3.22

FROM rust:latest AS source-binary

WORKDIR /src

RUN apt-get update && apt-get install -y --no-install-recommends \
    build-essential \
    pkg-config \
    libssl-dev \
    && rm -rf /var/lib/apt/lists/*

COPY . .

RUN cargo build --package nodeget-server --profile minimal --locked \
    && mkdir -p /out \
    && cp target/minimal/nodeget-server /out/nodeget-server \
    && chmod 0755 /out/nodeget-server

FROM debian:bookworm-slim AS runtime

LABEL org.opencontainers.image.title="NodeGet Server"
LABEL org.opencontainers.image.description="NodeGet server runtime image (self-built fork)"
LABEL org.opencontainers.image.source="https://github.com/Jyanbai/NodeGet"
LABEL org.opencontainers.image.licenses="AGPL-3.0"

RUN apt-get update && apt-get install -y --no-install-recommends \
    ca-certificates \
    tzdata \
    && rm -rf /var/lib/apt/lists/* \
    && update-ca-certificates \
    && mkdir -p /etc/nodeget /var/lib/nodeget

COPY docker/entrypoint.sh /usr/local/bin/nodeget-entrypoint

RUN chmod 0755 /usr/local/bin/nodeget-entrypoint

WORKDIR /etc/nodeget

ENV NODEGET_PORT="2211" \
    NODEGET_LOG_FILTER="info" \
    NODEGET_CONFIG_PATH="/etc/nodeget/config.toml" \
    NODEGET_DATABASE_URL="sqlite:///var/lib/nodeget/nodeget.db?mode=rwc"

EXPOSE 2211

COPY --from=source-binary /out/nodeget-server /usr/local/bin/nodeget-server

ENTRYPOINT ["/usr/local/bin/nodeget-entrypoint"]
CMD ["serve"]
