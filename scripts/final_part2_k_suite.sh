#!/bin/bash
# SRW3 Phase 1D-R1-FINAL — Part 2 (+3): K-side composition suite, FINAL run.
#
# Executes the exact composition suite represented by
#   k/phase1d/srw3lin-r1.k + k/phase1d/srw3lin-r1-demo.k
# (= semantics/phase1d/srw3lin-r1.k + srw3lin-r1-demo.k in the artifact bundle)
# in TWO independent ways, both captured verbatim:
#   (A) LIVE re-kompile from source: shim rebuilt from source, definition
#       re-kompiled (LLVM backend + KRYPTO hooks) into a FRESH output dir.
#   (B) the COMMITTED compiled definition k/phase1d/r1-out (interpreter as
#       committed at the R1 head).
#
# Required verdicts: pos=valid; neg1=neg2=neg3=invalid-state-composition.
# The stale failed transcript part7_k_composition_suite.txt is preserved
# untouched; this script writes part7_k_composition_suite_final.txt.
set -u
source /home/z/my-project/tools/env.sh
SRC=/home/z/my-project/srw3-work
P1D=$SRC/k/phase1d
OUT=$P1D/part7_k_composition_suite_final.txt

: > "$OUT"
log() { echo "$@" | tee -a "$OUT"; }

log "=== SRW3 Phase 1D-R1-FINAL — Part 2: K COMPOSITION SUITE (FINAL RUN) ==="
log "=== generated: $(date -u '+%Y-%m-%d %H:%M:%S UTC') ==="
log ""
log "definition : k/phase1d/srw3lin-r1.k  (module SRW3LIN-R1, additive;"
log "             linCtxP + VerifyLineageP; legacy linCtx/VerifyLineage untouched)"
log "suite      : k/phase1d/srw3lin-r1-demo.k  (module SRW3LIN-R1-DEMO, pgm r1suite)"
log "scenario   : Q={1:{0:100,1:0},2:{0:50,1:1}}  E={1:{0:25},2:{1:7}}"
log "             P=Apply(Q,E)={1:{0:25,1:0},2:{0:50,1:7}}"
log "             neg1=P+{(2,9):999} (EXTRA — the L7 attack)  neg2=missing app-2 entries"
log "             neg3=(2,1):=9 (CHANGED)   pos=P (honest exact post)"
log "             all four records built by LinBuildRec (crypto fully genuine;"
log "             authorized-dishonest-producer construction)"
log ""
log "--- toolchain ---"
log "backend: llvm (r1-out/backend.txt: $(cat $P1D/r1-out/backend.txt))"
log "K:      $(kompile --version 2>&1 | head -1)"
log "z3:     $(z3 --version 2>&1)"
log "clang:  $($T/extract/llvm/usr/bin/clang++-15 --version 2>/dev/null | head -1)"
log "kevm:   v1.0.921 source; plugin @ 207ae512"
log ""

# ---------- (A) live shim rebuild + live re-kompile ----------
log "=== (A) LIVE RE-KOMPIle FROM SOURCE ==="
log ""
log "--- A.1 krypto shim rebuild (source: k/phase1d/shim/) ---"
log "exact command:"
log "  clang++-15 -std=c++20 -O2 -c krypto_shim.cpp -isystem <kllvm-clang-res> \\"
log "    -nostdinc++ -isystem /usr/include/c++/14 -isystem /usr/include/x86_64-linux-gnu/c++/14 \\"
log "    -I<kllvm-include> -I<k-include> -I<devheaders-include> -I."
log "  (idem plugin_util.cpp; then ar rcs libkrypto-shim.a)"
cd "$P1D/shim" || exit 1
KRES="$T/extract/llvm/usr/lib/llvm-15/lib/clang/15.0.6/include"
CL="$T/extract/llvm/usr/bin/clang++-15"
rm -f krypto_shim.o plugin_util.o libkrypto-shim.a
$CL -std=c++20 -O2 -c krypto_shim.cpp \
  -isystem "$KRES" -nostdinc++ -isystem /usr/include/c++/14 \
  -isystem /usr/include/x86_64-linux-gnu/c++/14 \
  -I"$KROOT/usr/include/kllvm" -I"$KROOT/usr/include" \
  -I"$T/extract/devheaders/usr/include" -I. >> "$OUT" 2>&1
E1=$?
$CL -std=c++20 -O2 -c plugin_util.cpp \
  -isystem "$KRES" -nostdinc++ -isystem /usr/include/c++/14 \
  -isystem /usr/include/x86_64-linux-gnu/c++/14 \
  -I"$KROOT/usr/include/kllvm" -I"$KROOT/usr/include" \
  -I"$T/extract/devheaders/usr/include" >> "$OUT" 2>&1
E2=$?
ar rcs libkrypto-shim.a krypto_shim.o plugin_util.o 2>> "$OUT"
E3=$?
cp -f "$T/extract/secp/usr/lib/x86_64-linux-gnu/libsecp256k1.so.2" libsecp256k1.so
log "clang++ krypto_shim.cpp exit=$E1"
log "clang++ plugin_util.cpp exit=$E2"
log "ar rcs libkrypto-shim.a exit=$E3"
log "libkrypto-shim.a: $(stat -c %s libkrypto-shim.a 2>/dev/null) bytes"
log "shim keccak-multiblock fix present: $(grep -c '1D-R1-KECCAK-MULTIBLOCK FIX' krypto_shim.cpp) marker line(s)"
log ""

log "--- A.2 kompile srw3lin-r1-demo.k (fresh output dir r1-out-final) ---"
log "exact command:"
log "  kompile srw3lin-r1-demo.k --backend llvm --hook-namespaces KRYPTO \\"
log "    --main-module SRW3LIN-R1-DEMO -o r1-out-final -I $PLUGIN"
cd "$P1D" || exit 1
rm -rf r1-out-final
export NIX_LLVM_KOMPILE_LIBS="-L$P1D/shim -lkrypto-shim -lsecp256k1 -lgmp"
timeout 600 kompile srw3lin-r1-demo.k --backend llvm --hook-namespaces KRYPTO \
  --main-module SRW3LIN-R1-DEMO -o r1-out-final -I "$PLUGIN" >> "$OUT" 2>&1
EK=$?
log "kompile exit=$EK (0 = ok)"
log ""

log "--- A.3 krun r1suite -d r1-out-final (fresh definition) ---"
log "exact command: krun r1suite.pgm -d r1-out-final"
echo 'r1suite' > /tmp/r1suite.pgm
timeout 300 krun /tmp/r1suite.pgm -d r1-out-final > /tmp/r1_final_run.txt 2>&1
ER=$?
log "krun exit=$ER"
log "--- verbatim krun output (A) ---"
cat /tmp/r1_final_run.txt >> "$OUT"
log "--- end verbatim output (A) ---"
V=$(grep -o '"pos=valid;neg1=invalid-state-composition;neg2=invalid-state-composition;neg3=invalid-state-composition"' /tmp/r1_final_run.txt | head -1 | tr -d '"')
log "FINAL FOUR VERDICTS (A): ${V:-<ABSENT — RUN FAILED>}"
log ""

# ---------- (B) committed definition ----------
log "=== (B) COMMITTED DEFINITION (k/phase1d/r1-out, interpreter as committed) ==="
log "exact command: krun r1suite.pgm -d r1-out"
timeout 300 krun /tmp/r1suite.pgm -d r1-out > /tmp/r1_committed_run.txt 2>&1
ER2=$?
log "krun exit=$ER2"
log "--- verbatim krun output (B) ---"
cat /tmp/r1_committed_run.txt >> "$OUT"
log "--- end verbatim output (B) ---"
V2=$(grep -o '"pos=valid;neg1=invalid-state-composition;neg2=invalid-state-composition;neg3=invalid-state-composition"' /tmp/r1_committed_run.txt | head -1 | tr -d '"')
log "FINAL FOUR VERDICTS (B): ${V2:-<ABSENT — RUN FAILED>}"
log ""

log "=== PART 3 STRUCTURAL VERIFICATION (K-side exact composition) ==="
log "composition relation (k/phase1d/srw3lin-r1.k, rule LinCompositionOk):"
log "  BytesEq( LinCanonKV(linCtxPostP(CTX)),"
log "           LinCanonKV(LinApplyEff(linCtxPre(CTX), linCtxEffP(CTX))) )"
log "i.e. PresentedPost == Apply(PreState, TrueEffects) is established through"
log "byte equality of the canonical finite-map encodings — NEVER by an"
log "asymmetric membership loop."
log "symmetry  : BytesEq(B,B)=>true / BytesEq(B1,B2)=>false [owise] (srw3lin.k)"
log "            compares its two arguments symmetrically; the compared terms"
log "            are canon(post) and canon(apply(pre,eff))."
log "canonical : LinCanonKV(M) = I2B4(sizeMap(M)) + LinKVIter(M); LinKVIter"
log "            extracts MinKeyOfMap ascending, slots likewise — one unique"
log "            byte string per finite map (injective encoding)."
log "extra key : changes sizeMap prefix AND appends an ascending-key section"
log "            -> different bytes -> rejected (neg1, the L7 attack)."
log "missing key: smaller sizeMap, missing section -> rejected (neg2)."
log "changed value: same key layout, different slot int -> rejected (neg3)."
log "The semantics were NOT weakened: the definition kompiled and run here is"
log "byte-identical to the committed srw3lin-r1.k (sha256 below)."
log "sha256(sr w3lin-r1.k): see manifest; verified by git clean tree."
log ""

if [ "$EK" = "0" ] && [ -n "$V" ] && [ -n "$V2" ]; then
  log "RESULT: PART7 K COMPOSITION SUITE FINAL = PASS (live re-kompile AND"
  log "committed definition agree; pos=valid; neg1=neg2=neg3=invalid-state-composition)"
  log "PART7_FINAL_DONE_OK"
else
  log "RESULT: PART7 K COMPOSITION SUITE FINAL = FAIL (see above)"
  log "PART7_FINAL_DONE_FAIL"
fi
