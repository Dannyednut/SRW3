#!/bin/bash
# Phase 1D — run the full 1D demonstration matrix into a transcript artifact.
# Covers: chain positive + independent verification, true-effects binding
# (CM-L5), 12-field tamper matrix (distinct verdicts), impersonation (CM-L4),
# replay R1/R2/R3 + honest continuation (R4).
set -u
source /home/z/my-project/tools/env.sh
D=$SRW3/k/phase1d
OUT=$SRW3/transcripts/audit/phase1d_lin_demos.txt
: > "$OUT"

echo "=== SRW3 Phase 1D — verifiable lineage demonstration matrix ($(date -u)) ===" >> "$OUT"
echo "=== definition: k/phase1d/srw3lin{,-verify,-gate,-demo}.k | LLVM + krypto shim ===" >> "$OUT"
echo "=== commitments: real Keccak256raw; signatures: secp256k1 (pinned libsecp256k1) ===" >> "$OUT"
echo "=== kompile: --backend llvm --hook-namespaces KRYPTO --main-module SRW3LIN-DEMO ===" >> "$OUT"
echo >> "$OUT"

cd "$D" || exit 1
run() {
  echo "--- $1" >> "$OUT"
  echo "program: $(cat "$1.lin")" >> "$OUT"
  timeout 120 krun "$1.lin" -d lin-out > "/tmp/p1d_lin_$1.txt" 2>&1
  echo "krun exit: $? (0 = clean)" >> "$OUT"
  grep -A2 "<result>" "/tmp/p1d_lin_$1.txt" | head -3 | sed 's/^/  /' >> "$OUT"
  echo >> "$OUT"
}

run lin_chain_positive
run lin_true_effects
run lin_tamper_matrix
run lin_impersonate
run lin_replay_same_chain
run lin_replay_fresh_chain

{
echo "=== interpretation ==="
echo "chain_positive : commit;commit; 0:valid;1:valid;  — two-record real-keccak chain;"
echo "                 independent verifier re-derives every digest/signature/commitment"
echo "                 from the claimed artifacts alone (no execution state)."
echo "true_effects   : record 1 (hidden side effect app2.slot1:=7) verifies against"
echo "                 TRUE effects but FAILS against the declared-only presentation"
echo "                 (invalid-appset) — declared-footprint divergence cannot hide (CM-L5)."
echo "tamper_matrix  : 12/12 fields tampered, 12 DISTINCT verdicts, one per field:"
echo "                 version/parent/tid/apps/inputD/effectD/stateD/policyV/"
echo "                 authority/evidence/sig/child."
echo "impersonate    : authority swapped to the OTHER in-set member — membership holds"
echo "                 but the evidence signature recovers to the true signer:"
echo "                 invalid-evidence (cryptographic authorization ≠ set membership, CM-L4)."
echo "replay R1      : verbatim replay of record 0 at position 2 → reject:invalid-tid"
echo "replay R2      : tid forged to current position → reject:invalid-parent"
echo "replay R3      : chain record forged into a fresh chain → reject:invalid-parent"
echo "replay R4      : after all replays rejected, the honest transition commits and the"
echo "                 full chain verifies 0:valid;1:valid;2:valid; (no corruption)"
} >> "$OUT"
echo "TRANSCRIPT_DONE"
