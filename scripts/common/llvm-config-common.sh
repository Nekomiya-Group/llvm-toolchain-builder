#!/usr/bin/env bash
# =============================================================================
# LLVM CMake configuration — shared definitions used by both Stage 1 and Stage 2.
# Sourced by llvm-config-stage1.sh and llvm-config-stage2.sh.
# =============================================================================

: "${VARIANT:=main}"
: "${STAGE:=stage2}"
: "${PLATFORM:=linux-x64}"
: "${BOOTSTRAP_PREFIX:=/opt/bootstrap}"
: "${STAGE1_PREFIX:=/opt/stage1}"
: "${INSTALL_PREFIX:=/opt/coca-toolchain}"
: "${SOURCE_DIR:=/tmp/llvm-project}"
: "${BUILD_DIR:=/tmp/stage2-build}"

# Append common CMake args shared by all stages to CMAKE_ARGS.
_append_common_cmake_args() {
    local prefix
    if [[ "${STAGE}" == "stage1" ]]; then
        prefix="${STAGE1_PREFIX}"
    else
        prefix="${INSTALL_PREFIX}"
    fi

    CMAKE_ARGS+=(
        "-DCMAKE_BUILD_TYPE=Release"
        "-DCMAKE_INSTALL_PREFIX=${prefix}"
    )

    CMAKE_ARGS+=(
        "-DLLVM_ENABLE_ASSERTIONS=OFF"
        "-DLLVM_INCLUDE_TESTS=OFF"
        "-DLLVM_INCLUDE_BENCHMARKS=OFF"
        "-DLLVM_INCLUDE_EXAMPLES=OFF"
        "-DLLVM_INCLUDE_DOCS=OFF"
        "-DLLVM_ENABLE_PER_TARGET_RUNTIME_DIR=OFF"
    )

    CMAKE_ARGS+=(
        "-DCLANG_DEFAULT_RTLIB=compiler-rt"
        "-DCLANG_DEFAULT_UNWINDLIB=libunwind"
        "-DCLANG_DEFAULT_CXX_STDLIB=libc++"
        "-DCLANG_DEFAULT_LINKER=lld"
    )
}
