#!/usr/bin/env bash
# Pin the expected AWS account for an environment from your *current* credentials.
# Run this once with the correct profile/key (e.g. the account you want to allow).
# The account ID is written to environments/<env>/.expected_aws_account_id (gitignored).
# Terraform and build scripts will then refuse to run if the current account doesn't match.
# Nothing is hardcoded in the repo.

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/common.sh"

ENV="$(check_env "${1:-}")"

if ! command -v aws &>/dev/null; then
  echo "AWS CLI required." >&2
  exit 1
fi

account="$(aws sts get-caller-identity --query Account --output text 2>/dev/null)" || {
  echo "Could not get current AWS account. Check your credentials (e.g. AWS_PROFILE, env vars)." >&2
  exit 1
}

file="$REPO_ROOT/environments/$ENV/.expected_aws_account_id"
echo "$account" > "$file"
echo "Pinned expected AWS account for $ENV: $account"
echo "Written to $file (gitignored). Terraform and build scripts will only run when the current account is $account."
echo "To change it, run this script again with the desired credentials, or delete the file to skip the check."
