#!/bin/bash
set -e

DOCKER_USER="arumanoh"
ENV="${1:-dev}"          # dev or prod
TAG="${2:-latest}"

if [[ "$ENV" != "dev" && "$ENV" != "prod" ]]; then
  echo "Usage: ./build.sh [dev|prod] [tag]"
  exit 1
fi

IMAGE="$DOCKER_USER/$ENV:$TAG"

echo "Building image: $IMAGE"
docker build -t "$IMAGE" .
echo "Build complete: $IMAGE"
