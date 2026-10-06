#!/bin/bash
# SRW3 Phase 1F — Part 3: K mechanized proofs (HASKELL backend, kprove).
# Runs every 1F claim one-per-file (split via split_auth_claims.py) and
# records per-claim exit codes verbatim (1E part3 precedent).
# Convention: exit 0 = PROVED; nonzero = NOT proved (for negative controls
# in exec_negative_controls.k, nonzero is the DESIGNED outcome).
set -u
source /home/z/my-project/tools/env.sh
SRC=/home/z/my-project/srw3-kevm
OUT=$SRC/phase1f/transcripts/part3_k_proofs.txt
DEFS=$SRC/phase1f/semantics/exec-hs-out
INC="-I $SRC/phase1f/semantics -I $SRC/phase1e/semantics -I $SRC/k/phase1d -I /home/z/my-project/tools/plugin-207ae512/plugin"
mkdir -p "$(dirname "$OUT")"
if [ -z "${KEEPS:-}" ]; then : > "$OUT"; rm -f "$OUT.tmp_codes"; fi
log() { echo "$@" | tee -a "$OUT"; }

log "=== SRW3 Phase 1F — Part 3: K MECHANIZED PROOFS (HASKELL BACKEND, kprove) ==="
log "=== generated: $(date -u '+%Y-%m-%d %H:%M:%S UTC') ==="
log ""
log "definition : phase1f/semantics/srw3exec.k (module SRW3EXEC, additive; requires srw3auth.k)"
log "sha256(srw3exec.k) = $(sha256sum $SRC/phase1f/semantics/srw3exec.k | cut -d' ' -f1)"
log "K:         $(kompile --version 2>&1 | head -1)"
log "z3:        $(z3 --version 2>&1)"
log ""

rm -rf /tmp/exec-claims-1f; mkdir -p /tmp/exec-claims-1f
declare -a FILES=( exec_id_canon exec_replay exec_record_binding exec_gate_binding )
# FILTER: optional space-separated subset (e.g. "exec_replay exec_record_binding")
if [ -n "${1:-}" ]; then IFS=' ' read -ra FILES <<< "$1"; fi
declare -A MODNAME=( [exec_id_canon]=SRW3EXEC-ID-CANON-PROOFS
                     [exec_replay]=SRW3EXEC-REPLAY-PROOFS
                     [exec_record_binding]=SRW3EXEC-RECBIND-PROOFS
                     [exec_gate_binding]=SRW3EXEC-GATE-PROOFS )

if [ -z "${KEEPS:-}" ]; then PROVED=0; OTHER=0; else PROVED=$(grep -c PROVED /tmp/exec-1f-results.txt 2>/dev/null || echo 0); OTHER=$(grep -c "NOT-PROVED" /tmp/exec-1f-results.txt 2>/dev/null || echo 0); fi
if [ -z "${KEEPS:-}" ]; then : > /tmp/exec-1f-results.txt; fi
for F in "${FILES[@]}"; do
  python3 "$SRC/scripts/split_auth_claims.py" "$SRC/phase1f/proofs/$F.k" /tmp/exec-claims-1f > /dev/null 2>&1
done
# split negative controls too (same splitter)
if [[ " ${FILES[*]} " == *" exec_negative_controls "* || "${#FILES[@]}" -eq 4 ]]; then
  python3 "$SRC/scripts/split_auth_claims.py" "$SRC/phase1f/proofs/exec_negative_controls.k" /tmp/exec-claims-1f > /dev/null 2>&1
fi

for CK in /tmp/exec-claims-1f/*.k; do
  B=$(basename "$CK" .k)               # e.g. exec_gate_binding_EXB1
  F=${B%%_*}_                          # exec_gate_binding_
  STEM=$(echo "$B" | cut -d_ -f1)      # base stem
  # stem may contain underscores (exec_id_canon); recover by stripping the label
  LABEL=$(echo "$B" | sed 's/^[a-z_]*_//')
  STEM=${B%_$LABEL}
  MOD=${MODNAME[$STEM]:-SRW3EXEC-NEG-PROOFS}
  ST=$(date +%s)
  timeout 900 kprove "$CK" -d "$DEFS" --spec-module "$MOD" $INC > "/tmp/1f_${B}.out" 2>&1
  EX=$?
  EN=$(( $(date +%s) - ST ))
  if [ "$EX" -eq 0 ]; then
    V="PROVED"; PROVED=$((PROVED+1))
  else
    V="NOT-PROVED(exit=$EX)"; OTHER=$((OTHER+1))
  fi
  echo "$STEM $LABEL $V time=${EN}s" | tee -a /tmp/exec-1f-results.txt
  echo "$STEM $LABEL exit=$EX time=${EN}s" >> "$OUT.tmp_codes"
done

log "--- RESULTS ---"
cat /tmp/exec-1f-results.txt | while read -r STEM LABEL V T; do
  echo "$STEM $LABEL $V $T" >> "$OUT"
done
log ""
log "--- per-claim exit codes (verbatim) ---"
sort "$OUT.tmp_codes" >> "$OUT" 2>/dev/null || true
log ""
log "PROVED claims: $PROVED ; NOT-PROVED (incl. designed-fail controls): $OTHER"
log ""
log "PART3_K_PROOFS_DONE"
