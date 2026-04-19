#!/usr/bin/env bash
# =============================================================================
# LLVM Stage 1 Build — minimal clang + lld for bootstrapping Stage 2
# Platform: Linux x86_64 (Ubuntu 16.04)
#
# Usage: BOOTSTRAP_PREFIX=/opt/bootstrap STAGE1_PREFIX=/opt/stage1 \
#        ./scripts/linux-x64/build-llvm-stage1.sh
# =============================================================================
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
COMMON_DIR="${SCRIPT_DIR}/../common"

: "${BOOTSTRAP_PREFIX:=/opt/bootstrap}"
: "${STAGE1_PREFIX:=/opt/stage1}"
: "${LLVM_SRC:=/tmp/llvm-project}"
: "${STAGE1_BUILD:=/tmp/stage1-build}"
: "${NPROC:=$(nproc)}"
: "${VARIANT:=main}"

export PLATFORM="linux-x64"
export STAGE="stage1"
export INSTALL_PREFIX="${STAGE1_PREFIX}"
export SOURCE_DIR="${LLVM_SRC}"
export BUILD_DIR="${STAGE1_BUILD}"

export PATH="${BOOTSTRAP_PREFIX}/bin:${PATH}"
export LD_LIBRARY_PATH="${BOOTSTRAP_PREFIX}/lib64:${BOOTSTRAP_PREFIX}/lib:${LD_LIBRARY_PATH:-}"

source "${COMMON_DIR}/versions.sh"
source "${COMMON_DIR}/source.sh"
source "${COMMON_DIR}/llvm-config.sh"

log() { echo "===> $(date '+%H:%M:%S') $*"; }

main() {
    log "LLVM Stage 1 build starting (${PLATFORM})"
    log "  BOOTSTRAP_PREFIX: ${BOOTSTRAP_PREFIX}"
    log "  STAGE1_PREFIX:    ${STAGE1_PREFIX}"
    log "  LLVM_VERSION:     ${LLVM_VERSION}"
    log "  NPROC:            ${NPROC}"

    obtain_llvm_source "${LLVM_SRC}"
    SOURCE_DIR="${LLVM_SRC}"

    mkdir -p "${STAGE1_BUILD}"

    generate_cmake_args

    log "Configuring LLVM Stage 1..."
    cmake -G Ninja -S "${SOURCE_DIR}/llvm" -B "${STAGE1_BUILD}" "${CMAKE_ARGS[@]}"

    log "Building LLVM Stage 1..."
    cmake --build "${STAGE1_BUILD}" -j"${NPROC}"

    log "Installing LLVM Stage 1..."
    cmake --install "${STAGE1_BUILD}"

    log "Stage 1 installed to ${STAGE1_PREFIX}"
    "${STAGE1_PREFIX}/bin/clang" --version
    "${STAGE1_PREFIX}/bin/ld.lld" --version

    log "Stage 1 build complete!"
}

main "$@"
