#!/usr/bin/env bash
# Deploy controller and persistent agent for dev.
# Controller uses blue/green (CodeDeploy): traffic switches automatically when new tasks are healthy.
# Run from repo root. Prerequisites: images already built and pushed (./scripts/dev/build.sh).
set -euo pipefail
REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
cd "$REPO_ROOT"
echo "=== Dev: deploy controller (blue/green; switch is automatic when healthy) ==="
./scripts/dev/deploy-controller-blue-green.sh
echo "=== Dev: deploy persistent agent ==="
./scripts/dev/activate-persistent-agent.sh
echo "Dev deploy done."
