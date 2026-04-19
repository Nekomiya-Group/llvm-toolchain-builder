#!/usr/bin/env bash
# =============================================================================
# Portability verification script for Linux AArch64 toolchain.
# Reuses the same logic as the x86_64 version.
#
# Usage: TOOLCHAIN_DIR=/opt/coca-toolchain ./scripts/linux-arm64/verify-portability.sh
# =============================================================================
set -euo pipefail

# Delegate to the shared verification script
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
exec "${SCRIPT_DIR}/../ubuntu-16.04/verify-portability.sh" "$@"
