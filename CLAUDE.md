# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Overview

A lightweight Docker container that wraps [stunnel](https://www.stunnel.org/) on Alpine Linux to add TLS encryption to any TCP service. Published as `mbologna/docker-stunnel` to Docker Hub and GHCR. Supports `linux/amd64` and `linux/arm64`.

## Build & Run

```bash
# Build locally
docker build -t stunnel:custom .

# Run with docker-compose
cp .env.example .env
docker-compose up -d

# Multi-arch build
docker buildx build --platform linux/amd64,linux/arm64 -t stunnel:custom .
```

## CI/CD Pipeline

The GitHub Actions workflow (`.github/workflows/build-scan-push.yaml`) runs on push to `main`, tags `v*.*.*`, PRs, and weekly (Monday 06:00 UTC):

1. **Lint** — Hadolint (Dockerfile, errors only) + yamllint (docker-compose.yml, k8s/)
2. **Build** — Multi-arch build and push to Docker Hub + GHCR, with SBOM generation
3. **Security** — Trivy and Grype vulnerability scans (parallel matrix), results uploaded as SARIF
4. **Test** — Integration test: starts container, waits for healthy status, verifies port binding

Security scans and integration tests only run on non-PR events (they need the pushed image).

## Architecture

The entire application is a single `Dockerfile`:
- Installs stunnel + openssl + tini on Alpine
- Generates a self-signed cert at build time (`/etc/stunnel/stunnel.pem`)
- Both the config template and entrypoint script are embedded inline in the Dockerfile using heredoc `COPY` syntax — there are no separate script files
- Entrypoint uses `envsubst` to render the config template to `/tmp/stunnel.conf` at startup (supports read-only root filesystem)
- Configuration is controlled via `STUNNEL_*` env vars (see `.env.example` for the full list)
- Runs as non-root user (UID/GID 1000), all capabilities dropped

### Kubernetes Manifests

`k8s/` contains production-grade manifests managed via Kustomize (`kustomization.yaml`): namespace, configmap, deployment, and service. The deployment enforces read-only root filesystem with `emptyDir` volumes for `/tmp`, `/var/run/stunnel`, and `/var/log/stunnel`.

## Testing Locally

There is no test script. To test locally, mirror what CI does:

```bash
docker build -t stunnel:test .
docker run -d --name stunnel-test -e STUNNEL_CONNECT=localhost:6667 stunnel:test
sleep 5
docker exec stunnel-test nc -zv localhost 6697
docker rm -f stunnel-test
```

## Conventions

- **Commit messages**: Follow [Conventional Commits](https://www.conventionalcommits.org/)
- **YAML**: Max 120 char line length (warning level)
- **Dockerfile**: Must pass Hadolint at error threshold
