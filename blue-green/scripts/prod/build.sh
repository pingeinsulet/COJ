#!/usr/bin/env bash
# Build and push controller + agent images for prod.
# Run from repo root. Prerequisites: Terraform applied for prod, Docker, AWS CLI.
set -euo pipefail
REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
cd "$REPO_ROOT"
echo "=== Prod: build controller ==="
./scripts/build-controller.sh prod
echo "=== Prod: build agent ==="
./scripts/build-persistent-agent.sh prod
echo "Prod build done. Run ./scripts/prod/deploy.sh to deploy."
