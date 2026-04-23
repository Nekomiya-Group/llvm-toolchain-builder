#!/usr/bin/env bash
# =============================================================================
# Linux portability verification entry point.
# Works on any Linux architecture (x86_64, aarch64) and any distro version.
#
# Usage: TOOLCHAIN_DIR=/opt/coca-toolchain ./scripts/linux/verify-portability.sh
# =============================================================================
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
COMMON_DIR="${SCRIPT_DIR}/../common"

: "${TOOLCHAIN_DIR:=/opt/coca-toolchain}"
export TOOLCHAIN_DIR

source "${COMMON_DIR}/verify-lib.sh"
source "${COMMON_DIR}/verify-toolchain.sh"
source "${COMMON_DIR}/verify-third-party.sh"

main() {
    log "Portability verification on $(cat /etc/os-release 2>/dev/null | grep PRETTY_NAME | cut -d= -f2 | tr -d '"' || echo 'unknown')"
    log "Arch: $(uname -m)"
    log "glibc: $(ldd --version 2>&1 | head -1 || echo 'unknown')"
    log "Toolchain: ${TOOLCHAIN_DIR}"

    install_test_deps

    local tmpdir
    tmpdir=$(mktemp -d)

    test_binary_execution
    test_basic_compilation "${tmpdir}"
    test_sanitizers "${tmpdir}"
    test_openmp "${tmpdir}"
    test_profiling "${tmpdir}"
    test_cross_compilation "${tmpdir}"
    test_fortran "${tmpdir}"
    test_clang_tidy "${tmpdir}"
    test_third_party_libs "${tmpdir}"
    test_dependencies

    rm -rf "${tmpdir}"

    verify_summary
}

main "$@"
