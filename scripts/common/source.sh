#!/usr/bin/env bash
# =============================================================================
# Unified LLVM source acquisition via git clone.
#
# Usage:
#   VARIANT=main|p2996  source scripts/common/source.sh
#   obtain_llvm_source "/tmp/llvm-project"
#
# Requires: versions.sh to be sourced first.
# =============================================================================

obtain_llvm_source() {
    local dest_dir="$1"

    if [[ -d "${dest_dir}/llvm" ]]; then
        log "LLVM source already present at ${dest_dir}"
        return 0
    fi

    case "${VARIANT:-main}" in
        main)
            log "Cloning LLVM ${LLVM_VERSION} (tag: ${LLVM_GIT_TAG})..."
            git clone --depth 1 --branch "${LLVM_GIT_TAG}" \
                "${LLVM_REPO}" "${dest_dir}"
            ;;
        p2996)
            log "Cloning clang-p2996 (branch: ${P2996_BRANCH})..."
            git clone --depth 1 --branch "${P2996_BRANCH}" \
                "${P2996_REPO}" "${dest_dir}"
            ;;
        *)
            echo "ERROR: Unknown VARIANT '${VARIANT}'. Use 'main' or 'p2996'." >&2
            return 1
            ;;
    esac

    log "Source cloned to ${dest_dir}"
}
