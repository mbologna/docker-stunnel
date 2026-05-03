#!/usr/bin/env bash
set -euo pipefail

IMAGE="${IMAGE_REF:-${DOCKER_USERNAME}/docker-stunnel:latest}"

docker pull "$IMAGE"

docker run -d --name stunnel-test \
  -e STUNNEL_CONNECT=localhost:6667 \
  "$IMAGE"

sleep 2
docker logs stunnel-test

for i in {1..30}; do
  STATUS=$(docker inspect --format="{{.State.Status}}" stunnel-test 2>/dev/null || echo "gone")
  if [ "$STATUS" = "gone" ]; then
    echo "Container disappeared!"
    exit 1
  fi
  HEALTH=$(docker inspect --format="{{.State.Health.Status}}" stunnel-test 2>/dev/null || echo "none")
  if [ "$HEALTH" = "healthy" ]; then
    echo "Container is healthy"
    break
  fi
  if [ "$STATUS" != "running" ]; then
    echo "Container is not running (status: $STATUS)"
    docker logs stunnel-test
    docker rm stunnel-test || true
    exit 1
  fi
  echo "Waiting... ($i/30) - Status: $STATUS, Health: $HEALTH"
  sleep 2
done

if [ "$HEALTH" != "healthy" ]; then
  echo "Container failed to become healthy"
  docker logs stunnel-test
  docker rm stunnel-test || true
  exit 1
fi

docker exec stunnel-test nc -zv localhost 6697 || exit 1
echo "TLS port 6697 OK"

docker stop stunnel-test && docker rm stunnel-test

