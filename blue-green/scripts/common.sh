#!/usr/bin/env bash
# Shared helpers for Jenkins build scripts. Source from script: source "$(dirname "$0")/common.sh"

set -euo pipefail

REPO_ROOT="${REPO_ROOT:-$(cd "$(dirname "$0")/.." && pwd)}"
VALID_ENVS="dev nonprod prod"

usage_env() {
  echo "Usage: $0 <environment>" >&2
  echo "  environment: one of $VALID_ENVS" >&2
  echo "  Run from repo root or set REPO_ROOT." >&2
  exit 1
}

check_env() {
  local env="${1:-}"
  if [[ -z "$env" ]]; then
    usage_env
  fi
  if [[ " $VALID_ENVS " != *" $env "* ]]; then
    echo "Invalid environment: $env. Must be one of: $VALID_ENVS" >&2
    exit 1
  fi
  echo "$env"
}

# If EXPECTED_AWS_ACCOUNT_ID is set (or file environments/<env>/.expected_aws_account_id exists),
# verify current AWS account matches; exit 1 otherwise so we don't build in the wrong account.
check_aws_account() {
  local env="$1"
  local expected=""
  if [[ -n "${EXPECTED_AWS_ACCOUNT_ID:-}" ]]; then
    expected="$EXPECTED_AWS_ACCOUNT_ID"
  elif [[ -f "$REPO_ROOT/environments/$env/.expected_aws_account_id" ]]; then
    expected="$(cat "$REPO_ROOT/environments/$env/.expected_aws_account_id" | tr -d '[:space:]')"
  fi
  if [[ -z "$expected" ]]; then
    return 0
  fi
  local current
  current="$(aws sts get-caller-identity --query Account --output text 2>/dev/null)" || {
    echo "Could not get current AWS account (aws sts get-caller-identity failed)." >&2
    return 1
  }
  if [[ "$current" != "$expected" ]]; then
    echo "Wrong AWS account: current account is $current but expected $expected (environment: $env). Aborting to avoid building in the wrong account." >&2
    echo "Set EXPECTED_AWS_ACCOUNT_ID or create environments/$env/.expected_aws_account_id to enforce, or unset to skip this check." >&2
    return 1
  fi
  echo "AWS account check passed: $current (expected $expected for $env)."
  return 0
}

# Get Terraform outputs from an environment directory. Requires terraform init and apply to have been run.
get_tf_output() {
  local env="$1"
  local output_name="$2"
  local out
  out=$(cd "$REPO_ROOT/environments/$env" && terraform output -raw "$output_name" 2>&1) || {
    echo "Could not get Terraform output '$output_name' for environment '$env'. Run: cd $REPO_ROOT/environments/$env && terraform init && terraform apply -var-file=${env}.tfvars" >&2
    echo "$out" >&2
    return 1
  }
  echo "$out"
}

get_tf_outputs() {
  local env="$1"
  if ! (cd "$REPO_ROOT/environments/$env" && terraform output -json >/dev/null 2>&1); then
    echo "Terraform outputs not available. Run from repo root: cd environments/$env && terraform init && terraform apply -var-file=${env}.tfvars" >&2
    return 1
  fi
  cd "$REPO_ROOT/environments/$env" && terraform output -json
}

ecr_login() {
  local region="$1"
  local registry="$2"
  aws ecr get-login-password --region "$region" | docker login --username AWS --password-stdin "$registry"
}

require_cmds() {
  for cmd in aws docker terraform; do
    if ! command -v "$cmd" &>/dev/null; then
      echo "Required command not found: $cmd. Install AWS CLI, Docker, and Terraform." >&2
      exit 1
    fi
  done
}

# Optional: require jq (needed for controller build when using Azure AD secret)
require_jq() {
  if ! command -v jq &>/dev/null; then
    echo "jq is required for this script. Install jq (e.g. apt-get install jq)." >&2
    exit 1
  fi
}
