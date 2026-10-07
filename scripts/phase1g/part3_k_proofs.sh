#!/bin/bash
# SRW3 Phase 1G — Part 3: K mechanized proofs (HASKELL backend, kprove).
# Runs every 1G claim one-per-file (split via split_auth_claims.py) and
# records per-claim exit codes verbatim (1E/1F precedent).
# Convention: exit 0 = PROVED; nonzero = NOT proved (for the negative
# controls in az_negative_proofs.k, nonzero is the DESIGNED outcome).
set -u
source /home/z/my-project/tools/env.sh
SRC=/home/z/my-project/srw3-kevm
OUT=$SRC/phase1g/transcripts/part3_k_proofs.txt
DEFS=$SRC/phase1g/semantics/authz-hs-out
INC="-I $SRC/phase1g/semantics -I $SRC/phase1f/semantics -I $SRC/phase1e/semantics -I $SRC/k/phase1d -I $PLUGIN"
mkdir -p "$(dirname "$OUT")"
if [ -z "${KEEPS:-}" ]; then : > "$OUT"; rm -f "$OUT.tmp_codes"; fi
log() { echo "$@" | tee -a "$OUT"; }

log "=== SRW3 Phase 1G — Part 3: K MECHANIZED PROOFS (HASKELL BACKEND, kprove) ==="
log "=== generated: $(date -u '+%Y-%m-%d %H:%M:%S UTC') ==="
log ""
log "definition : phase1g/semantics/srw3authz.k (module SRW3AUTHZ, additive; requires srw3exec.k)"
log "sha256(srw3authz.k) = $(sha256sum $SRC/phase1g/semantics/srw3authz.k | cut -d' ' -f1)"
log "K:         $(kompile --version 2>&1 | head -1)"
log "z3:        $(z3 --version 2>&1)"
log ""

rm -rf /tmp/authz-claims-1g; mkdir -p /tmp/authz-claims-1g
declare -a FILES=( az_record_proofs az_gate_proofs az_binding_proofs az_noncirc_proofs az_negative_proofs )
# FILTER: optional space-separated subset (e.g. "az_gate_proofs")
if [ -n "${1:-}" ]; then IFS=' ' read -ra FILES <<< "$1"; fi
declare -A MODNAME=( [az_record_proofs]=SRW3AUTHZ-RECBIND-PROOFS
                     [az_gate_proofs]=SRW3AUTHZ-GATE-PROOFS
                     [az_binding_proofs]=SRW3AUTHZ-BIND-PROOFS
                     [az_noncirc_proofs]=SRW3AUTHZ-NONCIRC-PROOFS
                     [az_negative_proofs]=SRW3AUTHZ-NEGATIVE-PROOFS )

if [ -z "${KEEPS:-}" ]; then PROVED=0; OTHER=0; else PROVED=$(grep -c PROVED /tmp/authz-1g-results.txt 2>/dev/null || echo 0); OTHER=$(grep -c "NOT-PROVED" /tmp/authz-1g-results.txt 2>/dev/null || echo 0); fi
if [ -z "${KEEPS:-}" ]; then : > /tmp/authz-1g-results.txt; fi
for F in "${FILES[@]}"; do
  python3 "$SRC/scripts/split_auth_claims.py" "$SRC/phase1g/proofs/$F.k" /tmp/authz-claims-1g > /dev/null 2>&1
done

for CK in /tmp/authz-claims-1g/*.k; do
  B=$(basename "$CK" .k)
  # recover the file stem and the label: the stem is one of the FILES entries
  STEM=""
  for F in "${FILES[@]}"; do
    case "$B" in
      ${F}_*) STEM="$F"; LABEL="${B#${F}_}"; break ;;
    esac
  done
  [ -z "$STEM" ] && continue
  MOD="${MODNAME[$STEM]}"
  log "--- claim $LABEL (module $MOD)"
  log "    file: proofs/$STEM.k"
  T0=$(date +%s)
  timeout 900 kprove "$CK" -d "$DEFS" --spec-module "$MOD" $INC \
      > /tmp/authz-1g-claim.out 2>&1
  EX=$?
  T1=$(date +%s)
  log "    kprove exit=$EX ($((T1-T0))s)"
  echo "$LABEL $EX" >> "$OUT.tmp_codes"
  if [ $EX -eq 0 ]; then
    log "    PROVED"
    PROVED=$((PROVED+1))
    echo "$LABEL PROVED" >> /tmp/authz-1g-results.txt
  else
    log "    NOT-PROVED (see the per-claim raw output; for the negative"
    log "    controls this is the DESIGNED outcome)"
    OTHER=$((OTHER+1))
    echo "$LABEL NOT-PROVED" >> /tmp/authz-1g-results.txt
    cp /tmp/authz-1g-claim.out "$SRC/phase1g/transcripts/part3_fail_$LABEL.txt"
  fi
  log ""
done

log "=== SUMMARY: PROVED=$PROVED  NOT-PROVED=$OTHER (negative controls are"
log "    designed NOT-PROVED: az_negative_proofs.k) ==="
log "PART3_K_PROOFS_DONE"
