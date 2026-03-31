#!/usr/bin/env bash
# Build and push the Jenkins ECS agent image for the given environment.
# This is the same image used by the ECS cloud to launch ephemeral agents (and by the persistent agent).

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/common.sh"

ENV="$(check_env "${1:-}")"
require_cmds
check_aws_account "$ENV"

echo "=== Jenkins ECS agents build (environment: $ENV) ==="

AGENT_REPO_URL="$(get_tf_output "$ENV" "agent_ecr_repository_url")"
AGENT_REGISTRY="$(get_tf_output "$ENV" "agent_ecr_registry")"
AWS_REGION="$(get_tf_output "$ENV" "aws_region")"

ecr_login "$AWS_REGION" "$AGENT_REGISTRY"

DOCKER_BUILDKIT=1 docker build -t "jenkins-agent:latest" \
  --platform linux/amd64 \
  -f "$REPO_ROOT/docker/jenkins_agent/Dockerfile" \
  "$REPO_ROOT/docker/jenkins_agent"

docker tag "jenkins-agent:latest" "$AGENT_REPO_URL:latest"
docker push "$AGENT_REPO_URL:latest"

echo "ECS agent image pushed to $AGENT_REPO_URL:latest"
