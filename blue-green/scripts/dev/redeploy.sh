#!/usr/bin/env bash
# Full dev redeploy: build, push, and activate both controller and persistent agent.
# Run from repo root. Requires: docker, aws cli, credentials for dev account (114039064573, us-east-2).
# On first run ensure: ECR repos exist (terraform apply), persistent agent secret in Secrets Manager.
set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

if ! command -v docker &>/dev/null; then
  echo "Error: docker is required. Install Docker and ensure your user can run 'docker'." >&2
  exit 1
fi
if ! command -v aws &>/dev/null; then
  echo "Error: aws CLI is required. Configure credentials for dev account." >&2
  exit 1
fi

cd "$REPO_ROOT"

echo "========== Controller: build, push, activate =========="
"$SCRIPT_DIR/build-and-push-controller.sh"
"$SCRIPT_DIR/activate-controller.sh"

echo ""
echo "========== Agent: build, push, activate =========="
"$SCRIPT_DIR/build-and-push-agent.sh"
"$SCRIPT_DIR/activate-persistent-agent.sh"

echo ""
echo "Redeploy complete. Controller and persistent agent are rolling out with :latest images."
echo "If controller uses blue/green (controller_blue_green = true), run a CodeDeploy deploy instead of activate:"
echo "  ./scripts/dev/deploy-controller-blue-green.sh"
echo "Check ECS: aws ecs describe-services --cluster jenkins-blue-green-dev-controller --services jenkins --region us-east-2"
