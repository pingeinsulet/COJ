#!/usr/bin/env bash
# Deploy controller and persistent agent for nonprod (ECS rolling update).
# Run from repo root. Prerequisites: images already built and pushed (./scripts/nonprod/build.sh).
set -euo pipefail
REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
cd "$REPO_ROOT"
echo "=== Nonprod: deploy controller ==="
./scripts/nonprod/activate-controller.sh
echo "=== Nonprod: deploy persistent agent ==="
./scripts/nonprod/activate-persistent-agent.sh
echo "Nonprod deploy done."
