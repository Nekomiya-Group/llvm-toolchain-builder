#!/usr/bin/env bash
# =============================================================================
# Centralized version definitions for all LLVM toolchain builds.
# Source this file from any build script.
# =============================================================================

# LLVM
export LLVM_VERSION="${LLVM_VERSION:-21.1.1}"
export LLVM_GIT_TAG="llvmorg-${LLVM_VERSION}"
export LLVM_REPO="https://github.com/llvm/llvm-project.git"
export P2996_REPO="https://github.com/nekomiya-kasane/clang-p2996.git"
export P2996_BRANCH="p2996"

# Bootstrap tools
export GCC_VERSION="${GCC_VERSION:-14.2.0}"
export CMAKE_VERSION="${CMAKE_VERSION:-3.31.7}"
export NINJA_VERSION="${NINJA_VERSION:-1.12.1}"
export PYTHON_VERSION="${PYTHON_VERSION:-3.12.11}"
export SWIG_VERSION="${SWIG_VERSION:-4.3.1}"

# Bootstrap libraries
export OPENSSL_VERSION="${OPENSSL_VERSION:-3.5.0}"
export ZLIB_VERSION="${ZLIB_VERSION:-1.3.1}"
export ZSTD_VERSION="${ZSTD_VERSION:-1.5.7}"
export LIBXML2_VERSION="${LIBXML2_VERSION:-2.13.8}"
export NCURSES_VERSION="${NCURSES_VERSION:-6.5}"
export LIBEDIT_VERSION="${LIBEDIT_VERSION:-20250104-3.1}"
export LIBFFI_VERSION="${LIBFFI_VERSION:-3.4.7}"
export XZ_VERSION="${XZ_VERSION:-5.8.1}"
export PCRE2_VERSION="${PCRE2_VERSION:-10.45}"

# LLVM project lists (shared between all platforms)
# These are the canonical definitions — platform scripts should NOT override them
# unless there's a platform-specific reason (e.g., bolt is Linux-only).
LLVM_PROJECTS_MAIN="clang;lld;clang-tools-extra;lldb;mlir;polly;flang"
LLVM_PROJECTS_P2996="clang;lld;clang-tools-extra;lldb;mlir;polly;flang"

LLVM_RUNTIMES_MAIN="compiler-rt;libunwind;libcxxabi;libcxx;openmp;flang-rt"
LLVM_RUNTIMES_P2996="compiler-rt;libunwind;libcxxabi;libcxx;openmp;flang-rt"

LLVM_TARGETS_ALL="X86;AArch64;ARM;WebAssembly;RISCV;NVPTX;AMDGPU;BPF"
