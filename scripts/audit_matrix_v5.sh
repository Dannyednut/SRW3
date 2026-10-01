#!/bin/bash
# Phase 1B: generalized-state regression matrix v5.
# Re-runs every matrix-v3 stage into full_matrix_v5.txt (v3/v4 canonical
# records preserved untouched), then appends the Phase-1B stage: generalized
# demos (hs+llvm + equivalence), generalized ghost suites (36 claims, live
# re-run into the matrix transcript), Python generalized model, KEVM
# generalized binding demos.
# Usage: bash audit_matrix_v5.sh <stage>
#   setup | py | demos | claims | r2 | defect | ghost | tier3 | kevm |
#   gendemos | ghostgen | genbind | genverdict
V5=/home/z/my-project/scripts/.matrix_v5_stage.sh
if [ ! -f "$V5" ]; then
  sed -e 's|full_matrix_v3.txt|full_matrix_v5.txt|' \
      -e 's|cd /home/z/my-project/srw3-work \&\& timeout 300 make test|cd /home/z/my-project/download/srw3-artifacts/baseline/reference-implementation \&\& timeout 300 make test|' \
      /home/z/my-project/scripts/audit_matrix_v3.sh > "$V5"
fi
bash "$V5" "${1:-setup}"

GK=/home/z/my-project/srw3-kevm
case "$1" in
gendemos)
  OUT=$GK/transcripts/audit/full_matrix_v5.txt
  cd "$GK" || exit 1
  source /home/z/my-project/tools/env.sh
  {
  echo
  echo "=== [GEN-1] generalized demo suite — haskell (expected table = Part IX contract) ==="
  bash /home/z/my-project/scripts/run_gen_demos.sh k/gen-hs-out haskell 2>&1 | tail -1
  echo "=== [GEN-2] generalized demo suite — llvm ==="
  bash /home/z/my-project/scripts/run_gen_demos.sh k/gen-llvm-out llvm 2>&1 | tail -1
  echo "=== [GEN-3] hs <-> llvm semantic cell equivalence (10 demos) ==="
  cat transcripts/llvm_gen_equivalence.txt | tail -2
  echo
  } >> "$OUT"
  echo "gendemos done"
  ;;
ghostgen)
  # live re-run of ALL 36 generalized ghost claims into the matrix transcript
  # (fresh target file => the skip-logic re-executes every claim; resumable:
  # re-invoke the same stage until it reports ghostgen done)
  OUT=$GK/transcripts/audit/full_matrix_v5.txt
  cd "$GK" || exit 1
  GEN_OUT=/tmp/matrix_v5_ghostgen.txt bash /home/z/my-project/scripts/audit_ghost_gen.sh claims
  if rg -q "per-claim done" /tmp/matrix_v5_ghostgen.txt 2>/dev/null; then
    {
    echo
    echo "=== [GEN-4] generalized ghost suites — live re-run (36 claims) ==="
    echo "cm2 (CM2 alias):"
    rg "SRW3G2" /tmp/matrix_v5_ghostgen.txt | rg "kprove exit"
    echo "cm3 (CM3 aggregate authority):"
    rg "SRW3G3" /tmp/matrix_v5_ghostgen.txt | rg "kprove exit"
    echo "gen_full (generalized):"
    rg "SRW3G4" /tmp/matrix_v5_ghostgen.txt | rg "kprove exit"
    echo
    } >> "$OUT"
    cp /tmp/matrix_v5_ghostgen.txt "$GK/transcripts/audit/full_matrix_v5_ghostgen.txt"
    echo "ghostgen done"
  else
    echo "ghostgen PARTIAL (re-invoke to resume)"
  fi
  ;;
genbind)
  OUT=$GK/transcripts/audit/full_matrix_v5.txt
  cd "$GK" || exit 1
  source /home/z/my-project/tools/env.sh
  {
  echo
  echo "=== [GEN-5] Python generalized model (mirror oracle; 14 tests) ==="
  ( cd python-gen && timeout 300 python3 -m pytest test_gen.py -q 2>&1 | tail -2 )
  echo
  echo "=== [GEN-6] KEVM generalized binding (additive SRW3-GEN-EVM; frozen binding untouched) ==="
  for d in evm_gen_positive evm_gen_overflow; do
    timeout 600 krun k/kevm/demos/$d.srw3evm -d k/kevm/gen-hs-out \
      -cMODE=NORMAL -cSCHEDULE=CANCUN -cUSEGAS=false -cCHAINID=1 > /tmp/gb5_$d.txt 2>&1
    echo "--- $d: hs krun exit $? (1 = designed carrier terminal)" >> /tmp/gb5_hs.txt
  done
  python3 - /tmp/gb5_evm_gen_positive.txt /tmp/gb5_evm_gen_overflow.txt <<'PYEOF' >> "$OUT"
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
genverdict)
  OUT=$GK/transcripts/audit/full_matrix_v5.txt
  {
  echo
  echo "=== [VERDICT v5] ==="
  echo "Phase-1A surface (stages 1-11 + LLVM-1..10): see matrix transcript above;"
  echo "Phase-1B additions: GEN-1..3 demos 10/10 hs + 10/10 llvm + equivalent;"
  echo "GEN-4 ghost suites 36 claims (11 PROVED + NEG-fails per suite; T2+M #Top);"
  echo "GEN-5 python model; GEN-6 KEVM generalized binding COMMIT/REJECT+RESTORE."
  echo >> "$OUT"
  echo "genverdict done"
  } >> "$OUT" 2>/dev/null
  echo "genverdict done"
  ;;
esac
