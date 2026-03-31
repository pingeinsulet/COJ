#!/usr/bin/env bash
# Build and push the Jenkins controller image for the given environment.
# Prerequisites: Terraform applied for that environment (so jenkins.yaml is generated and ECR repos exist).
# Optional: AZURE_AD_SECRET_NAME (e.g. azure-ad-secrets_nonprod) for AAD integration; if unset, build args are omitted.

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/common.sh"

ENV="$(check_env "${1:-}")"
require_cmds
check_aws_account "$ENV"
require_jq

echo "=== Jenkins controller build (environment: $ENV) ==="

CONTROLLER_REPO_URL="$(get_tf_output "$ENV" "controller_ecr_repository_url")"
CONTROLLER_REGISTRY="$(get_tf_output "$ENV" "controller_ecr_registry")"
AWS_REGION="$(get_tf_output "$ENV" "aws_region")"
JENKINS_CONFIG_PATH="$(get_tf_output "$ENV" "jenkins_config_path")"
PREFIX="$(get_tf_output "$ENV" "prefix")"

# Generated config is under build/<prefix>/jenkins.yaml; controller Dockerfile expects docker/jenkins_controller/jenkins.yaml
if [[ ! -f "$JENKINS_CONFIG_PATH" ]]; then
  echo "Generated Jenkins config not found at $JENKINS_CONFIG_PATH. Run Terraform apply first: cd $REPO_ROOT/environments/$ENV && terraform apply -var-file=${ENV}.tfvars" >&2
  exit 1
fi

mkdir -p "$REPO_ROOT/docker/jenkins_controller"
cp "$JENKINS_CONFIG_PATH" "$REPO_ROOT/docker/jenkins_controller/jenkins.yaml"
echo "Copied jenkins.yaml from $JENKINS_CONFIG_PATH into docker/jenkins_controller/"

ecr_login "$AWS_REGION" "$CONTROLLER_REGISTRY"

# Azure AD secret (optional): set AZURE_AD_SECRET_NAME to the Secrets Manager secret name for this env
SECRET_NAME="${AZURE_AD_SECRET_NAME:-azure-ad-secrets_$ENV}"
BUILD_ARGS=()
if aws secretsmanager describe-secret --secret-id "$SECRET_NAME" --region "$AWS_REGION" &>/dev/null; then
  echo "Using Azure AD secret: $SECRET_NAME"
  SECRET_JSON="$(aws secretsmanager get-secret-value --region "$AWS_REGION" --secret-id "$SECRET_NAME" | jq -r '.SecretString | fromjson')"
  BUILD_ARGS=(
    --build-arg "CLIENT_ID=$(echo "$SECRET_JSON" | jq -r '.CLIENT_ID')"
    --build-arg "CLIENT_SECRET=$(echo "$SECRET_JSON" | jq -r '.CLIENT_SECRET')"
    --build-arg "TENANT_ID=$(echo "$SECRET_JSON" | jq -r '.TENANT_ID')"
  )
else
  echo "No Azure AD secret found ($SECRET_NAME). Building without AAD build args."
fi

DOCKER_BUILDKIT=1 docker build -t "jenkins-controller:latest" \
  "${BUILD_ARGS[@]}" \
  --platform linux/amd64 \
  -f "$REPO_ROOT/docker/jenkins_controller/Dockerfile" \
  "$REPO_ROOT/docker/jenkins_controller"

docker tag "jenkins-controller:latest" "$CONTROLLER_REPO_URL:latest"
docker push "$CONTROLLER_REPO_URL:latest"

echo "Controller image pushed to $CONTROLLER_REPO_URL:latest"
