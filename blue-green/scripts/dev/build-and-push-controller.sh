#!/usr/bin/env bash
# Build dev Jenkins controller image; optionally push to ECR (account 114039064573, us-east-2).
# Usage: ./scripts/dev/build-and-push-controller.sh [--build-only]
# Run from repo root. Requires: docker; for push: aws cli, credentials for dev account.
set -euo pipefail

REPO_URI="114039064573.dkr.ecr.us-east-2.amazonaws.com/jenkins-blue-green-dev-controller"
REGION="us-east-2"
REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
BUILD_ONLY=false
[[ "${1:-}" == "--build-only" ]] && BUILD_ONLY=true

# Prerequisites
if ! command -v docker &>/dev/null; then
  echo "Error: docker is required. Install Docker and ensure your user can run 'docker' (e.g. add to docker group)." >&2
  exit 1
fi
if [[ "$BUILD_ONLY" != true ]] && ! command -v aws &>/dev/null; then
  echo "Error: aws CLI is required to push. Install AWS CLI and configure credentials for dev account." >&2
  exit 1
fi
if [[ ! -f "$REPO_ROOT/docker/jenkins_controller/Dockerfile" ]]; then
  echo "Error: docker/jenkins_controller/Dockerfile not found. Run from repo root." >&2
  exit 1
fi

# Use Terraform-generated jenkins.yaml (with WEBSERVER etc.) if present (run terraform apply in dev first)
GENERATED_YAML="$REPO_ROOT/docker/jenkins_controller/jenkins_jenkins_blue_green_dev.yaml"
if [[ -f "$GENERATED_YAML" ]]; then
  cp "$GENERATED_YAML" "$REPO_ROOT/docker/jenkins_controller/jenkins.yaml"
  echo "Using generated config: jenkins_jenkins_blue_green_dev.yaml -> jenkins.yaml"
fi

echo "Building controller image..."
DOCKER_BUILDKIT=1 docker build -t jenkins-controller:latest --platform linux/amd64 \
  -f "$REPO_ROOT/docker/jenkins_controller/Dockerfile" \
  "$REPO_ROOT/docker/jenkins_controller"

if [[ "$BUILD_ONLY" == true ]]; then
  echo "Build complete (no push). Image: jenkins-controller:latest"
  exit 0
fi

echo "Logging in to ECR..."
aws ecr get-login-password --region "$REGION" | docker login --username AWS --password-stdin "${REPO_URI%%/*}"

echo "Tagging and pushing..."
docker tag jenkins-controller:latest "$REPO_URI:latest"
docker push "$REPO_URI:latest"

echo "Done. Image URI: $REPO_URI:latest"
