#!/usr/bin/env bash
# Build and push controller + agent images for dev.
# Run from repo root. Prerequisites: Terraform applied for dev, Docker, AWS CLI.
set -euo pipefail
REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
cd "$REPO_ROOT"
echo "=== Dev: build controller ==="
./scripts/dev/build-and-push-controller.sh
echo "=== Dev: build agent ==="
./scripts/dev/build-and-push-agent.sh
echo "Dev build done. Run ./scripts/dev/deploy.sh to deploy."
