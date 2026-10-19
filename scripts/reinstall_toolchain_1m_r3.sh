#!/bin/bash
# SRW3 Phase 1M — pinned toolchain rebuild r3 (sandbox reset #7 recovery).
# Recipe = scripts/r2_rebuild_toolchain.sh + the 1M repairs of record
# (phase1m/audit/m1-repair.md §8): prelude.md symlink at the K include root,
# the llvm-kompile-clang driver's /usr/bin/clang++-15 substituted with the
# extracted clang (the 1K fix of record — ONE path substitution, driver
# otherwise pristine), syslibs dev symlinks on LIBRARY_PATH, krypto shim
# rebuilt.  All extracted under /home/z/my-project/tools, no root.
# Idempotent: skips completed pieces.  Reconstructs tools/env.sh.
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

echo "=== 2. z3 / flex / libfl2 / libsecp256k1 runtime (sandbox apt) ==="
for p in z3 flex libfl2 libsecp256k1-2; do
  ls ${p}_*.deb >/dev/null 2>&1 || apt-get download $p 2>&1 | tail -1
done

echo "=== 3. LLVM-15 + clang-15 chain (bookworm pool) ==="
POOL=http://deb.debian.org/debian/pool/main/l/llvm-toolchain-15
curl -sSL "$POOL/" -o pool.html
for pkg in libllvm15 llvm-15 clang-15 libclang-cpp15 lld-15 libclang-common-15-dev; do
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
for d in k z3 flex llvm secp devheaders syslibs; do mkdir -p "$d"; done
[ -d k/usr/bin ] && [ -x k/usr/bin/kompile ] && echo "k already extracted" || {
  dpkg -x "$T/deb/k.deb" k && echo "k ok"; }
for f in "$T"/deb/z3_*.deb;  do dpkg -x "$f" z3;  done; echo "z3 ok"
for f in "$T"/deb/flex_*.deb "$T"/deb/libfl2_*.deb; do dpkg -x "$f" flex; done; echo "flex ok"
for f in "$T"/deb/libllvm15*.deb "$T"/deb/llvm-15_*.deb "$T"/deb/clang-15_*.deb \
         "$T"/deb/libclang-cpp15_*.deb "$T"/deb/lld-15_*.deb "$T"/deb/libclang-common-15-dev_*.deb; do
  [ -e "$f" ] && dpkg -x "$f" llvm
done; echo "llvm chain ok"
for f in "$T"/deb/libsecp256k1-?_*.deb; do [ -e "$f" ] && dpkg -x "$f" secp; done; echo "secp ok"
for f in "$T"/deb/libgmp-dev_*.deb "$T"/deb/libmpfr-dev_*.deb "$T"/deb/libsecp256k1-dev_*.deb; do
  [ -e "$f" ] && dpkg -x "$f" devheaders
done; echo "devheaders ok"

echo "=== secp soname compat symlinks ==="
for v in 0 1 2; do
  SRC=$(find secp -name "libsecp256k1.so.$v" | head -1)
  if [ -n "$SRC" ]; then
    D=$(dirname "$SRC")
    for w in 0 1 2; do [ -e "$D/libsecp256k1.so.$w" ] || ln -s "libsecp256k1.so.$v" "$D/libsecp256k1.so.$w"; done
  fi
done

echo "=== syslibs dev symlinks (host libtinfo/jemalloc/unwind; host mpfr) ==="
for lib in tinfo:6 mpfr:6 jemalloc:2 unwind:8; do
  name=${lib%%:*}; ver=${lib##*:}
  [ -e "syslibs/lib$name.so" ] || ln -s "/lib/x86_64-linux-gnu/lib$name.so.$ver" "syslibs/lib$name.so"
done
ls -la syslibs/

echo "=== K include root: prelude.md symlink (m1-repair.md §8) ==="
PRELUDE=$(find k -name "prelude.md" -path "*builtin*" | head -1)
if [ -n "$PRELUDE" ]; then
  INCDIR=$(dirname "$PRELUDE")
  # the include root kompile uses: the parent of builtin/
  ROOT="$INCDIR/.."
  [ -e "$ROOT/prelude.md" ] || ln -s "builtin/prelude.md" "$ROOT/prelude.md"
  echo "prelude.md link ok at $ROOT"
else
  echo "WARN: prelude.md not found under builtin/"
fi

echo "=== llvm-kompile-clang driver: ONE path substitution (1K fix of record) ==="
DRIVER=$(find k -name "llvm-kompile-clang" \( -type f -o -type l \) | head -1)
CLANGXX=$(find llvm -name "clang++-15" \( -type f -o -type l \) | head -1)
echo "driver: $DRIVER; clang++-15: $CLANGXX"
if [ -n "$DRIVER" ] && [ -n "$CLANGXX" ]; then
  [ -e "$DRIVER.orig" ] || cp "$DRIVER" "$DRIVER.orig"
  if head -1 "$DRIVER.orig" | grep -q "^#!.*bash"; then
    # pristine driver is a bash arg-parsing script (shebang '#!/bin/bash -e')
    # whose ONLY hardcoded tool path is /usr/bin/clang++-15 (line ~290)
    CL15=$(find llvm -name "clang-15" \( -type f -o -type l \) | head -1)
    sed "s#/usr/bin/clang++-15#$T/extract/$CLANGXX#g; s#/usr/bin/clang-15#$T/extract/$CL15#g" \
      "$DRIVER.orig" > "$DRIVER"
  else
    # binary or other: fall back to the exec wrapper
    printf '#!/bin/bash\nexec "%s" "$@"\n' "$T/extract/$CLANGXX" > "$DRIVER"
  fi
  chmod +x "$DRIVER"
  echo "driver repointed (orig preserved at $DRIVER.orig)"
fi

echo "=== env.sh (1M layout) ==="
KBIN=$(find k -maxdepth 5 -name kompile \( -type f -o -type l \) | head -1 | xargs dirname 2>/dev/null)
Z3BIN=$(find z3 -maxdepth 5 -name z3 \( -type f -o -type l \) | head -1 | xargs dirname 2>/dev/null)
LLVMBIN=$(find llvm -maxdepth 6 -name clang-15 \( -type f -o -type l \) | head -1 | xargs dirname 2>/dev/null)
LLVMLIB=$(dirname "$(find llvm -name "libLLVM-15.so*" | head -1)")
cat > "$T/env.sh" <<EOF
#!/bin/bash
# SRW3 Phase 1M environment — pinned toolchain (K v7.1.337, z3 4.13.3, LLVM-15 runtime)
export SRW3=/home/z/my-project/srw3-1m
export TOOLS=/home/z/my-project/tools
export KROOT=$T/extract/k
export PATH="$T/extract/$KBIN:$T/extract/$Z3BIN:$T/extract/flex/usr/bin:\$PATH"
export LD_LIBRARY_PATH="$T/extract/$LLVMLIB:$T/extract/secp/usr/lib/x86_64-linux-gnu:\${LD_LIBRARY_PATH:-}"
export LIBRARY_PATH="$T/extract/$LLVMLIB:\${LIBRARY_PATH:-}"
export Z3="$T/extract/$Z3BIN/z3"
export K_OPTS="-Xmx4g -Xss8m"
EOF
echo "env.sh written"

echo "=== krypto shim build (k/phase1d/shim — the multiblock-fix shim) ==="
. "$T/env.sh"
REPO=/home/z/my-project/srw3-1m
SHIMDIR="$REPO/k/phase1d/shim"
[ -d "$SHIMDIR" ] || SHIMDIR="$REPO/k/phase1c/shim"
cd "$SHIMDIR" || exit 1
CL="$T/extract/llvm/usr/bin/clang++-15"
[ -e "$CL" ] || CL=$(find "$T/extract/llvm" -name "clang++-15" \( -type f -o -type l \) | head -1)
KRES=$(find "$T/extract/llvm" -type d -name "15.0.*" -path "*lib/clang*" | head -1)
echo "shim dir: $SHIMDIR; clang++: $CL; clang resources: $KRES"
"$CL" -std=c++20 -O2 -c krypto_shim.cpp \
  -isystem "$KRES/include" -nostdinc++ -isystem /usr/include/c++/14 -isystem /usr/include/x86_64-linux-gnu/c++/14 \
  -I"$T/extract/k/usr/include/kllvm" -I"$T/extract/k/usr/include" \
  -I"$T/extract/devheaders/usr/include" -I. 2>&1 | tail -3
S1=${PIPESTATUS[0]}
"$CL" -std=c++20 -O2 -c plugin_util.cpp \
  -isystem "$KRES/include" -nostdinc++ -isystem /usr/include/c++/14 -isystem /usr/include/x86_64-linux-gnu/c++/14 \
  -I"$T/extract/k/usr/include/kllvm" -I"$T/extract/k/usr/include" \
  -I"$T/extract/devheaders/usr/include" 2>&1 | tail -3
S2=${PIPESTATUS[0]}
echo "shim objects rc: krypto=$S1 util=$S2"
if [ "$S1" = "0" ] && [ "$S2" = "0" ]; then
  ar rcs libkrypto-shim.a krypto_shim.o plugin_util.o
  echo "libkrypto-shim.a: $(ls -la libkrypto-shim.a | awk '{print $5}') bytes"
  SECPFILE=$(find "$T/extract/secp" -name "libsecp256k1.so.2" | head -1)
  [ -n "$SECPFILE" ] && cp -f "$SECPFILE" ./libsecp256k1.so
fi

echo "=== sanity ==="
kompile --version 2>&1 | head -2
z3 --version 2>&1 | head -1
echo "TOOLCHAIN_R3_DONE"
