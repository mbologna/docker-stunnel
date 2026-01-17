# syntax=docker/dockerfile:1.7

FROM alpine:latest

LABEL org.opencontainers.image.title="Stunnel TLS Wrapper" \
      org.opencontainers.image.description="Stunnel on Alpine Linux - secure TLS tunnel" \
      org.opencontainers.image.url="https://github.com/mbologna/docker-stunnel" \
      org.opencontainers.image.licenses="MIT"

# Install stunnel and dependencies
RUN apk add --no-cache \
    ca-certificates \
    stunnel \
    openssl \
    netcat-openbsd \
    gettext \
    tini

# Create stunnel user and required directories
# The stunnel package creates a stunnel user/group, so we use those
RUN deluser stunnel 2>/dev/null || true && \
    delgroup stunnel 2>/dev/null || true && \
    addgroup -g 1000 -S stunnel && \
    adduser -u 1000 -S -G stunnel -h /var/lib/stunnel stunnel && \
    mkdir -p /var/lib/stunnel /var/run/stunnel /var/log/stunnel /etc/stunnel && \
    chown -R stunnel:stunnel /var/lib/stunnel /var/run/stunnel /var/log/stunnel /etc/stunnel

# Generate self-signed certificate at build time
RUN openssl req -new -x509 -days 3650 -nodes \
    -out /etc/stunnel/stunnel.pem \
    -keyout /etc/stunnel/stunnel.pem \
    -subj "/CN=stunnel/O=Stunnel/C=US" && \
    chmod 600 /etc/stunnel/stunnel.pem && \
    chown stunnel:stunnel /etc/stunnel/stunnel.pem

# Create stunnel configuration template
COPY --chown=stunnel:stunnel <<'EOF' /etc/stunnel/stunnel.conf.template
foreground = yes
debug = 5
syslog = no
output = /var/log/stunnel/stunnel.log

cert = /etc/stunnel/stunnel.pem
key = /etc/stunnel/stunnel.pem

[$STUNNEL_SERVICE]
client = $STUNNEL_CLIENT
accept = $STUNNEL_ACCEPT
connect = $STUNNEL_CONNECT
EOF

# Create entrypoint script
COPY --chmod=755 <<'EOF' /usr/local/bin/entrypoint.sh
#!/bin/sh
set -e

# Set defaults
export STUNNEL_SERVICE="${STUNNEL_SERVICE:-stunnel}"
export STUNNEL_CLIENT="${STUNNEL_CLIENT:-no}"
export STUNNEL_ACCEPT="${STUNNEL_ACCEPT:-6697}"
export STUNNEL_CONNECT="${STUNNEL_CONNECT:-localhost:6667}"

# Expand environment variables in config template
# Write to /tmp since root filesystem may be read-only
envsubst '$STUNNEL_SERVICE $STUNNEL_CLIENT $STUNNEL_ACCEPT $STUNNEL_CONNECT' \
  < /etc/stunnel/stunnel.conf.template \
  > /tmp/stunnel.conf

# Display configuration for debugging
echo "=== Stunnel Configuration ==="
cat /tmp/stunnel.conf
echo "============================="

# Start stunnel with config from /tmp
exec stunnel /tmp/stunnel.conf
EOF

USER stunnel
WORKDIR /var/lib/stunnel

EXPOSE 6697

HEALTHCHECK --interval=30s --timeout=5s --start-period=5s --retries=3 \
  CMD nc -z localhost ${STUNNEL_ACCEPT:-6697} || exit 1

ENTRYPOINT ["/sbin/tini", "--"]
CMD ["/usr/local/bin/entrypoint.sh"]
