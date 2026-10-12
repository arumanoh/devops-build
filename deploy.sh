#!/bin/bash
set -e

DOCKER_USER="arumanoh"
ENV="${1:-dev}"          # dev or prod
TAG="${2:-latest}"

if [[ "$ENV" != "dev" && "$ENV" != "prod" ]]; then
  echo "Usage: ./deploy.sh [dev|prod] [tag]"
  exit 1
fi

export IMAGE_NAME="$DOCKER_USER/$ENV"
export IMAGE_TAG="$TAG"

echo "Deploying $IMAGE_NAME:$IMAGE_TAG"
docker compose pull
docker compose up -d --no-build
docker image prune -f
echo "Deployment complete"
