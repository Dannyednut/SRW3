#!/bin/bash
# =============================================================================
# SRW3 Phase 1X — the HARDENED ghost-fidelity regeneration + per-claim battery
# runner (phase1x/proofs/run_1x_ghost.sh; structural descendant of the audited
# phase1v/phase1w runners with the R13 + status-fidelity corrections).
#
# Corrections over run_1w_ghost.sh (root cause and evidence: phase1x/report):
#   C1 (R13 / WS-A1)  The splitter output is ASSERTED against the pinned
#        expected-claim inventory (phase1x/claims/expected-ghost-inventory.json)
#        BEFORE any K proof is invoked. Missing labels, unexpected labels,
#        duplicates, empty/malformed output, and spec-file mismatches all
#        terminate the run as a failure (stage LABELCHECK, and re-asserted
#        inside MAIN/GENSPEC). The battery can no longer be silently shortened
#        or extended by a splitter regression.
#   C2 (WS-B)  Status-aware per-claim assertions via classify_1x.py:
#        PROVED requires rc=0 + '#Top' + no prover [Error] + no stuck warning;
#        GH-T / GH-T2-NEG / *NEG are asserted FAILED-STUCK from the diagnostic
#        signature (WarnStuckClaimState + backend termination), not from the
#        bare exit code; rc=124 is TIMEOUT; anything unrecognized fails.
#        The Phase 1W ledger's coarse 'FAILED' label for these rows is
#        superseded BY THE 1X LEDGER ONLY; 1W files are immutable.
#   C3 (WS-B2)  The GENSPEC loop now requires the proof-closure evidence for
#        PROVED rows (rc + #Top + clean log) — the 1W loop checked only the
#        exit code, so a closure-free rc=0 would have been misclassified.
#   C4 (WS-C)  Isolation: unique mktemp workspaces, EXIT/INT/TERM cleanup
#        traps, splitter failure = stage failure, all 1X evidence under
#        phase1x/ (historical phase1u/1v/1w artifacts are never written),
#        every assertion failure is printed BY NAME, nonzero exit on any
#        unexpected outcome, and per-stage row-count pins on the ledger.
#
# Stages (default all): LABELCHECK GEN KOM MAIN GENSPEC
#   LABELCHECK  splitter-vs-inventory assertions only (no K required)
#   GEN         artifact regeneration + fidelity certificates (as 1W)
#   KOM         ghost definition kompile
#   MAIN        the 12-claim main battery (isolated kprove, status-aware)
#   GENSPEC     the three generalized batteries (12+12+11, status-aware);
#               GS_SUITES="cm2_alias cm3_auth gen_full" subsets the suites
#               (staged execution under the sandbox tool-call budget)
# RUN_APPEND=1 appends for staged re-invocation; each stage re-runs ALL of its
# claims and the ledger is deduplicated LAST-WINS after every stage (each
# control appears exactly once, with the outcome of its final execution; the
# retained transcript is that same final execution's log — the 1W R14
# discipline, automated). Raw logs: phase1x/transcripts/ghost/. Ledger:
# phase1x/claims/ghost-verdicts-1x.csv. Nonzero exit on ANY deviation.
# A successful runner means the EXPECTED proof and control outcomes were
# obtained and correctly classified — it is NOT a claim that every proof
# obligation is closed (GH-T stays FAILED-STUCK; verdict PARTIALLY COMPLETE).
# Level III only.
# =============================================================================
set -u
cd "$(dirname "$0")/../.." || exit 1
REPO=$PWD

export LD_LIBRARY_PATH="${LD_LIBRARY_PATH:-}"   # env.sh appends to it; keep set -u safe
if [ -n "${KTOOLS:-}" ] && [ -f "$KTOOLS/env.sh" ]; then source "$KTOOLS/env.sh"
elif [ -f /home/z/my-project/tools1v/env.sh ]; then source /home/z/my-project/tools1v/env.sh
elif [ -f /home/z/my-project/tools/env.sh ]; then source /home/z/my-project/tools/env.sh
else echo "[1X-GHOST] FATAL: pinned toolchain env.sh not found (K-dependent stages are BLOCKED; LABELCHECK still runs)"; NOTOOLS=1; fi

OUTD=$REPO/phase1x/transcripts/ghost
CLMS=$REPO/phase1x/claims
WORK=$REPO/.1x-work
mkdir -p "$OUTD" "$CLMS" "$WORK"
VCSV=$CLMS/ghost-verdicts-1x.csv
INV=$CLMS/expected-ghost-inventory.json
CHK=$REPO/phase1x/scripts/check_labels_1x.py
CLS=$REPO/phase1x/scripts/classify_1x.py
FAILURES=0
note() { echo "[1X-GHOST] $*"; }
record() { # tag class rc expected observed verdict note
  echo "$1,$2,$3,$4,$5,$6,$7" >> "$VCSV"
  [ "$6" = "OK" ] || { FAILURES=$((FAILURES+1)); note "ASSERTION FAILED: $1 (expected [$4], observed [$5])"; }
}
ACTIVE_TMP=""
cleanup() { [ -n "$ACTIVE_TMP" ] && rm -rf "$ACTIVE_TMP"; }
trap cleanup EXIT INT TERM

rowcount() { wc -l < "$VCSV" | tr -d ' '; }
# Last-wins dedup (1W R14 discipline, automated): staged re-invocations append
# fresh rows for the whole stage; dedup keeps the LAST row per tag so each
# control appears exactly once with its final execution's outcome.
dedup_ledger() {
  python3 - "$VCSV" << 'PYEOF'
import sys
p = sys.argv[1]
rows = [l for l in open(p).read().splitlines() if l.strip()]
last = {}
order = []
for r in rows:
    tag = r.split(",", 1)[0]
    if tag not in last:
        order.append(tag)
    last[tag] = r
open(p, "w").write("".join(last[t] + "\n" for t in order))
PYEOF
}
# Fresh ledger ONCE per invocation (before the stage loop) unless RUN_APPEND=1.
if [ "${RUN_APPEND:-0}" != "1" ] || [ ! -f "$VCSV" ]; then : > "$VCSV"; fi
delta_check() { # <rows-at-stage-start> <expected-stage-rows> <stage-name>
  local GOT=$(( $(rowcount) - $1 ))
  if [ "$GOT" != "$2" ]; then
    note "ASSERTION FAILED: LEDGER-ROW-COUNT ($3 wrote $GOT rows, pinned $2)"; exit 3; fi
}

# classify <tag> <class> <rc> <log> <expected-status> <extra-note>
classify_and_record() {
  local TAG=$1 CLASS=$2 RC=$3 LOG=$4 EXP=$5 EXTRA=$6
  local OUT ST TOP STK BE ERR
  OUT=$(python3 "$CLS" --rc "$RC" --log "$LOG") || { record "$TAG" "$CLASS" "$RC" "rc=? ($EXP)" "classifier-error" FAIL "$EXTRA"; return; }
  ST=$(echo  "$OUT" | sed -n 's/.*status=\([^ ]*\).*/\1/p')
  TOP=$(echo "$OUT" | sed -n 's/.*top=\([0-9]*\).*/\1/p')
  STK=$(echo "$OUT" | sed -n 's/.*stuck=\([0-9]*\).*/\1/p')
  BE=$(echo  "$OUT" | sed -n 's/.*backenderr=\([0-9]*\).*/\1/p')
  local V=OK
  [ "$ST" = "$EXP" ] || { V=FAIL; note "  $TAG: classified $ST, expected $EXP"; }
  if [ "$EXP" = "PROVED" ] && [ "${TOP:-0}" -lt 1 ]; then V=FAIL; note "  $TAG: PROVED without #Top closure marker"; fi
  record "$TAG" "$CLASS" "$RC" "rc=$([ "$EXP" = "PROVED" ] && echo 0 || echo 1) ($EXP)" \
         "rc=$RC #Top=${TOP:-0} stuck=${STK:-0} backenderr=${BE:-0} status=$ST" "$V" "$EXTRA"
}

STAGES=${@:-LABELCHECK GEN KOM MAIN GENSPEC}
for ST in $STAGES; do
case $ST in

LABELCHECK)
note "stage LABELCHECK: splitter output vs pinned inventory (no K required)"
GDIR=$(mktemp -d /tmp/srw3-1x-labelcheck-XXXXXX); ACTIVE_TMP=$GDIR
# main suite
GHOST_CLAIMS_DIR="$GDIR/main" python3 "$REPO/scripts/split_ghost_claims.py" > "$GDIR/main-labels.txt" 2>&1
RC=$?
if [ $RC != 0 ]; then note "ASSERTION FAILED: SPLITTER-EXIT (main suite rc=$RC)"; cat "$GDIR/main-labels.txt"; exit 3; fi
python3 "$CHK" --suite main --labels-file "$GDIR/main-labels.txt" --specs-dir "$GDIR/main" || exit 4
# generalized suites
for SU in cm2_alias cm3_auth gen_full; do
  PRE=$(python3 -c "import json;print(json.load(open('$INV'))['$SU']['obs_module'])")
  ART=$(python3 -c "import json;print(json.load(open('$INV'))['$SU']['artifact'])")
  python3 "$REPO/scripts/split_gen_claims.py" "$REPO/$ART" "$PRE" "$PRE" "$GDIR/gen-$SU" > "$GDIR/$SU-labels.txt" 2>&1
  RC=$?
  if [ $RC != 0 ]; then note "ASSERTION FAILED: SPLITTER-EXIT ($SU rc=$RC)"; cat "$GDIR/$SU-labels.txt"; exit 3; fi
  python3 "$CHK" --suite "$SU" --labels-file "$GDIR/$SU-labels.txt" --specs-dir "$GDIR/gen-$SU" || exit 4
done
note "LABELCHECK: all four suites match the pinned inventory"
;;

GEN)
note "stage GEN: regenerate ghost artifacts from the sources"
python3 "$REPO/scripts/gen_ghost_artifact.py" > "$OUTD/ghost_gen_1x.txt" 2>&1 || {
  note "FATAL: gen_ghost_artifact.py failed"; tail -5 "$OUTD/ghost_gen_1x.txt"; exit 3; }
tail -3 "$OUTD/ghost_gen_1x.txt"

python3 "$REPO/scripts/audit_ghost_exact.py" freeze --force > "$OUTD/ghost_manifest_freeze_1x.txt" 2>&1 || {
  note "FATAL: manifest freeze failed"; tail -5 "$OUTD/ghost_manifest_freeze_1x.txt"; exit 3; }

python3 "$REPO/scripts/audit_ghost_exact.py" verify > "$OUTD/ghost_manifest_verify_1x.txt" 2>&1
VRC=$?
tail -2 "$OUTD/ghost_manifest_verify_1x.txt"
if [ $VRC = 0 ]; then record ghost-exact-fidelity fidelity 0 "rc=0 (PROVED)" "rc=0 status=PROVED" OK "audit_ghost_exact.py verify"
else record ghost-exact-fidelity fidelity "$VRC" "rc=0 (PROVED)" "rc=$VRC status=FAILED" FAIL "audit_ghost_exact.py verify"; fi

python3 "$REPO/scripts/gen_ghost_proofs.py" > "$OUTD/ghost_gen_proofs_1x.txt" 2>&1 || {
  note "FATAL: gen_ghost_proofs.py failed"; tail -5 "$OUTD/ghost_gen_proofs_1x.txt"; exit 3; }
tail -2 "$OUTD/ghost_gen_proofs_1x.txt"
# WS-C: regeneration must be byte-faithful to the committed artifacts —
# sha256 fields invariant; the ONLY permitted tracked change is the manifests'
# environment-absolute "path" fields (the 1W-disclosed, semantics-neutral
# environmental drift; see phase1x/report §GEN). A stage gate, not a ledger
# row — the ledger keeps the historical 48-row shape.
DIRTY=$(git -C "$REPO" status --porcelain proofs/ | awk '{print $2}')
BAD=""
for F in $DIRTY; do
  case "$F" in
    proofs/ghost_manifest.json|proofs/gen/ghost_manifest_gen.json)
      NONPATH=$(git -C "$REPO" diff -U0 -- "$F" | grep -E '^[+-]' | grep -vE '^(\+\+\+|---)' | grep -cv '"path"' || true)
      [ "$NONPATH" != "0" ] && BAD="$BAD $F(non-path-diff)"
      ;;
    *) BAD="$BAD $F";;
  esac
done
if [ -n "$BAD" ]; then
  record ghost-regen-immutability fidelity 1 "rc=0 (PROVED)" "dirty:$BAD" FAIL "regeneration changed tracked proof artifacts beyond manifest path fields"
  note "FATAL: regeneration is not byte-faithful (non-path changes: $BAD)"; exit 3
fi
note "  regen-immutability OK: regenerated artifacts byte-identical; manifest drift confined to path fields"
;;

KOM)
note "stage KOM: kompile the ghost definition"
if [ -n "${NOTOOLS:-}" ]; then note "BLOCKED: pinned toolchain env.sh not found — KOM/MAIN/GENSPEC NOT RUN"; exit 2; fi
rm -rf "$WORK/ghost-out"
timeout 900 kompile "$REPO/proofs/induction_ghost.k" --backend haskell --main-module SRW3-GHOST-OBS -o "$WORK/ghost-out" > "$OUTD/kompile_ghost_1x.log" 2>&1
RC=$?
[ $RC = 0 ] || { note "FATAL: ghost kompile rc=$RC"; tail -5 "$OUTD/kompile_ghost_1x.log"; exit 3; }
note "  ghost definition compiled"
;;

MAIN)
SNAP=$(rowcount)
note "stage MAIN: per-claim ghost battery (isolated kprove runs, status-aware)"
if [ -n "${NOTOOLS:-}" ]; then note "BLOCKED: pinned toolchain env.sh not found — MAIN NOT RUN"; exit 2; fi
GDIR=$(mktemp -d /tmp/srw3-1x-ghost-XXXXXX); ACTIVE_TMP=$GDIR
GHOST_CLAIMS_DIR="$GDIR" python3 "$REPO/scripts/split_ghost_claims.py" > "$GDIR/labels.txt" 2>&1 || {
  note "ASSERTION FAILED: SPLITTER-EXIT (main rc=$?)"; cat "$GDIR/labels.txt"; exit 3; }
# C1: assert the label set BEFORE invoking K
python3 "$CHK" --suite main --labels-file "$GDIR/labels.txt" --specs-dir "$GDIR" || { note "FATAL: label inventory mismatch — battery refused"; exit 4; }
while read -r L EXPST; do
  T0=$(date +%s)
  timeout 1200 kprove "$GDIR/c_$L.k" -d "$WORK/ghost-out" -I "$GDIR" \
    --spec-module "SRW3-GC-$L" > "$OUTD/kpg_1x_$L.log" 2>&1
  E=$?; TS=$(( $(date +%s) - T0 ))
  classify_and_record "ghost-$L" kprove "$E" "$OUTD/kpg_1x_$L.log" "$EXPST" "wall=${TS}s"
done < <(python3 "$CHK" --suite main --emit)
rm -rf "$GDIR"; ACTIVE_TMP=""
delta_check "$SNAP" "$(python3 -c "import json;d=json.load(open('$INV'));print(len(d['main']['labels']))")" "MAIN"
dedup_ledger
;;

GENSPEC)
SNAP=$(rowcount)
note "stage GENSPEC: generalized per-claim batteries (${GS_SUITES:-cm2_alias cm3_auth gen_full})"
if [ -n "${NOTOOLS:-}" ]; then note "BLOCKED: pinned toolchain env.sh not found — GENSPEC NOT RUN"; exit 2; fi
GDIR=$(mktemp -d /tmp/srw3-1x-ghostgen-XXXXXX); ACTIVE_TMP=$GDIR
GS_ALL="cm2_alias:SRW3G2:out-cm2 cm3_auth:SRW3G3:out-cm3 gen_full:SRW3G4:out-gen"
GS_RUN="${GS_SUITES:-cm2_alias cm3_auth gen_full}"
for SPEC in $GS_ALL; do
  SU=$(echo "$SPEC" | cut -d: -f1); PRE=$(echo "$SPEC" | cut -d: -f2); OD=$(echo "$SPEC" | cut -d: -f3)
  case " $GS_RUN " in *" $SU "*) ;; *) note "  skipping $SU (GS_SUITES='$GS_RUN')"; continue;; esac
  ART=$(python3 -c "import json;print(json.load(open('$INV'))['$SU']['artifact'])")
  timeout 900 kompile "$REPO/$ART" --backend haskell --main-module "$PRE-GHOST-OBS" --syntax-module "$PRE-GHOST-OBS" -I "$REPO/k" -o "$WORK/ghost-gen-$OD" > "$OUTD/kompile_gen_$PRE.log" 2>&1
  RC=$?
  if [ $RC != 0 ]; then note "FATAL: gen ghost $PRE kompile rc=$RC"; tail -5 "$OUTD/kompile_gen_$PRE.log"; exit 3; fi
  python3 "$REPO/scripts/split_gen_claims.py" "$REPO/$ART" "$PRE" "$PRE" "$GDIR/gen-$PRE" > "$GDIR/$SU-labels.txt" 2>&1 || {
    note "ASSERTION FAILED: SPLITTER-EXIT ($SU rc=$?)"; cat "$GDIR/$SU-labels.txt"; exit 3; }
  # C1: per-suite label assertion BEFORE the K runs
  python3 "$CHK" --suite "$SU" --labels-file "$GDIR/$SU-labels.txt" --specs-dir "$GDIR/gen-$PRE" || { note "FATAL: $SU label inventory mismatch — battery refused"; exit 4; }
  note "  $PRE claims: $(tr '\n' ' ' < "$GDIR/$SU-labels.txt" | awk '{$1=$1};1')"
  while read -r L EXPST; do
    T0=$(date +%s)
    timeout 3600 kprove "$GDIR/gen-$PRE/${PRE}_${L}.k" -d "$WORK/ghost-gen-$OD" -I "$GDIR/gen-$PRE" -I "$REPO/k" \
      --spec-module "${PRE}-GC-${L}" > "$OUTD/kpg_1x_${PRE}_${L}.log" 2>&1
    E=$?; TS=$(( $(date +%s) - T0 ))
    classify_and_record "ghost-$PRE-$L" kprove "$E" "$OUTD/kpg_1x_${PRE}_${L}.log" "$EXPST" "wall=${TS}s"
  done < <(python3 "$CHK" --suite "$SU" --emit)
done
rm -rf "$GDIR"; ACTIVE_TMP=""
GS_N=$(python3 - "$INV" $GS_RUN << 'PYEOF'
import json, sys
inv = json.load(open(sys.argv[1]))
print(sum(len(inv[s]["labels"]) for s in sys.argv[2:]))
PYEOF
)
delta_check "$SNAP" "$GS_N" "GENSPEC"
dedup_ledger
;;

*) note "unknown stage $ST"; exit 1;;
esac
done
note "ghost battery done: $VCSV"
if [ "$FAILURES" != "0" ]; then note "TOTAL FAILURES: $FAILURES"; exit 1; fi
note "ALL GHOST VERDICTS AS EXPECTED (statuses classified per the 1X vocabulary)"
note "REMINDER: a green runner is not a completeness claim — open obligations remain (verdict PARTIALLY COMPLETE)"
exit 0
