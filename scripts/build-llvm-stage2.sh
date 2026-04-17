#!/usr/bin/env bash
# =============================================================================
# LLVM Stage 2 Build — full self-hosted toolchain using Stage 1 clang
# Produces a portable, self-contained LLVM toolchain for distribution.
#
# Supports two variants:
#   VARIANT=main   — official LLVM release
#   VARIANT=p2996  — Bloomberg clang-p2996 fork (C++ reflection)
#
# Usage:
#   BOOTSTRAP_PREFIX=/opt/bootstrap STAGE1_PREFIX=/opt/stage1 \
#   INSTALL_PREFIX=/opt/coca-toolchain VARIANT=main \
#   ./scripts/build-llvm-stage2.sh
# =============================================================================
set -euo pipefail

: "${BOOTSTRAP_PREFIX:=/opt/bootstrap}"
: "${STAGE1_PREFIX:=/opt/stage1}"
: "${INSTALL_PREFIX:=/opt/coca-toolchain}"
: "${VARIANT:=main}"
: "${LLVM_VERSION:=21.1.1}"
: "${LLVM_SRC:=/tmp/llvm-project}"
: "${P2996_SRC:=/tmp/llvm-p2996}"
: "${STAGE2_BUILD:=/tmp/stage2-build}"
: "${NPROC:=$(nproc)}"

export PATH="${STAGE1_PREFIX}/bin:${BOOTSTRAP_PREFIX}/bin:${PATH}"
export LD_LIBRARY_PATH="${STAGE1_PREFIX}/lib:${BOOTSTRAP_PREFIX}/lib64:${BOOTSTRAP_PREFIX}/lib:${LD_LIBRARY_PATH:-}"

log() { echo "===> $(date '+%H:%M:%S') $*"; }

# Validate Stage 1
if [[ ! -x "${STAGE1_PREFIX}/bin/clang" ]]; then
    echo "ERROR: Stage 1 clang not found at ${STAGE1_PREFIX}/bin/clang" >&2
    exit 1
fi

# -----------------------------------------------------------------------------
# 1. Obtain source code
# -----------------------------------------------------------------------------
obtain_source() {
    case "${VARIANT}" in
        main)
            if [[ -d "${LLVM_SRC}/llvm" ]]; then
                log "Using existing LLVM source at ${LLVM_SRC}"
            else
                log "Downloading LLVM ${LLVM_VERSION} source..."
                local tarball="/tmp/llvm-project-${LLVM_VERSION}.src.tar.xz"
                if [[ ! -f "${tarball}" ]]; then
                    curl -fSL --retry 3 -o "${tarball}" \
                        "https://github.com/llvm/llvm-project/releases/download/llvmorg-${LLVM_VERSION}/llvm-project-${LLVM_VERSION}.src.tar.xz"
                fi
                mkdir -p "${LLVM_SRC}"
                tar xf "${tarball}" --strip-components=1 -C "${LLVM_SRC}"
            fi
            SOURCE_DIR="${LLVM_SRC}"
            ;;
        p2996)
            if [[ -d "${P2996_SRC}/llvm" ]]; then
                log "Using existing p2996 source at ${P2996_SRC}"
            else
                log "Cloning Bloomberg clang-p2996..."
                git clone --depth 1 --branch p2996 \
                    "https://github.com/bloomberg/clang-p2996.git" "${P2996_SRC}"
            fi
            SOURCE_DIR="${P2996_SRC}"
            ;;
        *)
            echo "ERROR: Unknown variant '${VARIANT}'. Use 'main' or 'p2996'." >&2
            exit 1
            ;;
    esac

    log "Source directory: ${SOURCE_DIR}"
}

# -----------------------------------------------------------------------------
# 2. Build Stage 2
# -----------------------------------------------------------------------------
build_stage2() {
    log "Configuring LLVM Stage 2 (variant=${VARIANT})..."

    mkdir -p "${STAGE2_BUILD}"

    # Common projects and runtimes
    local projects="clang;lld;clang-tools-extra;lldb;bolt;polly"
    local runtimes="compiler-rt;libunwind;libcxxabi;libcxx;openmp"
    local targets="X86;AArch64;ARM;WebAssembly;RISCV;NVPTX;AMDGPU;BPF"

    # p2996 variant adjustments: no bolt/polly/flang (fork may not support them)
    if [[ "${VARIANT}" == "p2996" ]]; then
        projects="clang;lld;clang-tools-extra;lldb"
        runtimes="compiler-rt;libunwind;libcxxabi;libcxx"
        targets="X86;AArch64;WebAssembly"
    fi

    # Add flang for main variant (requires Fortran-capable bootstrap — we have it from GCC)
    if [[ "${VARIANT}" == "main" ]]; then
        projects="${projects};flang"
    fi

    # Python paths for LLDB
    local python_exe="${BOOTSTRAP_PREFIX}/bin/python3"
    local python_version
    python_version=$("${python_exe}" -c 'import sys; print(f"{sys.version_info.major}.{sys.version_info.minor}")')
    local python_include
    python_include=$("${python_exe}" -c 'import sysconfig; print(sysconfig.get_path("include"))')
    local python_lib
    python_lib=$("${python_exe}" -c 'import sysconfig; print(sysconfig.get_config_var("LIBDIR"))')

    cmake -G Ninja -S "${SOURCE_DIR}/llvm" -B "${STAGE2_BUILD}" \
        -DCMAKE_BUILD_TYPE=Release \
        -DCMAKE_INSTALL_PREFIX="${INSTALL_PREFIX}" \
        -DCMAKE_C_COMPILER="${STAGE1_PREFIX}/bin/clang" \
        -DCMAKE_CXX_COMPILER="${STAGE1_PREFIX}/bin/clang++" \
        -DCMAKE_ASM_COMPILER="${STAGE1_PREFIX}/bin/clang" \
        -DCMAKE_AR="${STAGE1_PREFIX}/bin/llvm-ar" \
        -DCMAKE_RANLIB="${STAGE1_PREFIX}/bin/llvm-ranlib" \
        -DCMAKE_NM="${STAGE1_PREFIX}/bin/llvm-nm" \
        -DCMAKE_STRIP="${STAGE1_PREFIX}/bin/llvm-strip" \
        -DCMAKE_OBJCOPY="${STAGE1_PREFIX}/bin/llvm-objcopy" \
        -DCMAKE_OBJDUMP="${STAGE1_PREFIX}/bin/llvm-objdump" \
        -DLLVM_USE_LINKER=lld \
        \
        -DCMAKE_C_FLAGS="-w" \
        -DCMAKE_CXX_FLAGS="-stdlib=libc++ -w" \
        -DCMAKE_EXE_LINKER_FLAGS="-stdlib=libc++ '-Wl,-rpath,\$ORIGIN/../lib' -Wl,-rpath,${BOOTSTRAP_PREFIX}/lib64 -Wl,-rpath,${BOOTSTRAP_PREFIX}/lib" \
        -DCMAKE_SHARED_LINKER_FLAGS="-stdlib=libc++ '-Wl,-rpath,\$ORIGIN/../lib' -Wl,-rpath,${BOOTSTRAP_PREFIX}/lib64 -Wl,-rpath,${BOOTSTRAP_PREFIX}/lib" \
        \
        -DLLVM_ENABLE_PROJECTS="${projects}" \
        -DLLVM_ENABLE_RUNTIMES="${runtimes}" \
        -DLLVM_TARGETS_TO_BUILD="${targets}" \
        \
        -DLLVM_BUILD_LLVM_DYLIB=ON \
        -DLLVM_LINK_LLVM_DYLIB=ON \
        -DLLVM_ENABLE_LLD=ON \
        -DLLVM_INSTALL_UTILS=ON \
        -DLLVM_ENABLE_ASSERTIONS=OFF \
        -DLLVM_INCLUDE_TESTS=OFF \
        -DLLVM_INCLUDE_BENCHMARKS=OFF \
        -DLLVM_INCLUDE_EXAMPLES=OFF \
        -DLLVM_INCLUDE_DOCS=OFF \
        -DLLVM_ENABLE_BINDINGS=ON \
        -DLLVM_INSTALL_TOOLCHAIN_ONLY=OFF \
        \
        -DLLVM_ENABLE_TERMINFO=ON \
        -DLLVM_ENABLE_ZLIB=ON \
        -DLLVM_ENABLE_ZSTD=ON \
        -DLLVM_ENABLE_LIBXML2=ON \
        -DLLVM_ENABLE_LIBEDIT=ON \
        \
        -DCLANG_DEFAULT_RTLIB=compiler-rt \
        -DCLANG_DEFAULT_UNWINDLIB=libunwind \
        -DCLANG_DEFAULT_CXX_STDLIB=libc++ \
        -DCLANG_DEFAULT_LINKER=lld \
        \
        -DLLDB_ENABLE_PYTHON=ON \
        -DLLDB_ENABLE_LIBEDIT=ON \
        -DLLDB_ENABLE_CURSES=ON \
        -DLLDB_ENABLE_LZMA=ON \
        -DLLDB_ENABLE_LIBXML2=ON \
        -DPython3_EXECUTABLE="${python_exe}" \
        -DPython3_INCLUDE_DIR="${python_include}" \
        -DPython3_LIBRARY="${python_lib}/libpython${python_version}.so" \
        -DSWIG_EXECUTABLE="${BOOTSTRAP_PREFIX}/bin/swig" \
        \
        -DCOMPILER_RT_BUILD_SANITIZERS=ON \
        -DCOMPILER_RT_BUILD_XRAY=ON \
        -DCOMPILER_RT_BUILD_LIBFUZZER=ON \
        -DCOMPILER_RT_BUILD_PROFILE=ON \
        -DCOMPILER_RT_BUILD_MEMPROF=ON \
        -DCOMPILER_RT_BUILD_ORC=ON \
        \
        -DLIBCXX_INSTALL_MODULES=ON

    log "Building LLVM Stage 2..."
    cmake --build "${STAGE2_BUILD}" -j"${NPROC}"

    log "Installing LLVM Stage 2..."
    cmake --install "${STAGE2_BUILD}"

    log "Stage 2 installed to ${INSTALL_PREFIX}"
}

# -----------------------------------------------------------------------------
# 3. Post-install: fix rpaths, bundle shared libs, strip binaries
# -----------------------------------------------------------------------------
post_install() {
    log "Post-install: fixing rpaths and bundling dependencies..."

    # Copy bootstrap shared libraries that LLVM tools link against
    local lib_dest="${INSTALL_PREFIX}/lib"
    mkdir -p "${lib_dest}"

    # Libraries to bundle: libstdc++ (from GCC, for any GCC-compiled components),
    # plus all our custom-built shared libs
    local libs_to_copy=(
        # From bootstrap GCC
        "${BOOTSTRAP_PREFIX}/lib64/libstdc++.so"*
        "${BOOTSTRAP_PREFIX}/lib64/libgcc_s.so"*
        # Custom-built dependencies
        "${BOOTSTRAP_PREFIX}/lib/libz.so"*
        "${BOOTSTRAP_PREFIX}/lib/libzstd.so"*
        "${BOOTSTRAP_PREFIX}/lib/libxml2.so"*
        "${BOOTSTRAP_PREFIX}/lib/libncursesw.so"*
        "${BOOTSTRAP_PREFIX}/lib/libedit.so"*
        "${BOOTSTRAP_PREFIX}/lib/libffi.so"*
        "${BOOTSTRAP_PREFIX}/lib/liblzma.so"*
        # Python shared library for LLDB
        "${BOOTSTRAP_PREFIX}/lib/libpython"*.so*
    )

    for lib in "${libs_to_copy[@]}"; do
        if [[ -f "${lib}" && ! -d "${lib}" ]]; then
            cp -aL "${lib}" "${lib_dest}/" 2>/dev/null || true
        fi
    done

    # Fix rpaths on all ELF executables and shared libraries in the install
    log "Patching rpaths to use \$ORIGIN..."
    find "${INSTALL_PREFIX}/bin" -type f -executable | while read -r exe; do
        if file "${exe}" | grep -q "ELF"; then
            patchelf --set-rpath '$ORIGIN/../lib' "${exe}" 2>/dev/null || true
        fi
    done

    find "${INSTALL_PREFIX}/lib" -name '*.so*' -type f | while read -r lib; do
        if file "${lib}" | grep -q "ELF.*shared"; then
            patchelf --set-rpath '$ORIGIN' "${lib}" 2>/dev/null || true
        fi
    done

    # Strip debug info from binaries (significantly reduces size)
    log "Stripping binaries..."
    find "${INSTALL_PREFIX}/bin" -type f -executable | while read -r exe; do
        if file "${exe}" | grep -q "ELF"; then
            strip --strip-unneeded "${exe}" 2>/dev/null || true
        fi
    done
    find "${INSTALL_PREFIX}/lib" -name '*.so*' -type f | while read -r lib; do
        if file "${lib}" | grep -q "ELF.*shared"; then
            strip --strip-unneeded "${lib}" 2>/dev/null || true
        fi
    done
    # Don't strip .a files — they contain relocatable objects

    log "Post-install complete"
}

# -----------------------------------------------------------------------------
# 4. Bundle Python for LLDB (optional portable Python)
# -----------------------------------------------------------------------------
bundle_python() {
    log "Bundling Python for LLDB..."

    local python_dest="${INSTALL_PREFIX}/lib/python3"
    local python_version
    python_version=$("${BOOTSTRAP_PREFIX}/bin/python3" -c 'import sys; print(f"{sys.version_info.major}.{sys.version_info.minor}")')

    # Copy Python standard library (trimmed)
    mkdir -p "${python_dest}"
    cp -r "${BOOTSTRAP_PREFIX}/lib/python${python_version}"/* "${python_dest}/" 2>/dev/null || true

    # Remove test suites and unnecessary data to save space
    rm -rf "${python_dest}/test" \
           "${python_dest}/unittest/test" \
           "${python_dest}/lib2to3/tests" \
           "${python_dest}/tkinter" \
           "${python_dest}/turtledemo" \
           "${python_dest}/idlelib" \
           "${python_dest}/ensurepip/_bundled" \
           "${python_dest}/__pycache__"

    # Compile .py files to .pyc
    "${BOOTSTRAP_PREFIX}/bin/python3" -m compileall -q "${python_dest}" 2>/dev/null || true

    log "Python stdlib bundled to ${python_dest}"
}

# -----------------------------------------------------------------------------
# 5. Create archive
# -----------------------------------------------------------------------------
create_archive() {
    local archive_name
    case "${VARIANT}" in
        main)  archive_name="coca-toolchain-linux-x86_64" ;;
        p2996) archive_name="coca-toolchain-p2996-linux-x86_64" ;;
    esac

    log "Creating archive: ${archive_name}.tar.xz"

    local install_parent
    install_parent=$(dirname "${INSTALL_PREFIX}")
    local install_dir
    install_dir=$(basename "${INSTALL_PREFIX}")

    # Rename install dir to match archive name
    if [[ "${install_dir}" != "${archive_name}" ]]; then
        mv "${INSTALL_PREFIX}" "${install_parent}/${archive_name}"
    fi

    cd "${install_parent}"
    XZ_OPT="-T${NPROC} -6" tar cJf "/tmp/${archive_name}.tar.xz" "${archive_name}"

    # Restore original name
    if [[ "${install_dir}" != "${archive_name}" ]]; then
        mv "${install_parent}/${archive_name}" "${INSTALL_PREFIX}"
    fi

    log "Archive created: /tmp/${archive_name}.tar.xz"
    ls -lh "/tmp/${archive_name}.tar.xz"
}

# -----------------------------------------------------------------------------
# Main
# -----------------------------------------------------------------------------
main() {
    log "LLVM Stage 2 build starting"
    log "  VARIANT:          ${VARIANT}"
    log "  BOOTSTRAP_PREFIX: ${BOOTSTRAP_PREFIX}"
    log "  STAGE1_PREFIX:    ${STAGE1_PREFIX}"
    log "  INSTALL_PREFIX:   ${INSTALL_PREFIX}"
    log "  NPROC:            ${NPROC}"

    obtain_source
    build_stage2
    post_install
    bundle_python
    create_archive

    log "Stage 2 build complete!"
    log "Toolchain verification:"
    "${INSTALL_PREFIX}/bin/clang" --version
    "${INSTALL_PREFIX}/bin/lld" --version || true
    "${INSTALL_PREFIX}/bin/lldb" --version || true
}

main "$@"
