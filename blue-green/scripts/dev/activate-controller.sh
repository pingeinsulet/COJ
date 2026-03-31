#!/usr/bin/env bash
# Force ECS to deploy the current controller :latest image (after you've pushed it).
# Run from repo root. Requires: aws cli, credentials for dev account.
set -euo pipefail

CLUSTER="jenkins-blue-green-dev-controller"
SERVICE="jenkins"
REGION="us-east-2"

if ! command -v aws &>/dev/null; then
  echo "Error: aws CLI is required." >&2
  exit 1
fi

echo "Forcing new deployment of $SERVICE on cluster $CLUSTER (will pull current :latest image)..."
aws ecs update-service \
  --cluster "$CLUSTER" \
  --service "$SERVICE" \
  --force-new-deployment \
  --region "$REGION" \
  --output text

echo ""
echo "Deployment started. ECS will start new tasks with the current :latest image. Check status:"
echo "  aws ecs describe-services --cluster $CLUSTER --services $SERVICE --region $REGION --query 'services[0].deployments'"
