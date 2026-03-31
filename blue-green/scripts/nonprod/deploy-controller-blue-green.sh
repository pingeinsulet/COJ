#!/usr/bin/env bash
# Deploy the Jenkins controller with zero overlap: scale to 0, wait for tasks to stop, then deploy.
# Only one controller process uses EFS at a time. Run from repo root.
set -euo pipefail

CLUSTER="jenkins-blue-green-nonprod-controller"
SERVICE="jenkins"
REGION="us-east-2"
WAIT_TIMEOUT=600
WAIT_POLL=15

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

echo "Step 1: Scaling controller to 0 (no overlap)..."
aws ecs update-service \
  --cluster "$CLUSTER" \
  --service "$SERVICE" \
  --desired-count 0 \
  --region "$REGION" \
  --query 'service.{desiredCount:desiredCount,runningCount:runningCount}' --output table >/dev/null

echo "Waiting for all controller tasks to stop (up to $((WAIT_TIMEOUT/60)) minutes)..."
wait_for_count 0

echo "Step 2: Deploying new controller (desired 1, force new deployment)..."
aws ecs update-service \
  --cluster "$CLUSTER" \
  --service "$SERVICE" \
  --desired-count 1 \
  --force-new-deployment \
  --region "$REGION" \
  --output text >/dev/null

echo "Blue/green deployment (zero overlap) completed for nonprod controller."
