#!/usr/bin/env bash
# Force ECS to deploy the current persistent agent :latest image.
# Run from repo root. Requires: aws cli, credentials for nonprod account.
set -euo pipefail

CLUSTER="jenkins-blue-green-nonprod-agents"
SERVICE="jenkins-blue-green-nonprod-persistent-agent"
REGION="us-east-2"

if ! command -v aws &>/dev/null; then
  echo "Error: aws CLI is required." >&2
  exit 1
fi

echo "Forcing new deployment of $SERVICE on cluster $CLUSTER..."
aws ecs update-service \
  --cluster "$CLUSTER" \
  --service "$SERVICE" \
  --force-new-deployment \
  --region "$REGION" \
  --output text

echo ""
echo "Deployment started. Check status:"
echo "  aws ecs describe-services --cluster $CLUSTER --services $SERVICE --region $REGION --query 'services[0].deployments'"
