#!/usr/bin/env bash
# Build and push persistent agent for prod. Wrapper around shared script (requires Terraform applied).
set -euo pipefail
REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
exec "$REPO_ROOT/scripts/build-persistent-agent.sh" prod
