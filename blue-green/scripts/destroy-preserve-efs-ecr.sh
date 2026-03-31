#!/usr/bin/env bash
# Destroy a Jenkins environment while preserving EFS (job files, workspaces) and ECR repos (images).
#
# SAFETY — EFS: We NEVER delete or overwrite the EFS file system. This script removes EFS
# from Terraform state before destroy so Terraform never attempts deletion. A pre-destroy
# plan check aborts if any EFS resource would be destroyed. No code in this repo may call
# "aws efs delete-file-system" or wipe EFS contents.
#
# Usage: ./scripts/destroy-preserve-efs-ecr.sh <dev|nonprod|prod>
# Run from repo root. Requires: terraform, aws CLI, credentials for the environment.
set -euo pipefail

REPO_ROOT="${REPO_ROOT:-$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)}"
VALID_ENVS="dev nonprod prod"
ENV="${1:-}"

if [[ -z "$ENV" ]] || [[ " $VALID_ENVS " != *" $ENV "* ]]; then
  echo "Usage: $0 <environment>" >&2
  echo "  environment: one of $VALID_ENVS" >&2
  exit 1
fi

ENV_DIR="$REPO_ROOT/environments/$ENV"
TFVARS="$ENV.tfvars"
SUBNETS='["subnet-06e158d9e205a9588","subnet-04e35976121efcd63","subnet-06ea6dd1d4590f251"]'

if [[ ! -f "$ENV_DIR/$TFVARS" ]]; then
  echo "Error: $ENV_DIR/$TFVARS not found." >&2
  exit 1
fi

REGION="us-east-2"
CONTROLLER_CLUSTER="jenkins-blue-green-${ENV}-controller"
CONTROLLER_SERVICE="jenkins"
AGENT_CLUSTER="jenkins-blue-green-${ENV}-agents"
AGENT_SERVICE="jenkins-blue-green-${ENV}-persistent-agent"
WAIT_TIMEOUT=600
WAIT_POLL=15
ENI_WAIT=90

get_running() {
  aws ecs describe-services --cluster "$1" --services "$2" --region "$REGION" \
    --query 'services[0].runningCount' --output text 2>/dev/null || echo "0"
}

wait_for_zero() {
  local cluster=$1
  local service=$2
  local elapsed=0
  while [[ $elapsed -lt $WAIT_TIMEOUT ]]; do
    local count
    count="$(get_running "$cluster" "$service")"
    if [[ "${count:-0}" == "0" ]]; then
      return 0
    fi
    echo "  $cluster / $service running: $count. Waiting ${WAIT_POLL}s..."
    sleep "$WAIT_POLL"
    elapsed=$((elapsed + WAIT_POLL))
  done
  echo "Warning: Timed out waiting for $service to reach 0; continuing anyway." >&2
  return 0
}

echo "=== Destroy $ENV (preserving EFS and ECR) ==="
echo "Step 0: Scaling ECS services to 0 so security groups can be deleted..."
aws ecs update-service --cluster "$CONTROLLER_CLUSTER" --service "$CONTROLLER_SERVICE" \
  --desired-count 0 --region "$REGION" --output text >/dev/null 2>/dev/null || true
aws ecs update-service --cluster "$AGENT_CLUSTER" --service "$AGENT_SERVICE" \
  --desired-count 0 --region "$REGION" --output text >/dev/null 2>/dev/null || true
echo "Waiting for controller and agent tasks to stop (up to $((WAIT_TIMEOUT/60)) min)..."
wait_for_zero "$CONTROLLER_CLUSTER" "$CONTROLLER_SERVICE"
wait_for_zero "$AGENT_CLUSTER" "$AGENT_SERVICE"
echo "Waiting ${ENI_WAIT}s for AWS to release network interfaces..."
sleep "$ENI_WAIT"

echo "Step 1: Removing EFS and ECR from state so destroy can run..."
cd "$ENV_DIR"

# Remove protected resources from state (they stay in AWS). EFS is never deleted.
terraform state rm \
  'module.jenkins.aws_ecr_repository.jenkins_nonprod_controller_repo' \
  'module.jenkins.aws_ecr_repository.jenkins_nonprod_agent_repo' \
  'module.jenkins.aws_efs_file_system.nonprod_efs' \
  'module.jenkins.aws_efs_access_point.nonprod_efs_ap' \
  'module.jenkins.aws_efs_mount_target.nonprod_storage["subnet-06e158d9e205a9588"]' \
  'module.jenkins.aws_efs_mount_target.nonprod_storage["subnet-04e35976121efcd63"]' \
  'module.jenkins.aws_efs_mount_target.nonprod_storage["subnet-06ea6dd1d4590f251"]' \
  'module.jenkins.aws_security_group.jenkins_nonprod_efs' \
  2>/dev/null || true

echo "Step 2: Verifying no EFS resource would be destroyed..."
PLAN_OUTPUT="$(terraform plan -destroy -var-file="$TFVARS" -no-color -input=false 2>&1)" || true
if echo "$PLAN_OUTPUT" | grep -qE 'module\.jenkins\.(aws_efs_file_system|aws_efs_mount_target|aws_efs_access_point)'; then
  echo "SAFETY: EFS resources are still in the destroy plan. EFS must never be deleted." >&2
  echo "Refusing to run destroy. Ensure state rm above succeeded and re-run this script." >&2
  exit 1
fi

echo "Step 3: Running terraform destroy (EFS and ECR are not in state; they will not be touched)..."
terraform destroy -var-file="$TFVARS" -auto-approve

echo ""
echo "Done. EFS and ECR repos (with images) are unchanged in AWS."
echo "To bring the stack back: run the imports below, then 'terraform apply -var-file=$TFVARS'."
echo ""
echo "  # Get EFS ID (replace if your prefix differs):"
echo "  EFS_ID=\$(aws efs describe-file-systems --region us-east-2 --query \"FileSystems[?Name=='jenkins-blue-green-${ENV}-efs'].FileSystemId\" --output text)"
echo "  cd $ENV_DIR"
echo "  terraform import -var-file=$TFVARS module.jenkins.aws_efs_file_system.nonprod_efs \$EFS_ID"
echo "  terraform import -var-file=$TFVARS module.jenkins.aws_efs_access_point.nonprod_efs_ap \$(aws efs describe-access-points --file-system-id \$EFS_ID --region us-east-2 --query 'AccessPoints[0].AccessPointId' --output text)"
echo "  # Mount targets (one per subnet):"
echo "  for sid in subnet-06e158d9e205a9588 subnet-04e35976121efcd63 subnet-06ea6dd1d4590f251; do"
echo "    MT_ID=\$(aws efs describe-mount-targets --file-system-id \$EFS_ID --region us-east-2 --query \"MountTargets[?SubnetId=='\$sid'].MountTargetId\" --output text)"
echo "    terraform import -var-file=$TFVARS 'module.jenkins.aws_efs_mount_target.nonprod_storage[\"'\$sid'\"]' \$MT_ID"
echo "  done"
echo "  terraform import -var-file=$TFVARS module.jenkins.aws_security_group.jenkins_nonprod_efs \$(aws ec2 describe-security-groups --filters \"Name=group-name,Values=jenkins-blue-green-${ENV}-efs-sg\" --query 'SecurityGroups[0].GroupId' --output text --region us-east-2)"
echo "  terraform import -var-file=$TFVARS module.jenkins.aws_ecr_repository.jenkins_nonprod_controller_repo jenkins-blue-green-${ENV}-controller"
echo "  terraform import -var-file=$TFVARS module.jenkins.aws_ecr_repository.jenkins_nonprod_agent_repo jenkins-blue-green-${ENV}-agent"
echo "  terraform apply -var-file=$TFVARS -auto-approve"
