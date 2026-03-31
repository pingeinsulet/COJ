#!/usr/bin/env bash
# Deploy the Jenkins controller to dev using CodeDeploy blue/green (zero overlap).
# Scale to 0, wait for tasks to stop, then deploy so only one controller uses EFS at a time.
# Prerequisites: controller image already built and pushed (e.g. ./scripts/dev/build-and-push-controller.sh).
# Requires: aws CLI; jq or Python 3 for task-definition cleanup.
set -euo pipefail

CLUSTER="jenkins-blue-green-dev-controller"
SERVICE="jenkins"
TASK_FAMILY="jenkins-blue-green-dev"
CODEDEPLOY_APP="jenkins-blue-green-dev-controller"
CODEDEPLOY_GROUP="jenkins-blue-green-dev-controller"
CONTAINER_NAME="jenkins-blue-green-dev"
CONTAINER_PORT="8080"
REGION="us-east-2"
REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
TMP_DIR=""
WAIT_TIMEOUT=600
WAIT_POLL=15

cleanup() {
  [[ -n "$TMP_DIR" && -d "$TMP_DIR" ]] && rm -rf "$TMP_DIR"
}
trap cleanup EXIT

if ! command -v aws &>/dev/null; then
  echo "Error: aws CLI is required." >&2
  exit 1
fi

get_running_count() {
  aws ecs describe-services --cluster "$CLUSTER" --services "$SERVICE" --region "$REGION" \
    --query 'services[0].runningCount' --output text
}

wait_for_count() {
  local target=$1
  local elapsed=0
  while [[ $elapsed -lt $WAIT_TIMEOUT ]]; do
    local count
    count="$(get_running_count)"
    if [[ "$count" == "$target" ]]; then
      return 0
    fi
    echo "  Running count: $count (target: $target). Waiting ${WAIT_POLL}s..."
    sleep "$WAIT_POLL"
    elapsed=$((elapsed + WAIT_POLL))
  done
  echo "Error: Timed out waiting for running count to reach $target." >&2
  return 1
}

echo "Step 1: Scaling service to 0 (no overlap with new tasks)..."
aws ecs update-service \
  --cluster "$CLUSTER" \
  --service "$SERVICE" \
  --desired-count 0 \
  --region "$REGION" \
  --query 'service.{desiredCount:desiredCount,runningCount:runningCount}' --output table >/dev/null

echo "Waiting for all tasks to stop (up to $((WAIT_TIMEOUT/60)) minutes)..."
wait_for_count 0

echo "Step 2: Setting desired count to 1..."
aws ecs update-service \
  --cluster "$CLUSTER" \
  --service "$SERVICE" \
  --desired-count 1 \
  --region "$REGION" \
  --query 'service.desiredCount' --output text >/dev/null

TMP_DIR="$(mktemp -d)"
TD_JSON="$TMP_DIR/task-def.json"
APPSPEC="$TMP_DIR/appspec.yaml"

echo "Step 3: Registering new task definition and starting deployment..."
aws ecs describe-task-definition --task-definition "$TASK_FAMILY" --region "$REGION" \
  --query 'taskDefinition' --output json > "$TD_JSON"

if command -v jq &>/dev/null; then
  jq 'del(.taskDefinitionArn, .revision, .status, .requiresAttributes, .compatibilities, .registeredAt, .registeredBy)' \
    "$TD_JSON" > "${TD_JSON}.clean"
else
  python3 -c "
import json,sys
d=json.load(open('$TD_JSON'))
for k in ['taskDefinitionArn','revision','status','requiresAttributes','compatibilities','registeredAt','registeredBy']:
  d.pop(k, None)
json.dump(d, sys.stdout, indent=2)
" > "${TD_JSON}.clean"
fi
mv "${TD_JSON}.clean" "$TD_JSON"

cat > "$APPSPEC" <<APPSPEC
version: 0.0
Resources:
  - TargetService:
      Type: AWS::ECS::Service
      Properties:
        TaskDefinition: "PLACEHOLDER"
        LoadBalancerInfo:
          ContainerName: "$CONTAINER_NAME"
          ContainerPort: $CONTAINER_PORT
APPSPEC

aws ecs deploy \
  --cluster "$CLUSTER" \
  --service "$SERVICE" \
  --task-definition "$TD_JSON" \
  --codedeploy-appspec "$APPSPEC" \
  --codedeploy-application "$CODEDEPLOY_APP" \
  --codedeploy-deployment-group "$CODEDEPLOY_GROUP" \
  --region "$REGION"

echo "Blue/green deployment completed (zero overlap; only one controller used EFS at a time)."
