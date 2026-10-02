#!/bin/bash
# SRW3 Phase 1D — full environment rebuild after fourth sandbox reset.
# Recipe = Phase 0-D report §A + 1B/1C recorded deviations:
#   K v7.1.337 jammy deb, z3 4.13.3 (trixie), flex/libfl2 (trixie),
#   LLVM-15 runtime + clang-15 chain 15.0.6-4+b1 (bookworm pool; +b1 pattern fix
#   recorded in Phase-1C report §2), libsecp256k1 0.5.0 (trixie) + soname shims,
#   KEVM v1.0.921 source, blockchain-k-plugin K sources at pinned SHA,
#   dev headers for the krypto shim (gmp/mpfr/secp256k1), kompile path patches,
#   tools/env.sh reconstruction.
# All extracted, no root. Idempotent: skips completed pieces.
set -u
T=/home/z/my-project/tools
mkdir -p "$T"/{deb,extract}
cd "$T/deb" || exit 1

fetch() { # fetch <url> <out>
  [ -s "$2" ] && { echo "HAVE $2"; return 0; }
  curl -sSL --retry 3 -o "$2" "$1"; echo "GET $2 exit=$?"
}

echo "=== 1. K framework v7.1.337 (pinned jammy deb) ==="
fetch https://github.com/runtimeverification/k/releases/download/v7.1.337/kframework_7.1.337_amd64_ubuntu_jammy.deb k.deb

echo "=== 2. z3 / flex / libfl2 / libsecp256k1 runtime (trixie) ==="
for p in z3 flex libfl2 libsecp256k1-2; do
  ls ${p}_*.deb >/dev/null 2>&1 || apt-get download $p 2>&1 | tail -1
done

echo "=== 3. LLVM-15 + clang-15 chain 15.0.6-4+b1 (bookworm pool) ==="
# Phase-1C §2 pattern fix: pool publishes binary-suffixed names (15.0.6-4+b1);
# '+' must be inside the character class.
POOL=http://deb.debian.org/debian/pool/main/l/llvm-toolchain-15
curl -sSL "$POOL/" -o pool.html
for pkg in libllvm15 llvm-15 clang-15 libclang-cpp15 lld-15; do
  CAND=$(grep -o "${pkg}_[0-9][0-9.]*-[0-9~a-z.+]*_amd64\.deb" pool.html | grep -v "dbgsym" | sort -V | tail -1)
  echo "candidate $pkg: $CAND"
  [ -n "$CAND" ] && fetch "$POOL/$CAND" "$CAND"
done

echo "=== 4. dev headers for the krypto shim (gmp/mpfr/secp256k1) ==="
for p in libgmp-dev libmpfr-dev libsecp256k1-dev; do
  ls ${p}_*.deb >/dev/null 2>&1 || apt-get download $p 2>&1 | tail -1
done

echo "=== EXTRACT ==="
cd "$T/extract" || exit 1
for d in k z3 flex llvm secp devheaders; do mkdir -p "$d"; done
dpkg -x "$T/deb/k.deb" k && echo "k ok"
for f in "$T"/deb/z3_*.deb;  do dpkg -x "$f" z3;  done; echo "z3 ok"
for f in "$T"/deb/flex_*.deb "$T"/deb/libfl2_*.deb; do dpkg -x "$f" flex; done; echo "flex ok"
for f in "$T"/deb/libllvm15*.deb "$T"/deb/llvm-15_*.deb "$T"/deb/clang-15_*.deb \
         "$T"/deb/libclang-cpp15_*.deb "$T"/deb/lld-15_*.deb; do
  [ -e "$f" ] && dpkg -x "$f" llvm
done; echo "llvm chain ok"
for f in "$T"/deb/libsecp256k1-?_*.deb; do [ -e "$f" ] && dpkg -x "$f" secp; done; echo "secp ok"
for f in "$T"/deb/libgmp-dev_*.deb "$T"/deb/libmpfr-dev_*.deb "$T"/deb/libsecp256k1-dev_*.deb; do
  [ -e "$f" ] && dpkg -x "$f" devheaders
done; echo "devheaders ok"

echo "=== soname compat symlinks (secp256k1, worklog: .0<->.2) ==="
for v in 0 1 2; do
  SRC=$(find secp -name "libsecp256k1.so.$v" | head -1)
  if [ -n "$SRC" ]; then
    D=$(dirname "$SRC")
    for w in 0 1 2; do [ -e "$D/libsecp256k1.so.$w" ] || ln -s "libsecp256k1.so.$v" "$D/libsecp256k1.so.$w"; done
  fi
done
find secp -name "libsecp256k1.so*" -exec ls -la {} \;

echo "=== KEVM source unpack (K sources only) ==="
cd "$T" || exit 1
[ -s deb/kevm-1.0.921.tar.gz ] || fetch https://github.com/runtimeverification/evm-semantics/archive/refs/tags/v1.0.921.tar.gz deb/kevm-1.0.921.tar.gz
[ -d evm-semantics-1.0.921 ] || tar xzf deb/kevm-1.0.921.tar.gz
echo "kevm src ok"

echo "=== blockchain-k-plugin K sources at pinned SHA ==="
cd "$T" || exit 1
if [ ! -d plugin-207ae512 ]; then
  curl -sSL --retry 3 -o plugin.tar.gz https://github.com/runtimeverification/blockchain-k-plugin/archive/207ae5121e5178a09742ed746f2d15e34b1750cc.tar.gz
  mkdir -p plugin-207ae512 && tar xzf plugin.tar.gz -C plugin-207ae512 --strip-components=1
fi
echo "plugin ok: $(ls plugin-207ae512 | head -3 | tr '\n' ' ')"

echo "=== locate layout ==="
ls k/usr/local/k/bin 2>/dev/null | head -8 || find k -maxdepth 4 -name kompile | head -2
find z3 -maxdepth 4 -name z3 -type f | head -2
find llvm -name "clang-15" -type f | head -2
find secp -name "libsecp256k1.so.2" | head -2
echo "REBUILD_ENV_1D_DONE"
