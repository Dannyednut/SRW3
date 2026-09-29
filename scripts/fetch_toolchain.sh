#!/bin/bash
# SRW3 Phase 0-D toolchain fetch script — pinned versions
# K: v7.1.337 (pinned by KEVM v1.0.921 deps/k_release)
# KEVM: v1.0.921 (source, no binary assets published)
# Z3: Debian trixie package (extracted, no root install)
set -x
cd /home/z/my-project/tools || exit 1

# 1. K framework deb (jammy build; glibc-forward-compatible with trixie)
curl -sSL -o kframework_7.1.337_amd64_ubuntu_jammy.deb \
  https://github.com/runtimeverification/k/releases/download/v7.1.337/kframework_7.1.337_amd64_ubuntu_jammy.deb
echo "K_DEB_EXIT:$?"

# 2. KEVM source tarball
curl -sSL -o kevm-1.0.921.tar.gz \
  https://github.com/runtimeverification/evm-semantics/archive/refs/tags/v1.0.921.tar.gz
echo "KEVM_SRC_EXIT:$?"

# 3. z3 from Debian trixie repo (download-only, no root needed)
apt-get download z3 2>&1
echo "Z3_EXIT:$?"
ls -la
echo "FETCH_DONE"
