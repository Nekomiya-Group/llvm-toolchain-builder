#!/usr/bin/env bash
# =============================================================================
# LLVM CMake configuration — dispatcher.
#
# Sources the appropriate stage-specific config file and provides
# generate_cmake_args(). Split into separate files so that Stage 2
# changes don't invalidate Stage 1 cache.
#
# Files:
#   llvm-config-common.sh  — shared defaults (both stages)
#   llvm-config-stage1.sh  — Stage 1 only (cache-sensitive)
#   llvm-config-stage2.sh  — Stage 2 only (no Stage 1 cache impact)
#
# Usage:
#   source scripts/common/versions.sh
#   source scripts/common/llvm-config.sh   # auto-selects stage file
#   generate_cmake_args                    # populates CMAKE_ARGS array
# =============================================================================

: "${STAGE:=stage2}"

_LLVM_CONFIG_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

if [[ "${STAGE}" == "stage1" ]]; then
    source "${_LLVM_CONFIG_DIR}/llvm-config-stage1.sh"
else
    source "${_LLVM_CONFIG_DIR}/llvm-config-stage2.sh"
fi
