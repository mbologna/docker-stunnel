# Stunnel Docker Container

[![Docker Pulls](https://img.shields.io/docker/pulls/mbologna/docker-stunnel)](https://hub.docker.com/r/mbologna/docker-stunnel)
[![GitHub Workflow Status](https://img.shields.io/github/actions/workflow/status/mbologna/docker-stunnel/build-scan-push.yml?branch=main)](https://github.com/mbologna/docker-stunnel/actions)
[![Docker Image Size](https://img.shields.io/docker/image-size/mbologna/docker-stunnel/latest)](https://hub.docker.com/r/mbologna/docker-stunnel)
[![License](https://img.shields.io/github/license/mbologna/docker-stunnel)](LICENSE)

A lightweight, secure Stunnel TLS wrapper container based on Alpine Linux. Perfect for adding TLS encryption to any TCP service.

## Technical Features

- 🏗️ **Multi-architecture support:** `linux/amd64`, `linux/arm64`
- 🔒 **Security-hardened:** Non-root user, read-only root filesystem, minimal capabilities
- 📊 **Health checks:** Built-in monitoring with liveness/readiness probes
- 📦 **SBOM generation:** Software Bill of Materials for supply chain security
- 🔍 **Automated vulnerability scanning:** Trivy and Grype scans in CI/CD
- 🚀 **Optimized builds:** Minimal Alpine base, layer caching
- ☸️ **Kubernetes-ready:** Production-grade manifests included
- 🔐 **Self-signed certificate:** Generated at build time, no runtime generation needed

## Quick Start

### Docker Run

```bash
docker run -d \
  --name stunnel \
  -p 6697:6697 \
  -e STUNNEL_CONNECT=localhost:6667 \
  mbologna/docker-stunnel:latest
```

### Docker Compose

```bash
# Clone repository
git clone https://github.com/mbologna/docker-stunnel.git
cd docker-stunnel

# Configure environment
cp .env.example .env

# Start service
docker-compose up -d
```

### Kubernetes

```bash
# Deploy to cluster
kubectl apply -f k8s/

# Check status
kubectl get pods -n stunnel

# Access service
kubectl port-forward -n stunnel svc/stunnel 6697:6697
```

## Configuration

### Environment Variables

| Variable | Default | Description |
|----------|---------|-------------|
| `STUNNEL_SERVICE` | `stunnel` | Service name in configuration |
| `STUNNEL_CLIENT` | `no` | Client mode (yes/no) |
| `STUNNEL_ACCEPT` | `6697` | Port to accept connections on |
| `STUNNEL_CONNECT` | `localhost:6667` | Backend service to connect to |
| `TZ` | `UTC` | Timezone |

### Docker Compose

Create a `.env` file:

```env
STUNNEL_SERVICE=my-service
STUNNEL_ACCEPT=6697
STUNNEL_CONNECT=backend:6667
STUNNEL_CLIENT=no
STUNNEL_PORT=6697
TZ=UTC
```

### Kubernetes

Edit `k8s/configmap.yaml`:

```yaml
data:
  STUNNEL_SERVICE: "my-service"
  STUNNEL_ACCEPT: "6697"
  STUNNEL_CONNECT: "backend:6667"
  STUNNEL_CLIENT: "no"
  TZ: "America/New_York"
```

Then apply:
```bash
kubectl apply -f k8s/configmap.yaml
kubectl rollout restart -n stunnel deployment/stunnel
```

## Custom Certificate

### Docker Compose

```bash
# Mount your certificate
volumes:
  - ./my-cert.pem:/etc/stunnel/stunnel.pem:ro
```

### Kubernetes

```bash
# Create secret
kubectl create secret generic stunnel-cert \
  --from-file=stunnel.pem=/path/to/cert.pem \
  -n stunnel

# Add to deployment volumeMounts:
volumeMounts:
  - name: cert
    mountPath: /etc/stunnel/stunnel.pem
    subPath: stunnel.pem
    readOnly: true

# Add to volumes:
volumes:
  - name: cert
    secret:
      secretName: stunnel-cert
```

## Common Use Cases

### TLS Wrapper for IRC

```bash
docker run -d \
  --name irc-stunnel \
  -p 6697:6697 \
  -e STUNNEL_CONNECT=irc.server.com:6667 \
  mbologna/docker-stunnel:latest
```

### TLS Wrapper for Redis

```bash
docker run -d \
  --name redis-stunnel \
  -p 6380:6380 \
  -e STUNNEL_ACCEPT=6380 \
  -e STUNNEL_CONNECT=redis:6379 \
  mbologna/docker-stunnel:latest
```

### TLS Client Mode

```bash
docker run -d \
  --name stunnel-client \
  -p 6667:6667 \
  -e STUNNEL_CLIENT=yes \
  -e STUNNEL_ACCEPT=6667 \
  -e STUNNEL_CONNECT=remote.server.com:6697 \
  mbologna/docker-stunnel:latest
```

## Building Locally

```bash
docker build -t stunnel:custom .

# Multi-architecture build
docker buildx build \
  --platform linux/amd64,linux/arm64 \
  -t stunnel:custom .
```

## Kubernetes Advanced Configuration

### Exposing with NodePort

Edit `k8s/service.yaml`:

```yaml
spec:
  type: NodePort
  ports:
    - port: 6697
      targetPort: 6697
      nodePort: 30697
```

### Exposing with LoadBalancer

```yaml
spec:
  type: LoadBalancer
  ports:
    - port: 6697
      targetPort: 6697
```

### Resource Limits

Edit `k8s/deployment.yaml`:

```yaml
resources:
  limits:
    memory: 512Mi
    cpu: 1000m
  requests:
    memory: 128Mi
    cpu: 100m
```

## Security

- Runs as non-root user (UID/GID 1000)
- Read-only root filesystem
- All capabilities dropped
- Seccomp profile enabled
- Self-signed certificate included (replace for production)
- Regular vulnerability scanning via CI/CD
