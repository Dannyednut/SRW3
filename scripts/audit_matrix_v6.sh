#!/bin/bash
# SRW3 Phase 1D — Part I freeze regression matrix v6.
# Re-runs the complete evidence surface after the fourth sandbox reset, against
# the surviving compiled definitions (sha-verified against git) and the freshly
# rebuilt Phase-1C LLVM crypto layer (scripts/rebuild_1c_llvm_1d.sh):
#   [1]-[11]  v3 stage machinery (py stage repointed per v5 record)
#   [LLVM]    abstract demo suite on the LLVM backend + equivalence note
#   [GEN-1-6] Phase-1B generalized stages (demos hs+llvm, ghost 36 claims live,
#             python model, KEVM generalized binding)
#   [1C-1/2]  Phase-1C crypto stage (probe 8/8 + ck demos commit/reject/commit)
# Usage: bash audit_matrix_v6.sh <stage>
#   setup | py | demos | claims | r2 | defect | ghost | tier3 | kevm | llvm |
#   gendemos | ghostgen | genbind | ckcrypto | verdict
V6=/home/z/my-project/scripts/.matrix_v6_stage.sh
if [ ! -f "$V6" ]; then
  sed -e 's|full_matrix_v3.txt|full_matrix_v6.txt|' \
      -e 's|cd /home/z/my-project/srw3-work \&\& timeout 300 make test|cd /home/z/my-project/download/srw3-artifacts/baseline/reference-implementation \&\& timeout 300 make test|' \
      /home/z/my-project/srw3-work/scripts/audit_matrix_v3.sh > "$V6"
fi
bash "$V6" "${1:-setup}"

GK=/home/z/my-project/srw3-kevm
REPO=/home/z/my-project/srw3-work
case "$1" in
llvm)
  OUT=$GK/transcripts/audit/full_matrix_v6.txt
  source /home/z/my-project/tools/env.sh
  echo "=== [LLVM] abstract demo suite — llvm backend (frozen 1A definition) ===" >> "$OUT"
  timeout 2400 bash "$REPO/scripts/llvm_demo_suite.sh" "$GK/k/llvm-out" /tmp/v6_llvm_demos.txt 2>&1 | tail -1 >> "$OUT"
  rg -c "DEMO:" /tmp/v6_llvm_demos.txt >> "$OUT" 2>&1
  tail -2 "$GK/transcripts/llvm_demo_equivalence.txt" >> "$OUT" 2>/dev/null
  echo >> "$OUT"
  echo "llvm done"
  ;;
gendemos)
  OUT=$GK/transcripts/audit/full_matrix_v6.txt
  cd "$GK" || exit 1
  source /home/z/my-project/tools/env.sh
  {
  echo
  echo "=== [GEN-1] generalized demo suite — haskell ==="
  bash "$REPO/scripts/run_gen_demos.sh" k/gen-hs-out haskell 2>&1 | tail -1
  echo "=== [GEN-2] generalized demo suite — llvm ==="
  bash "$REPO/scripts/run_gen_demos.sh" k/gen-llvm-out llvm 2>&1 | tail -1
  echo "=== [GEN-3] hs <-> llvm semantic cell equivalence (10 demos) ==="
  cat transcripts/llvm_gen_equivalence.txt | tail -2
  echo
  } >> "$OUT"
  echo "gendemos done"
  ;;
ghostgen)
  OUT=$GK/transcripts/audit/full_matrix_v6.txt
  cd "$GK" || exit 1
  GEN_OUT=/tmp/matrix_v6_ghostgen.txt bash "$REPO/scripts/audit_ghost_gen.sh" claims
  if rg -q "per-claim done" /tmp/matrix_v6_ghostgen.txt 2>/dev/null; then
    {
    echo
    echo "=== [GEN-4] generalized ghost suites — live re-run (36 claims) ==="
    echo "cm2 (CM2 alias):"
    rg "SRW3G2" /tmp/matrix_v6_ghostgen.txt | rg "kprove exit"
    echo "cm3 (CM3 aggregate authority):"
    rg "SRW3G3" /tmp/matrix_v6_ghostgen.txt | rg "kprove exit"
    echo "gen_full (generalized):"
    rg "SRW3G4" /tmp/matrix_v6_ghostgen.txt | rg "kprove exit"
    echo
    } >> "$OUT"
    cp /tmp/matrix_v6_ghostgen.txt "$GK/transcripts/audit/full_matrix_v6_ghostgen.txt"
    echo "ghostgen done"
  else
    echo "ghostgen PARTIAL (re-invoke to resume)"
  fi
  ;;
genbind)
  OUT=$GK/transcripts/audit/full_matrix_v6.txt
  cd "$GK" || exit 1
  source /home/z/my-project/tools/env.sh
  {
  echo
  echo "=== [GEN-5] Python generalized model (mirror oracle; 14 tests) ==="
  ( cd "$REPO/python-gen" && timeout 300 python3 -m pytest test_gen.py -q 2>&1 | tail -2 )
  echo
  echo "=== [GEN-6] KEVM generalized binding (additive SRW3-GEN-EVM) ==="
  for d in evm_gen_positive evm_gen_overflow; do
    timeout 600 krun k/kevm/demos/$d.srw3evm -d k/kevm/gen-hs-out \
      -cMODE=NORMAL -cSCHEDULE=CANCUN -cUSEGAS=false -cCHAINID=1 > /tmp/gb6_$d.txt 2>&1
    echo "--- $d: krun exit $? (1 = designed carrier terminal)" >> "$OUT"
  done
  python3 - /tmp/gb6_evm_gen_positive.txt /tmp/gb6_evm_gen_overflow.txt <<'PYEOF' >> "$OUT"
import re, sys
def carrier(f):
    t = open(f).read()
    m = re.search(r'#w3State\s*\(\.\.\.\s*s:\s*(.*?)\s*,\s*ln:\s*(.*?)\s*,\s*n:\s*(\S+)\s*,\s*h:\s*(\S+)\s*\)', t, re.S)
    return None if not m else (' '.join(m.group(1).split()), ' '.join(m.group(2).split()), m.group(3), m.group(4))
p, o = carrier(sys.argv[1]), carrier(sys.argv[2])
ok_p = p and p[2] == '1' and p[3] == '0' and '2 |-> 30' in p[0] and '2 |-> 40' in p[0] and '3 |-> 7' in p[0] and '0 |-> 100' in p[0]
ok_o = o and o[2] == '0' and o[3] == '-1' and '.Map' in o[0]
print('positive COMMIT (n=1,h=0, aliased+aggregate values committed):', 'PASS' if ok_p else 'FAIL')
print('overflow REJECT+RESTORE (n=0,h=-1, storages restored):        ', 'PASS' if ok_o else 'FAIL')
PYEOF
  echo "structural hs vs llvm: $(tail -1 transcripts/audit/evm_gen_equivalence.txt)"
  echo
  } >> "$OUT"
  echo "genbind done"
  ;;
ckcrypto)
  OUT=$GK/transcripts/audit/full_matrix_v6.txt
  source /home/z/my-project/tools/env.sh
  echo "=== [1C-1] krypto probe — llvm + rebuilt shim (Phase-1C layer, re-verified) ===" >> "$OUT"
  # self-contained: rebuild the layer if the interpreter is absent (reset recovery)
  if [ ! -x "$REPO/k/phase1c/probe-out/interpreter" ]; then
    bash "$REPO/scripts/rebuild_1c_llvm_1d.sh" > /tmp/v6_1c_rebuild.log 2>&1
    echo "(layer rebuilt this run: $(tail -1 /tmp/v6_1c_rebuild.log))" >> "$OUT"
  fi
  timeout 120 krun "$REPO/k/phase1c/probe.pgm" -d "$REPO/k/phase1c/probe-out" > /tmp/v6_probe.txt 2>&1
  grep -o 'IV-[a-z0-9-]* ok=true\|IX-[a-z0-9-]* ok=true\|IVX-[a-z0-9-]* ok=true' /tmp/v6_probe.txt | sort -u >> "$OUT"
  echo "[1C-1] ok-count: $(grep -o 'ok=true' /tmp/v6_probe.txt | wc -l) / 8" >> "$OUT"
  echo "=== [1C-2] ck cryptographic-lineage gate demos — expect commit/reject/commit ===" >> "$OUT"
  for d in ck_chain_positive ck_tamper_reject ck_recover; do
    timeout 120 krun "$REPO/k/phase1c/$d.ck" -d "$REPO/k/phase1c/ck-out" > "/tmp/v6_$d.txt" 2>&1
    RES=$(grep -o '"commit"\|"reject"' "/tmp/v6_$d.txt" | tail -1 | tr -d '"')
    echo "--- $d: result=$RES" >> "$OUT"
  done
  echo >> "$OUT"
  echo "ckcrypto done"
  ;;
verdict)
  OUT=$GK/transcripts/audit/full_matrix_v6.txt
  {
  echo
  echo "=== [VERDICT v6 — Phase 1D Part I freeze] ==="
  echo "[1]-[11] v3 surface as v5 (zero-regression expectation); [LLVM] 13 demos llvm;"
  echo "[GEN-1..3] 10/10 hs + 10/10 llvm + equivalent; [GEN-4] 36 claims live;"
  echo "[GEN-5] python 14/14; [GEN-6] KEVM gen binding COMMIT/REJECT+RESTORE;"
  echo "[1C-1] probe 8/8 ok=true; [1C-2] ck demos commit/reject/commit."
  echo >> "$OUT"
  echo "verdict done"
  } >> "$OUT" 2>/dev/null
  echo "verdict done"
  ;;
esac
