#!/usr/bin/env bash
# Wait for the Jenkins ECS service to finish draining (after a force delete or replace),
# then run terraform apply to create the new blue/green controller service.
# Run from repo root. Requires: aws CLI, terraform. Uses environments/dev and dev.tfvars.
set -euo pipefail

CLUSTER="jenkins-blue-green-dev-controller"
SERVICE="jenkins"
REGION="us-east-2"
REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
MAX_ATTEMPTS=20
SLEEP_SEC=30

if ! command -v aws &>/dev/null; then
  echo "Error: aws CLI is required." >&2
  exit 1
fi

echo "Waiting for service '$SERVICE' on cluster '$CLUSTER' to finish draining..."
for i in $(seq 1 "$MAX_ATTEMPTS"); do
  STATUS="$(aws ecs describe-services --cluster "$CLUSTER" --services "$SERVICE" --region "$REGION" --query 'services[0].status' --output text 2>/dev/null || true)"
  if [[ -z "$STATUS" || "$STATUS" == "None" ]]; then
    echo "Service is gone or not found. Proceeding with terraform apply."
    break
  fi
  if [[ "$STATUS" != "DRAINING" ]]; then
    echo "Service status is '$STATUS' (not DRAINING). Proceeding with terraform apply."
    break
  fi
  if [[ $i -eq $MAX_ATTEMPTS ]]; then
    echo "Timeout: service still DRAINING after $((MAX_ATTEMPTS * SLEEP_SEC))s. Run 'terraform apply' manually later." >&2
    exit 1
  fi
  echo "  Attempt $i/$MAX_ATTEMPTS: status=$STATUS. Waiting ${SLEEP_SEC}s..."
  sleep "$SLEEP_SEC"
done

echo ""
echo "Running terraform apply in environments/dev..."
cd "$REPO_ROOT/environments/dev"
terraform apply -var-file=dev.tfvars -auto-approve

echo ""
echo "Done. Next: build and push images, then deploy controller (blue/green) and activate agent:"
echo "  ./scripts/dev/build-and-push-controller.sh"
echo "  ./scripts/dev/build-and-push-agent.sh"
echo "  ./scripts/dev/deploy-controller-blue-green.sh"
echo "  ./scripts/dev/activate-persistent-agent.sh"
