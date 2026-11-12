# syntax=docker/dockerfile:1.28@sha256:bb22d9815c728170f72750f4e5b0d672e06176142e1d602c7e66c050100b7e5b

FROM alpine:3.24@sha256:f59abe656b692d901e184be3445e084786602108599d2a51d229c0f5a48c71bf

LABEL org.opencontainers.image.title="Stunnel TLS Wrapper" \
      org.opencontainers.image.description="Stunnel on Alpine Linux - secure TLS tunnel" \
      org.opencontainers.image.url="https://github.com/mbologna/stunnel-container" \
      org.opencontainers.image.licenses="MIT"

# Install stunnel and what the entrypoint and health check run: openssl
# (the default certificate), envsubst (the config template), nc (the health
# check), tini (PID 1). gettext-envsubst is envsubst alone, without the rest
# of gettext.
RUN apk add --no-cache \
    ca-certificates \
    stunnel \
    openssl \
    netcat-openbsd \
    gettext-envsubst \
    tini

# Create stunnel user and required directories
# The stunnel package creates a stunnel user/group, so we use those.
# /etc/stunnel stays root-owned: stunnel only reads it. It writes only to its
# log, run and home directories.
RUN deluser stunnel 2>/dev/null || true && \
    delgroup stunnel 2>/dev/null || true && \
    addgroup -g 1000 -S stunnel && \
    adduser -u 1000 -S -G stunnel -h /var/lib/stunnel stunnel && \
    mkdir -p /var/lib/stunnel /var/run/stunnel /var/log/stunnel /etc/stunnel && \
    chown -R stunnel:stunnel /var/lib/stunnel /var/run/stunnel /var/log/stunnel

# Create stunnel configuration template. $STUNNEL_PEM is set by the
# entrypoint: the mounted /etc/stunnel/stunnel.pem, or a certificate it
# generates at start.
COPY <<'EOF' /etc/stunnel/stunnel.conf.template
foreground = yes
debug = $STUNNEL_DEBUG
syslog = no
output = /var/log/stunnel/stunnel.log

cert = $STUNNEL_PEM
key = $STUNNEL_PEM

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
export STUNNEL_DEBUG="${STUNNEL_DEBUG:-2}"

# Certificate: a mounted /etc/stunnel/stunnel.pem (certificate and key in one
# file) wins. Without one, generate a self-signed certificate at every start,
# in /tmp since the root filesystem may be read-only: a key generated at build
# time would be shared by everyone who pulls the image.
if [ -f /etc/stunnel/stunnel.pem ]; then
  export STUNNEL_PEM=/etc/stunnel/stunnel.pem
else
  export STUNNEL_PEM=/tmp/stunnel.pem
  echo "No /etc/stunnel/stunnel.pem mounted: generating a self-signed certificate"
  (umask 077 && openssl req -new -x509 -days 3650 -nodes -newkey rsa:2048 \
    -out "$STUNNEL_PEM" -keyout "$STUNNEL_PEM" \
    -subj "/CN=stunnel/O=Stunnel/C=US" 2>/dev/null)
fi

# Expand environment variables in config template
# Write to /tmp since root filesystem may be read-only
envsubst '$STUNNEL_SERVICE $STUNNEL_CLIENT $STUNNEL_ACCEPT $STUNNEL_CONNECT $STUNNEL_DEBUG $STUNNEL_PEM' \
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
