#!/usr/bin/env bash
# =============================================================================
# Post-install tasks for LLVM toolchain (Linux builds).
#
# Tasks:
#   1. Bundle bootstrap shared libraries
#   2. Install Clang Python bindings (from source tree)
#   3. Fix rpaths to use $ORIGIN
#   4. Strip debug info
#   5. Bundle Python stdlib for LLDB
#   6. Create distributable archive
#
# Requires: INSTALL_PREFIX, BOOTSTRAP_PREFIX, SOURCE_DIR, VARIANT set.
# =============================================================================

: "${INSTALL_PREFIX:=/opt/coca-toolchain}"
: "${BOOTSTRAP_PREFIX:=/opt/bootstrap}"
: "${SOURCE_DIR:=/tmp/llvm-project}"
: "${VARIANT:=main}"

# ── 1. Bundle shared libraries ──────────────────────────────────────────
bundle_shared_libs() {
    log "Bundling shared libraries from bootstrap..."

    local lib_dest="${INSTALL_PREFIX}/lib"
    mkdir -p "${lib_dest}"

    local libs_to_copy=(
        "${BOOTSTRAP_PREFIX}/lib64/libstdc++.so"*
        "${BOOTSTRAP_PREFIX}/lib64/libgcc_s.so"*
        "${BOOTSTRAP_PREFIX}/lib/libz.so"*
        "${BOOTSTRAP_PREFIX}/lib/libzstd.so"*
        "${BOOTSTRAP_PREFIX}/lib/libxml2.so"*
        "${BOOTSTRAP_PREFIX}/lib/libncursesw.so"*
        "${BOOTSTRAP_PREFIX}/lib/libedit.so"*
        "${BOOTSTRAP_PREFIX}/lib/libffi.so"*
        "${BOOTSTRAP_PREFIX}/lib/liblzma.so"*
        "${BOOTSTRAP_PREFIX}/lib/libpython"*.so*
    )

    for lib in "${libs_to_copy[@]}"; do
        if [[ -f "${lib}" && ! -d "${lib}" ]]; then
            cp -aL "${lib}" "${lib_dest}/" 2>/dev/null || true
        fi
    done

    log "Shared libraries bundled"
}

# ── 2. Install Clang Python bindings ────────────────────────────────────
install_clang_python_bindings() {
    local src_bindings="${SOURCE_DIR}/clang/bindings/python/clang"
    if [[ ! -d "${src_bindings}" ]]; then
        log "WARN: Clang Python bindings not found at ${src_bindings}, skipping"
        return 0
    fi

    local python_version
    python_version=$("${BOOTSTRAP_PREFIX}/bin/python3" -c 'import sys; print(f"{sys.version_info.major}.{sys.version_info.minor}")')

    # Install to lib/pythonX.Y/site-packages/clang/
    local dest="${INSTALL_PREFIX}/lib/python${python_version}/site-packages/clang"
    mkdir -p "${dest}"
    cp -r "${src_bindings}"/* "${dest}/"

    log "Clang Python bindings installed to ${dest}"
}

# ── 3. Fix rpaths ──────────────────────────────────────────────────────
fix_rpaths() {
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

    log "rpaths patched"
}

# ── 4. Strip binaries ──────────────────────────────────────────────────
strip_binaries() {
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

    log "Binaries stripped"
}

# ── 5. Bundle Python stdlib for LLDB ────────────────────────────────────
bundle_python_stdlib() {
    log "Bundling Python stdlib for LLDB..."

    local python_version
    python_version=$("${BOOTSTRAP_PREFIX}/bin/python3" -c 'import sys; print(f"{sys.version_info.major}.{sys.version_info.minor}")')

    local python_dest="${INSTALL_PREFIX}/lib/python3"
    mkdir -p "${python_dest}"
    cp -r "${BOOTSTRAP_PREFIX}/lib/python${python_version}"/* "${python_dest}/" 2>/dev/null || true

    # Remove bulky test suites and unnecessary data
    rm -rf "${python_dest}/test" \
           "${python_dest}/unittest/test" \
           "${python_dest}/lib2to3/tests" \
           "${python_dest}/tkinter" \
           "${python_dest}/turtledemo" \
           "${python_dest}/idlelib" \
           "${python_dest}/ensurepip/_bundled" \
           "${python_dest}/__pycache__"

    "${BOOTSTRAP_PREFIX}/bin/python3" -m compileall -q "${python_dest}" 2>/dev/null || true

    log "Python stdlib bundled to ${python_dest}"
}

# ── 6. Create archive ──────────────────────────────────────────────────
create_archive() {
    local arch_suffix
    case "${PLATFORM}" in
        linux-x64)   arch_suffix="linux-x86_64" ;;
        linux-arm64) arch_suffix="linux-aarch64" ;;
        *)           arch_suffix="linux-unknown" ;;
    esac

    local archive_name
    case "${VARIANT}" in
        main)  archive_name="coca-toolchain-${arch_suffix}" ;;
        p2996) archive_name="coca-toolchain-p2996-${arch_suffix}" ;;
    esac

    log "Creating archive: ${archive_name}.tar.xz"

    local install_parent
    install_parent=$(dirname "${INSTALL_PREFIX}")
    local install_dir
    install_dir=$(basename "${INSTALL_PREFIX}")

    if [[ "${install_dir}" != "${archive_name}" ]]; then
        mv "${INSTALL_PREFIX}" "${install_parent}/${archive_name}"
    fi

    local nproc
    nproc=$(nproc 2>/dev/null || echo 4)
    cd "${install_parent}"
    XZ_OPT="-T${nproc} -6" tar cJf "/tmp/${archive_name}.tar.xz" "${archive_name}"

    if [[ "${install_dir}" != "${archive_name}" ]]; then
        mv "${install_parent}/${archive_name}" "${INSTALL_PREFIX}"
    fi

    log "Archive created: /tmp/${archive_name}.tar.xz"
    ls -lh "/tmp/${archive_name}.tar.xz"
}

# ── Run all post-install steps ──────────────────────────────────────────
run_post_install() {
    bundle_shared_libs
    install_clang_python_bindings
    fix_rpaths
    strip_binaries
    bundle_python_stdlib
    create_archive
    log "Post-install complete"
}
