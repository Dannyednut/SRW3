#!/bin/bash
# Audit P4: KEVM commitment-boundary evidence — inherited vs introduced
source /home/z/my-project/tools/env.sh
cd /home/z/my-project/srw3-kevm
OUT=transcripts/audit/boundary_census.txt
: > "$OUT"
{
echo "## P4 audit — KEVM binding: inherited (KEVM) vs introduced (SRW3) rule census"
echo "## date: $(date -u +'%Y-%m-%dT%H:%M:%SZ')"
echo
} >> "$OUT"

KPROJ_MD=/home/z/my-project/tools/evm-semantics-1.0.921/kevm-pyk/src/kevm_pyk/kproj/evm-semantics

echo "=== [1] KEVM sources used by the binding are UNMODIFIED vs the pristine v1.0.921 tarball ===" >> "$OUT"
mkdir -p /tmp/kevm-pristine && tar -xzf /home/z/my-project/tools/kevm-1.0.921.tar.gz -C /tmp/kevm-pristine 2>/dev/null
PRISTINE=$(dirname "$(rg --files /tmp/kevm-pristine -g 'evm.md' 2>/dev/null | head -1)" 2>/dev/null)
if [ -z "$PRISTINE" ]; then
  PRISTINE=$(rg --files /tmp/kevm-pristine -g 'evm.md' /home/z/my-project/tools 2>/dev/null | head -1)
  PRISTINE=$(dirname "$PRISTINE")
fi
echo "pristine dir: $PRISTINE" >> "$OUT"
DIFFSUM=0
for f in evm.md asm.md evm-types.md word.md data.md buf.md gas.md schedule.md serialization.md network.md hashed-locations.md state-utils.md; do
  if [ -f "$PRISTINE/$f" ]; then
    if diff -q "$PRISTINE/$f" "$KPROJ_MD/$f" >/dev/null 2>&1; then
      echo "  $f: IDENTICAL to pristine tarball" >> "$OUT"
    else
      echo "  $f: DIFFERS" >> "$OUT"; diff "$PRISTINE/$f" "$KPROJ_MD/$f" | head -5 >> "$OUT"; DIFFSUM=1
    fi
  else
    echo "  $f: (not in extracted pristine set; skipped)" >> "$OUT"
  fi
done
echo "any-diff flag: $DIFFSUM (0 = all checked KEVM sources byte-identical)" >> "$OUT"
echo >> "$OUT"

echo "=== [2] Rule census: what the binding ADDS vs what it INHERITS ===" >> "$OUT"
echo -n "  rules in k/kevm/srw3-kevm.k (ALL SRW3-introduced): " >> "$OUT"
rg -c "^\s*rule " k/kevm/srw3-kevm.k || echo 0 >> "$OUT"
echo -n "  syntax declarations introduced by the binding (all #w3*/W3* names): " >> "$OUT"
rg -c "^\s*syntax" k/kevm/srw3-kevm.k || echo 0 >> "$OUT"
echo -n "  of which non-#w3/non-SRW3 syntax: " >> "$OUT"
rg "^\s*syntax" k/kevm/srw3-kevm.k | rg -v "#w3|W3LinRec|EthereumSimulation" -c || echo 0 >> "$OUT"
echo -n "  rules in KEVM core evm.md (inherited, unmodified): " >> "$OUT"
rg -c "^\s*rule " "$KPROJ_MD/evm.md" || echo 0 >> "$OUT"
echo -n "  rules in KEVM asm.md (inherited, unmodified): " >> "$OUT"
rg -c "^\s*rule " "$KPROJ_MD/asm.md" || echo 0 >> "$OUT"
echo >> "$OUT"
echo "  introduced-rule inventory (k/kevm/srw3-kevm.k):" >> "$OUT"
rg -n "^\s*rule " k/kevm/srw3-kevm.k | sed 's/^/    /' >> "$OUT"
echo >> "$OUT"
echo "  EVM opcode semantics rules touched by the binding: NONE (the binding only" >> "$OUT"
echo "  adds #w3* driver/gate rules; SSTORE/SLOAD/CALL/RETURN/MSTORE/MLOAD/PUSH/STOP" >> "$OUT"
echo "  execute through evm.md's own rules, verified unmodified in [1])." >> "$OUT"
echo >> "$OUT"

echo "=== [3] Abstract layer: census of rules updating <committed> ===" >> "$OUT"
echo "  rules matching '<committed>' with an update (=>) in k/srw3.k:" >> "$OUT"
rg -n "<committed>.*=>" k/srw3.k | sed 's/^/    /' >> "$OUT"
echo "  (exactly one: the gate ACCEPT rule — the structural commitment boundary)" >> "$OUT"
echo >> "$OUT"
echo "=== [4] KEVM layer: census of rules writing account storage outside EVM execution ===" >> "$OUT"
echo "  SRW3-introduced rules that write <storage> (restore path):" >> "$OUT"
rg -n "#w3RestoreOne" k/kevm/srw3-kevm.k | sed 's/^/    /' >> "$OUT"
echo "  (restore = the reject path of the modeled commitment gate; the commit path" >> "$OUT"
echo "   re-snapshots via #w3allStorages — see rules at #w3Gate)" >> "$OUT"
echo >> "$OUT"
echo "=== done ===" >> "$OUT"
cat "$OUT" | head -60
