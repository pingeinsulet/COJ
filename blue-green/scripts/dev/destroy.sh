#!/usr/bin/env bash
# Destroy dev stack while preserving EFS and ECR (and images).
# Run from repo root. To bring back: run the import + apply commands the script prints.
set -euo pipefail
REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
cd "$REPO_ROOT"
exec ./scripts/destroy-preserve-efs-ecr.sh dev
