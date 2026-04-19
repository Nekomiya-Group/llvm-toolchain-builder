#!/usr/bin/env bash
# =============================================================================
# Ubuntu 16.04 bootstrap — installs system packages, then calls common bootstrap.
# Works for both x86_64 and aarch64.
#
# Usage: BOOTSTRAP_PREFIX=/opt/bootstrap ./scripts/bootstrap/ubuntu-16.04.sh
# =============================================================================
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

: "${BOOTSTRAP_PREFIX:=/opt/bootstrap}"
: "${BUILD_DIR:=/tmp/bootstrap-build}"
: "${NPROC:=$(nproc)}"
: "${DOWNLOAD_DIR:=/tmp/bootstrap-downloads}"

# -----------------------------------------------------------------------------
# Ubuntu 16.04 system dependencies (apt)
# -----------------------------------------------------------------------------
install_system_deps() {
    echo "===> $(date '+%H:%M:%S') Installing Ubuntu 16.04 system dependencies via apt..."
    apt-get update -qq
    DEBIAN_FRONTEND=noninteractive apt-get install -y --no-install-recommends \
        build-essential \
        ca-certificates \
        curl \
        wget \
        file \
        texinfo \
        bison \
        flex \
        gawk \
        m4 \
        patch \
        patchelf \
        libcurl4-openssl-dev \
        tar \
        xz-utils \
        bzip2 \
        unzip \
        pkg-config \
        libssl-dev \
        zlib1g-dev \
        libbz2-dev \
        libsqlite3-dev \
        libreadline-dev \
        libgdbm-dev \
        libdb-dev \
        tk-dev \
        uuid-dev \
        autoconf \
        automake \
        libtool \
        git \
        gperf
}

# -----------------------------------------------------------------------------
# Main
# -----------------------------------------------------------------------------
install_system_deps

source "${SCRIPT_DIR}/common-bootstrap.sh"
run_bootstrap
