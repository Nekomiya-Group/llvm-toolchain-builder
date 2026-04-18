#!/usr/bin/env bash
# =============================================================================
# LLVM Stage 1 Build — minimal clang + lld for bootstrapping Stage 2
# Runs on Ubuntu 16.04 with bootstrap GCC 14.2 + CMake + Ninja
#
# Usage: BOOTSTRAP_PREFIX=/opt/bootstrap STAGE1_PREFIX=/opt/stage1 \
#        LLVM_VERSION=21.1.1 ./scripts/build-llvm-stage1.sh
# =============================================================================
set -euo pipefail

: "${BOOTSTRAP_PREFIX:=/opt/bootstrap}"
: "${STAGE1_PREFIX:=/opt/stage1}"
: "${LLVM_VERSION:=21.1.1}"
: "${LLVM_SRC:=/tmp/llvm-project}"
: "${STAGE1_BUILD:=/tmp/stage1-build}"
: "${NPROC:=$(nproc)}"

export PATH="${BOOTSTRAP_PREFIX}/bin:${PATH}"
export LD_LIBRARY_PATH="${BOOTSTRAP_PREFIX}/lib64:${BOOTSTRAP_PREFIX}/lib:${LD_LIBRARY_PATH:-}"

log() { echo "===> $(date '+%H:%M:%S') $*"; }

# -----------------------------------------------------------------------------
# 1. Clone / download LLVM source
# -----------------------------------------------------------------------------
download_llvm_source() {
    if [[ -d "${LLVM_SRC}/llvm" ]]; then
        log "LLVM source already exists at ${LLVM_SRC}"
        return
    fi

    log "Downloading LLVM ${LLVM_VERSION} source..."
    local tarball="/tmp/llvm-project-${LLVM_VERSION}.src.tar.xz"

    if [[ ! -f "${tarball}" ]]; then
        curl -fSL --retry 3 -o "${tarball}" \
            "https://github.com/llvm/llvm-project/releases/download/llvmorg-${LLVM_VERSION}/llvm-project-${LLVM_VERSION}.src.tar.xz"
    fi

    mkdir -p "${LLVM_SRC}"
    tar xf "${tarball}" --strip-components=1 -C "${LLVM_SRC}"
    log "LLVM source extracted to ${LLVM_SRC}"
}

# -----------------------------------------------------------------------------
# 2. Build Stage 1 — minimal Clang + LLD (Release, no assertions)
# -----------------------------------------------------------------------------
build_stage1() {
    log "Configuring LLVM Stage 1..."

    mkdir -p "${STAGE1_BUILD}"

    cmake -G Ninja -S "${LLVM_SRC}/llvm" -B "${STAGE1_BUILD}" \
        -DCMAKE_BUILD_TYPE=Release \
        -DCMAKE_INSTALL_PREFIX="${STAGE1_PREFIX}" \
        -DCMAKE_C_COMPILER="${BOOTSTRAP_PREFIX}/bin/gcc" \
        -DCMAKE_CXX_COMPILER="${BOOTSTRAP_PREFIX}/bin/g++" \
        -DCMAKE_CXX_FLAGS="-w" \
        -DCMAKE_EXE_LINKER_FLAGS="-Wl,-rpath,${BOOTSTRAP_PREFIX}/lib64" \
        -DCMAKE_SHARED_LINKER_FLAGS="-Wl,-rpath,${BOOTSTRAP_PREFIX}/lib64" \
        -DLLVM_ENABLE_PROJECTS="clang;lld" \
        -DLLVM_ENABLE_RUNTIMES="compiler-rt;libunwind;libcxxabi;libcxx" \
        -DLLVM_TARGETS_TO_BUILD="X86" \
        -DLLVM_BUILD_LLVM_DYLIB=ON \
        -DLLVM_LINK_LLVM_DYLIB=ON \
        -DLLVM_ENABLE_ASSERTIONS=OFF \
        -DLLVM_INCLUDE_TESTS=OFF \
        -DLLVM_INCLUDE_BENCHMARKS=OFF \
        -DLLVM_INCLUDE_EXAMPLES=OFF \
        -DLLVM_INCLUDE_DOCS=OFF \
        -DLLVM_ENABLE_TERMINFO=ON \
        -DLLVM_ENABLE_ZLIB=ON \
        -DLLVM_ENABLE_ZSTD=ON \
        -DLLVM_ENABLE_LIBXML2=OFF \
        -DCLANG_DEFAULT_RTLIB=compiler-rt \
        -DCLANG_DEFAULT_UNWINDLIB=libunwind \
        -DCLANG_DEFAULT_CXX_STDLIB=libc++ \
        -DCLANG_DEFAULT_LINKER=lld \
        -DCOMPILER_RT_BUILD_SANITIZERS=OFF \
        -DCOMPILER_RT_BUILD_XRAY=OFF \
        -DCOMPILER_RT_BUILD_LIBFUZZER=OFF \
        -DCOMPILER_RT_BUILD_PROFILE=OFF \
        -DCOMPILER_RT_BUILD_MEMPROF=OFF \
        -DCOMPILER_RT_BUILD_ORC=OFF

    log "Building LLVM Stage 1 (clang + lld + runtimes)..."
    cmake --build "${STAGE1_BUILD}" -j"${NPROC}"

    log "Installing LLVM Stage 1..."
    cmake --install "${STAGE1_BUILD}"

    log "Stage 1 installed to ${STAGE1_PREFIX}"
    "${STAGE1_PREFIX}/bin/clang" --version
    "${STAGE1_PREFIX}/bin/ld.lld" --version
}

# -----------------------------------------------------------------------------
# Main
# -----------------------------------------------------------------------------
main() {
    log "LLVM Stage 1 build starting"
    log "  BOOTSTRAP_PREFIX: ${BOOTSTRAP_PREFIX}"
    log "  STAGE1_PREFIX:    ${STAGE1_PREFIX}"
    log "  LLVM_VERSION:     ${LLVM_VERSION}"
    log "  NPROC:            ${NPROC}"

    download_llvm_source
    build_stage1

    log "Stage 1 build complete!"
}

main "$@"
