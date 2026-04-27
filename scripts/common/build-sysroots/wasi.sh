#!/usr/bin/env bash
# =============================================================================
# Build sysroots/wasm32-wasi from wasi-sdk official release tarball.
# =============================================================================
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${SCRIPT_DIR}/lib.sh"

WASI_SDK_VERSION="${SYSROOT_WASI_SDK_VERSION:-30.0}"
TRIPLE="wasm32-wasi"

SYSROOT_DIR="${SYSROOTS_CACHE_DIR}/${TRIPLE}"
WORK_DIR="${SYSROOTS_WORK_DIR}/${TRIPLE}"

log "Building sysroot ${TRIPLE} from wasi-sdk ${WASI_SDK_VERSION}"

rm -rf "${WORK_DIR}" "${SYSROOT_DIR}"
mkdir -p "${WORK_DIR}" "${SYSROOT_DIR}"

# wasi-sdk releases:
#   https://github.com/WebAssembly/wasi-sdk/releases/download/wasi-sdk-30/wasi-sysroot-30.0.tar.gz
ARCHIVE_NAME="wasi-sysroot-${WASI_SDK_VERSION}.tar.gz"
URL="https://github.com/WebAssembly/wasi-sdk/releases/download/wasi-sdk-${WASI_SDK_VERSION%%.*}/${ARCHIVE_NAME}"

log "Downloading ${URL}"
curl --fail --location --silent --show-error \
     --output "${WORK_DIR}/${ARCHIVE_NAME}" "${URL}"

# Extract — wasi-sysroot tarball has a top-level wasi-sysroot/ dir
tar -xzf "${WORK_DIR}/${ARCHIVE_NAME}" -C "${WORK_DIR}"

# wasi-sysroot tarball structure varies between releases:
#   • 25.0+: top-level wasi-sysroot-N.M.M/ wrapper, with multi-target sub-dirs
#     under include/ (e.g. include/wasm32-wasip1/wasi/api.h)
#   • older: top-level wasi-sysroot/ wrapper, single-target
# Locate the source root by finding the include/ that contains a wasi/api.h
# in any sub-directory.
src_dir=""
for cand in \
    "${WORK_DIR}/wasi-sysroot-${WASI_SDK_VERSION}" \
    "${WORK_DIR}/wasi-sysroot" \
    "${WORK_DIR}"; do
    if [[ -d "${cand}/include" ]] && \
       find "${cand}/include" -name 'api.h' -path '*/wasi/api.h' -print -quit | grep -q .; then
        src_dir="${cand}"
        break
    fi
done
# Last-resort heuristic: search anywhere under WORK_DIR
if [[ -z "${src_dir}" ]]; then
    found=$(find "${WORK_DIR}" -name 'api.h' -path '*/wasi/api.h' -print -quit 2>/dev/null)
    if [[ -n "${found}" ]]; then
        # Walk back from <root>/include/.../wasi/api.h to <root>
        src_dir="${found%/include/*}"
    fi
fi
if [[ -z "${src_dir}" ]]; then
    err "wasi-sysroot: could not locate any wasi/api.h after extraction"
    log "Contents of ${WORK_DIR}:"
    ls -la "${WORK_DIR}"
    exit 1
fi

log "Copying from ${src_dir}/ → ${SYSROOT_DIR}/"
cp -a "${src_dir}/." "${SYSROOT_DIR}/"

# Verify: at least one wasi/api.h must exist after copy
if ! find "${SYSROOT_DIR}/include" -name 'api.h' -path '*/wasi/api.h' -print -quit | grep -q .; then
    err "wasi-sdk sysroot missing any wasi/api.h after copy"
    find "${SYSROOT_DIR}" -name 'api.h' 2>/dev/null | head -10
    exit 1
fi

log "sysroot ${TRIPLE} complete"
du -sh "${SYSROOT_DIR}"
