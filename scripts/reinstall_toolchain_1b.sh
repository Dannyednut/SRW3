#!/bin/bash
# SRW3 Phase 1B — toolchain reinstall after sandbox reset.
# Recipe = Phase 0-D report §A (pinned): K v7.1.337 jammy deb, z3 4.13.3 (trixie),
# flex/libfl2 2.6.4, LLVM-15 runtime (bookworm pool, for kore-expand-macros),
# libsecp256k1 (kore-exec), KEVM v1.0.921 source. All extracted, no root.
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

echo "=== 2. z3 (trixie) ==="
apt-get download z3 2>&1 | tail -1; ls z3_*.deb 2>/dev/null || echo "Z3_FAIL"

echo "=== 3. flex + libfl2 ==="
apt-get download flex 2>&1 | tail -1
apt-get download libfl2 2>&1 | tail -1

echo "=== 4. LLVM-15 runtime (kore-expand-macros) ==="
# trixie has no llvm-15; use bookworm pool. List pool, take newest 15.0.6 libllvm15.
POOL=http://deb.debian.org/debian/pool/main/l/llvm-toolchain-15
curl -sSL "$POOL/" -o pool.html
LIBLLVM=$(grep -o 'libllvm15_15\.0\.6-[0-9~a-z.]*_amd64\.deb' pool.html | sort -V | tail -1)
echo "libllvm15 candidate: $LIBLLVM"
[ -n "$LIBLLVM" ] && fetch "$POOL/$LIBLLVM" "$LIBLLVM"

echo "=== 5. libsecp256k1 (kore-exec) ==="
apt-get download libsecp256k1-2 2>/dev/null | tail -1
ls libsecp256k1*.deb 2>/dev/null || apt-get download libsecp256k1-0 2>&1 | tail -1
ls libsecp256k1*.deb 2>/dev/null || { curl -sSL http://deb.debian.org/debian/pool/main/libs/libsecp256k1/ -o sec.html; S=$(grep -o 'libsecp256k1-[0-9]_[0-9.]*-[0-9a-z.]*_amd64\.deb' sec.html | sort -V | tail -1); echo "pool candidate: $S"; [ -n "$S" ] && fetch "http://deb.debian.org/debian/pool/main/libs/libsecp256k1/$S" "$S"; }

echo "=== 6. KEVM v1.0.921 source (for gen binding stage) ==="
fetch https://github.com/runtimeverification/evm-semantics/archive/refs/tags/v1.0.921.tar.gz kevm-1.0.921.tar.gz

echo "=== EXTRACT ==="
cd "$T/extract" || exit 1
for d in k z3 flex llvm secp; do mkdir -p "$d"; done
dpkg -x "$T/deb/k.deb" k                       && echo "k ok"
for f in "$T"/deb/z3_*.deb;      do dpkg -x "$f" z3;   done; echo "z3 ok"
for f in "$T"/deb/flex_*.deb "$T"/deb/libfl2_*.deb; do dpkg -x "$f" flex; done; echo "flex ok"
for f in "$T"/deb/libllvm15*.deb; do dpkg -x "$f" llvm; done; echo "llvm ok"
for f in "$T"/deb/libsecp256k1*.deb; do dpkg -x "$f" secp; done; echo "secp ok"

echo "=== soname compat symlinks (secp256k1, worklog: .0<->.2) ==="
find secp -name "libsecp256k1.so*" -exec ls -la {} \;
for v in 0 1 2; do
  SRC=$(find secp -name "libsecp256k1.so.$v" | head -1)
  if [ -n "$SRC" ]; then
    D=$(dirname "$SRC")
    for w in 0 1 2; do [ -e "$D/libsecp256k1.so.$w" ] || ln -s "libsecp256k1.so.$v" "$D/libsecp256k1.so.$w"; done
  fi
done
find secp -name "libsecp256k1.so*" -exec ls -la {} \;

echo "=== KEVM source unpack (deferred heavy build; K sources only) ==="
cd "$T" || exit 1
[ -d evm-semantics-1.0.921 ] || tar xzf deb/kevm-1.0.921.tar.gz && echo "kevm src ok"

echo "=== locate layout ==="
ls k/usr/local/k/bin 2>/dev/null | head -20 || find k -maxdepth 4 -name kompile | head
find z3 -name "z3" -type f | head -2
find llvm -name "libLLVM-15.so*" | head -3
find flex -name "flex" -type f | head -2
echo "REINSTALL_DONE"
