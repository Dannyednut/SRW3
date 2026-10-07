#!/bin/bash
# SRW3 Phase 1G — environment finalization after the 7th sandbox reset.
# Rebuilds the toolchain glue that rebuild_env_1d.sh does not cover:
#   1. llvm-kompile-clang clang++-15 path patch (the 1B/1D recorded patch)
#   2. syslibs dev-symlink shims (-ltinfo/-lmpfr/-ljemalloc/-lunwind/-lsecp256k1)
#   3. krypto shim build (k/phase1d/shim; keccak-multiblock fix marker present)
#   4. tools/env.sh reconstruction (pinned recipe; the runners source it)
# Idempotent.
set -u
T=/home/z/my-project/tools
SRW3=/home/z/my-project/srw3-kevm
KEX=$T/extract/k
LEX=$T/extract/llvm
export LD_LIBRARY_PATH="$LEX/usr/lib/x86_64-linux-gnu:$T/extract/secp/usr/lib/x86_64-linux-gnu:${LD_LIBRARY_PATH:-}"

log() { echo "[setup-1g] $*"; }

# --- 1. patch the hardcoded /usr/bin/clang++-15 in llvm-kompile-clang -------
LKC=$KEX/usr/bin/llvm-kompile-clang
if [ -f "$LKC" ] && ! grep -q "PHASE1G-PATCHED" "$LKC"; then
  cp -f "$LKC" "$LKC.orig"
  sed -i "s#run /usr/bin/clang++-15#run $LEX/usr/bin/clang++-15#g" "$LKC"
  echo '# PHASE1G-PATCHED: clang++-15 repointed to the extracted toolchain' >> "$LKC"
  log "llvm-kompile-clang patched"
else
  log "llvm-kompile-clang already patched (or missing)"
fi

# kompile must find the clang chain on PATH as well
log "clang++-15 at: $LEX/usr/bin/clang++-15"

# --- 2. syslibs dev-symlink shims -------------------------------------------
SL=$T/extract/syslibs
mkdir -p "$SL"
link_shim() { # <name> <system-resolved>
  local NAME="$1" TGT="$2"
  [ -e "$SL/$NAME" ] || ln -s "$TGT" "$SL/$NAME"
}
link_shim libtinfo.so    /lib/x86_64-linux-gnu/libtinfo.so.6
link_shim libmpfr.so     /lib/x86_64-linux-gnu/libmpfr.so.6
link_shim libjemalloc.so /lib/x86_64-linux-gnu/libjemalloc.so.2
link_shim libunwind.so   /lib/x86_64-linux-gnu/libunwind.so.8
SECPUN=$(find $T/extract/devheaders -name "libsecp256k1.so" | head -1)
[ -n "$SECPUN" ] && link_shim libsecp256k1.so "$SECPUN"
GMPUN=$(find $T/extract/devheaders -name "libgmp.so" | head -1)
[ -n "$GMPUN" ] && link_shim libgmp.so "$GMPUN"
GMPXXUN=$(find $T/extract/devheaders -name "libgmpxx.so" | head -1)
[ -n "$GMPXXUN" ] && link_shim libgmpxx.so "$GMPXXUN"
MPFRUN=$(find $T/extract/devheaders -name "libmpfr.so" | head -1)
[ -n "$MPFRUN" ] && link_shim libmpfr_dev.so "$MPFRUN"
log "syslibs shims: $(ls "$SL" | tr '\n' ' ')"

# --- 3. krypto shim build ----------------------------------------------------
SHIM=$SRW3/k/phase1d/shim
if [ -f "$SHIM/libkrypto-shim.a" ]; then
  log "krypto shim already built ($(stat -c%s "$SHIM/libkrypto-shim.a") bytes)"
else
  KRES="$LEX/usr/lib/llvm-15/lib/clang/15.0.6/include"
  cd "$SHIM" || exit 1
  "$LEX/usr/bin/clang++-15" -std=c++20 -O2 -c krypto_shim.cpp \
    -isystem "$KRES" -nostdinc++ -isystem /usr/include/c++/14 \
    -isystem /usr/include/x86_64-linux-gnu/c++/14 \
    -I"$KEX/usr/include/kllvm" -I"$KEX/usr/include" \
    -I"$T/extract/devheaders/usr/include" -I. || exit 1
  "$LEX/usr/bin/clang++-15" -std=c++20 -O2 -c plugin_util.cpp \
    -isystem "$KRES" -nostdinc++ -isystem /usr/include/c++/14 \
    -isystem /usr/include/x86_64-linux-gnu/c++/14 \
    -I"$KEX/usr/include/kllvm" -I"$KEX/usr/include" \
    -I"$T/extract/devheaders/usr/include" || exit 1
  ar rcs libkrypto-shim.a krypto_shim.o plugin_util.o
  cp -f "$T/extract/secp/usr/lib/x86_64-linux-gnu/libsecp256k1.so.2" \
        "$SHIM/libsecp256k1.so" 2>/dev/null
  log "krypto shim built: $(stat -c%s "$SHIM/libkrypto-shim.a") bytes"
fi

# --- 4. env.sh ---------------------------------------------------------------
cat > "$T/env.sh" <<EOF
# SRW3 pinned toolchain environment (reconstructed for Phase 1G; recipe =
# Phase 0-D report A + the 1B/1D/1E/1F recorded deviations)
export T=$T
export SRW3=$SRW3
export KEX=$KEX
export LEX=$LEX
export PATH="$KEX/usr/bin:$LEX/usr/bin:$T/extract/z3/usr/bin:$T/extract/flex/usr/bin:\$PATH"
export LD_LIBRARY_PATH="$LEX/usr/lib/x86_64-linux-gnu:$T/extract/secp/usr/lib/x86_64-linux-gnu:\${LD_LIBRARY_PATH:-}"
export LIBRARY_PATH="$T/extract/syslibs:$T/extract/devheaders/usr/lib/x86_64-linux-gnu:$LEX/usr/lib/x86_64-linux-gnu:\${LIBRARY_PATH:-}"
export NIX_LLVM_KOMPILE_LIBS="-L$SRW3/k/phase1d/shim -lkrypto-shim -lsecp256k1 -lgmp"
export PLUGIN=$T/plugin-207ae512/plugin
export SRW3_TMPDIR=/tmp
EOF
log "env.sh written"

# --- 5. smoke test -----------------------------------------------------------
source "$T/env.sh"
log "kompile: $(kompile --version 2>&1 | head -1)"
log "z3: $(z3 --version 2>&1 | head -1)"
log "clang: $("$LEX/usr/bin/clang-15" --version 2>&1 | head -1)"
log "SETUP_1G_DONE"
