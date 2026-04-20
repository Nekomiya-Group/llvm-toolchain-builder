#!/usr/bin/env bash
# =============================================================================
# LLVM CMake configuration — Stage 1 (minimal clang + lld using bootstrap GCC).
#
# Changes to this file invalidate the Stage 1 cache.
# Changes to llvm-config-stage2.sh do NOT invalidate Stage 1 cache.
# =============================================================================

SCRIPT_DIR_CONFIG="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${SCRIPT_DIR_CONFIG}/llvm-config-common.sh"

generate_cmake_args() {
    CMAKE_ARGS=()

    # ── Compiler: bootstrap GCC ─────────────────────────────────────────
    CMAKE_ARGS+=(
        "-DCMAKE_C_COMPILER=${BOOTSTRAP_PREFIX}/bin/gcc"
        "-DCMAKE_CXX_COMPILER=${BOOTSTRAP_PREFIX}/bin/g++"
        "-DCMAKE_CXX_FLAGS=-w"
        "-DCMAKE_EXE_LINKER_FLAGS=-Wl,-rpath,${BOOTSTRAP_PREFIX}/lib64"
        "-DCMAKE_SHARED_LINKER_FLAGS=-Wl,-rpath,${BOOTSTRAP_PREFIX}/lib64"
    )

    # ── Projects: minimal set ───────────────────────────────────────────
    local targets
    case "${PLATFORM}" in
        linux-x64)   targets="X86" ;;
        linux-arm64) targets="AArch64" ;;
        *)           targets="X86" ;;
    esac

    CMAKE_ARGS+=(
        "-DLLVM_ENABLE_PROJECTS=clang;lld"
        "-DLLVM_ENABLE_RUNTIMES=compiler-rt;libunwind;libcxxabi;libcxx"
        "-DLLVM_TARGETS_TO_BUILD=${targets}"
    )

    # ── Common options ──────────────────────────────────────────────────
    _append_common_cmake_args

    # ── Stage 1 specific: disable optional deps for speed ───────────────
    CMAKE_ARGS+=(
        "-DLLVM_ENABLE_TERMINFO=OFF"
        "-DLLVM_ENABLE_ZLIB=OFF"
        "-DLLVM_ENABLE_ZSTD=OFF"
        "-DLLVM_ENABLE_LIBXML2=OFF"
    )

    # ── compiler-rt: minimal (no sanitizers) ────────────────────────────
    CMAKE_ARGS+=(
        "-DCOMPILER_RT_BUILD_SANITIZERS=OFF"
        "-DCOMPILER_RT_BUILD_XRAY=OFF"
        "-DCOMPILER_RT_BUILD_LIBFUZZER=OFF"
        "-DCOMPILER_RT_BUILD_PROFILE=OFF"
        "-DCOMPILER_RT_BUILD_MEMPROF=OFF"
        "-DCOMPILER_RT_BUILD_ORC=OFF"
    )
}
