#!/bin/bash
# Development Environment Setup Script for Codex
# This script delegates to scripts/env-setup.sh with Codex-friendly defaults.

set -e

REPO_ROOT=$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)

INSTALL_PREFIX="${HOME}/.local/bin"
ENV_FILE="${CODEX_ENV_FILE:-}"
STRICT_MODE="false"

export INSTALL_PREFIX
export ENV_FILE
export STRICT_MODE

bash "$REPO_ROOT/scripts/env-setup.sh"
