# LLVM Toolchain Builder

This file provides context to GitLab Duo Agent Platform (and any AGENTS.md-compatible AI tool) about this repository.

## Project Overview

This repository builds a complete, self-contained LLVM/Clang toolchain for distribution.
The build is a **multi-stage process** running in CI (GitHub Actions + GitLab CI/CD):

1. **Bootstrap**: Builds GCC 14, CMake, Python 3.12, Ninja, SWIG, OpenSSL from source inside Ubuntu 16.04 Docker containers (maximum glibc compatibility).
2. **Stage 1**: Minimal clang + lld built using bootstrap GCC.
3. **Stage 2**: Full LLVM toolchain (clang, lld, lldb, flang, mlir, polly, bolt, compiler-rt, libc++, libunwind, openmp, etc.) built using Stage 1 clang with `-stdlib=libc++`.

Two variants are built:
- **main**: Official LLVM 21.1.1 release
- **p2996**: Bloomberg's clang-p2996 fork (C++ reflection TS)

Three platforms:
- **linux-x64**: Ubuntu 16.04 x86_64 (Docker)
- **linux-arm64**: Ubuntu 16.04 aarch64 (Docker)
- **windows-x64**: Stage 1 MSVC → Stage 2 clang-cl + libc++

## Repository Structure

```
.gitlab-ci.yml                — GitLab CI/CD pipeline (all platforms)
.github/workflows/            — GitHub Actions workflows (equivalent)
AGENTS.md                     — This file (GitLab Duo context)
scripts/
  common/
    versions.sh               — LLVM version, project lists, target lists
    source.sh                 — Source download/extraction logic
    llvm-config.sh            — Dispatcher: sources stage1 or stage2 config
    llvm-config-common.sh     — Shared CMake args (both stages)
    llvm-config-stage1.sh     — Stage 1 CMake args (cache-sensitive)
    llvm-config-stage2.sh     — Stage 2 CMake args
    post-install.sh           — Bundle libs, fix rpaths, strip, create archive
  bootstrap/
    common-bootstrap.sh       — Bootstrap build logic
  linux-x64/
    build-llvm-stage1.sh      — Stage 1 build script (x86_64)
    build-llvm-stage2.sh      — Stage 2 build script (x86_64)
  linux-arm64/
    build-llvm-stage1.sh      — Stage 1 build script (ARM64)
    build-llvm-stage2.sh      — Stage 2 build script (ARM64)
  windows-x64/
    build-llvm.ps1            — Windows Stage 1 (MSVC cl.exe)
    build-llvm-stage2.ps1     — Windows Stage 2 (clang-cl + libc++)
    verify-portability.ps1    — Post-build verification
```

## Key Architecture Decisions

- **`LLVM_ENABLE_PER_TARGET_RUNTIME_DIR=OFF`**: Runtimes install to `lib/` not `lib/<triple>/`, so `$ORIGIN/../lib` rpath works universally.
- **Linux Stage 2** uses `-stdlib=libc++` in `CMAKE_CXX_FLAGS` (not linker flags).
- **Linux Stage 2 linker flags** include `-L` paths and `-Wl,-rpath` for Stage 1 and bootstrap lib directories.
- **Linux cache strategy**: Stage 1 cache key only hashes `llvm-config-common.sh` + `llvm-config-stage1.sh`, so Stage 2-only changes don't trigger Stage 1 rebuilds.
- **Windows dual-stage**: Stage 1 uses MSVC cl.exe, Stage 2 uses clang-cl.exe. Windows does NOT build libunwind/libcxxabi (uses SEH + MSVC ABI).
- **Windows Stage 2 defaults**: `CLANG_DEFAULT_CXX_STDLIB=libc++`, `CLANG_DEFAULT_RTLIB=compiler-rt`, `CLANG_DEFAULT_LINKER=lld`.

## Common Failure Patterns

1. **`unable to find library -l<name>`**: Missing `-L` path in linker flags.
2. **`libc++.so.1: cannot open shared object file`**: Missing from `LD_LIBRARY_PATH` or rpath.
3. **`relocation error` / `symbol version not defined`**: Build-tree `lib/` not in `LD_LIBRARY_PATH`.
4. **CMake C compiler test fails**: Linker flags that only make sense for C++ (e.g., `-stdlib=libc++`).
5. **OOM / `basic_string::_M_create`**: Often corrupted data from loading wrong shared libs.

## Fix Guidelines

- **Root cause fixes only**: Never use workarounds.
- **Architecture integrity**: Maintain the stage1/stage2 separation and cache strategy.
- **No technical debt**: Every fix should be the correct long-term solution.
- **Cross-platform**: Will it work on x86_64, ARM64, AND Windows? If not, use platform guards.
- **Cache awareness**: Changes to Stage 1 scripts invalidate ~40min rebuild.
