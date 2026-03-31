#!/usr/bin/env bash
# Push existing jenkins-agent:latest to dev ECR. Build first: ./scripts/dev/build-and-push-agent.sh --build-only
# Run from repo root. Requires: docker, aws cli, credentials for dev account.
set -euo pipefail

REPO_URI="114039064573.dkr.ecr.us-east-2.amazonaws.com/jenkins-blue-green-dev-agent"
REGION="us-east-2"

if ! command -v docker &>/dev/null || ! command -v aws &>/dev/null; then
  echo "Error: docker and aws CLI are required." >&2
  exit 1
fi
if ! docker image inspect jenkins-agent:latest &>/dev/null; then
  echo "Error: Image jenkins-agent:latest not found. Build first: ./scripts/dev/build-and-push-agent.sh --build-only" >&2
  exit 1
fi

echo "Logging in to ECR..."
aws ecr get-login-password --region "$REGION" | docker login --username AWS --password-stdin "${REPO_URI%%/*}"

echo "Tagging jenkins-agent:latest -> $REPO_URI:latest"
docker tag jenkins-agent:latest "$REPO_URI:latest"

echo "Pushing..."
docker push "$REPO_URI:latest"

echo "Done. Image: $REPO_URI:latest"
