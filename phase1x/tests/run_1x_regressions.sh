#!/bin/bash
# =============================================================================
# SRW3 Phase 1X — the adversarial regression suite (WS-D).
# phase1x/tests/run_1x_regressions.sh
#
# Exercises the 12-case mandate table + the old-runner weakness reproduction
# + the 1X follow-up status-fidelity battery (designed-negative downgrade
# rejection for EVERY NEG row, stripped stuck diagnostics, removed #Top,
# injected [Error], and claim↔transcript identity substitution).
# Mutation-based cases operate ONLY on sandbox copies (fresh git clones of the
# committed Phase 1X branch, or temp-dir fixture copies of ledgers/logs) —
# historical phase1u/1v/1w files and the Phase 1X evidence itself are never
# modified. Cases needing the real toolchain are marked; the suite records
# actual exit codes for every case.
#
# Usage: run_1x_regressions.sh [REPO_ROOT] [FRESH_RUN_DIR]
#   REPO_ROOT     the Phase 1X checkout (default: script's repo)
#   FRESH_RUN_DIR a completed fresh 1X runner evidence dir whose
#                 phase1x/transcripts/ghost/*.log are used for the real-log
#                 classification cases (default: REPO_ROOT itself, i.e. the
#                 in-tree Run A evidence)
# All case output goes to stdout; a per-case PASS/FAIL table is printed at
# the end; nonzero exit if any case fails. Level III only.
# =============================================================================
set -u
HERE=$(cd "$(dirname "$0")" && pwd)
REPO=$(cd "${1:-$HERE/../..}" && pwd)
FRESHRUN=${2:-$REPO}
cd "$REPO" || exit 1

PASS=0; FAIL=0; RESULTS=""
case_result() { # <id> <expected> <observed> <ok 0|1> <detail>
  if [ "$4" = "0" ]; then PASS=$((PASS+1)); RESULTS="$RESULTS
PASS  $1 | expected: $2 | observed: $3 | $5";
  else FAIL=$((FAIL+1)); RESULTS="$RESULTS
FAIL  $1 | expected: $2 | observed: $3 | $5"; fi
}
CHK=$REPO/phase1x/scripts/check_labels_1x.py
CLS=$REPO/phase1x/scripts/classify_1x.py
SUM=$REPO/phase1x/scripts/summarize_1x.py
TD=$(mktemp -d /tmp/srw3-1x-regress-XXXXXX)
trap 'rm -rf "$TD"' EXIT

# ---------------------------------------------------------------- Group 1
# fixtures: fresh splitter outputs (positive) + mutated label files
GDIR=$TD/labels; mkdir -p "$GDIR/main" "$GDIR/cm2" "$GDIR/cm3" "$GDIR/g4"
GHOST_CLAIMS_DIR="$GDIR/main" python3 "$REPO/scripts/split_ghost_claims.py" > "$GDIR/main.txt" 2>&1
python3 "$REPO/scripts/split_gen_claims.py" "$REPO/proofs/gen/cm2_alias.k" SRW3G2 SRW3G2 "$GDIR/cm2" > "$GDIR/cm2.txt" 2>&1
python3 "$REPO/scripts/split_gen_claims.py" "$REPO/proofs/gen/cm3_auth.k" SRW3G3 SRW3G3 "$GDIR/cm3" > "$GDIR/cm3.txt" 2>&1
python3 "$REPO/scripts/split_gen_claims.py" "$REPO/proofs/gen/gen_full.k" SRW3G4 SRW3G4 "$GDIR/g4" > "$GDIR/g4.txt" 2>&1

# R1 baseline expected labels — Accepted (all four suites)
OKALL=0
for SU in main:main cm2_alias:cm2 cm3_auth:cm3 gen_full:g4; do
  S=${SU%%:*}; D=${SU##*:}
  python3 "$CHK" --suite "$S" --labels-file "$GDIR/$D.txt" --specs-dir "$GDIR/$D" > "$GDIR/$D.out" 2>&1 || OKALL=1
done
case_result R1-baseline-labels "Accepted (4 suites rc=0)" "rc=$OKALL" "$OKALL" "$(cat "$GDIR/main.out")"

# R2 main ghost label omitted — Rejected before proof execution, correct reason
tr ' ' '\n' < "$GDIR/main.txt" | grep -v '^GH-M$' | tr '\n' ' ' > "$GDIR/main-omit.txt"
python3 "$CHK" --suite main --labels-file "$GDIR/main-omit.txt" > "$GDIR/r2.out" 2>&1; RC=$?
grep -q "MISSING expected label(s) \['GH-M'\]" "$GDIR/r2.out" && REASON=0 || REASON=1
[ $RC -ne 0 ] && [ $REASON = 0 ] && OK=0 || OK=1
case_result R2-main-label-omitted "Rejected before proofs (MISSING GH-M)" "rc=$RC reason=$REASON" "$OK" "$(head -1 "$GDIR/r2.out")"

# R3 generalized label omitted — Rejected before proof execution
tr ' ' '\n' < "$GDIR/cm2.txt" | grep -v '^GH2-A1$' | tr '\n' ' ' > "$GDIR/cm2-omit.txt"
python3 "$CHK" --suite cm2_alias --labels-file "$GDIR/cm2-omit.txt" > "$GDIR/r3.out" 2>&1; RC=$?
grep -q "MISSING expected label(s) \['GH2-A1'\]" "$GDIR/r3.out" && REASON=0 || REASON=1
[ $RC -ne 0 ] && [ $REASON = 0 ] && OK=0 || OK=1
case_result R3-gen-label-omitted "Rejected before proofs (MISSING GH2-A1)" "rc=$RC reason=$REASON" "$OK" "$(head -1 "$GDIR/r3.out")"

# R4 duplicate label — Rejected with NO-DUPLICATE-LABELS
tr ' ' '\n' < "$GDIR/main.txt" | sed 's/^GH-A$/GH-A\nGH-A/' | tr '\n' ' ' > "$GDIR/main-dup.txt"
python3 "$CHK" --suite main --labels-file "$GDIR/main-dup.txt" > "$GDIR/r4.out" 2>&1; RC=$?
grep -q "NO-DUPLICATE-LABELS" "$GDIR/r4.out" && REASON=0 || REASON=1
[ $RC -ne 0 ] && [ $REASON = 0 ] && OK=0 || OK=1
case_result R4-duplicate-label "Rejected (NO-DUPLICATE-LABELS)" "rc=$RC reason=$REASON" "$OK" "$(head -1 "$GDIR/r4.out")"

# R5 unexpected label — Rejected with UNEXPECTED
tr ' ' '\n' < "$GDIR/main.txt" | sed 's/^GH-A$/NOT-A-CLAIM/' | tr '\n' ' ' > "$GDIR/main-extra.txt"
python3 "$CHK" --suite main --labels-file "$GDIR/main-extra.txt" > "$GDIR/r5.out" 2>&1; RC=$?
grep -q "UNEXPECTED label(s) \['NOT-A-CLAIM'\]" "$GDIR/r5.out" && REASON=0 || REASON=1
[ $RC -ne 0 ] && [ $REASON = 0 ] && OK=0 || OK=1
case_result R5-unexpected-label "Rejected (UNEXPECTED)" "rc=$RC reason=$REASON" "$OK" "$(head -1 "$GDIR/r5.out")"

# R7 splitter returns an empty list — Rejected with SPLITTER-OUTPUT-EMPTY
: > "$GDIR/empty.txt"
python3 "$CHK" --suite main --labels-file "$GDIR/empty.txt" > "$GDIR/r7.out" 2>&1; RC=$?
grep -q "SPLITTER-OUTPUT-EMPTY" "$GDIR/r7.out" && REASON=0 || REASON=1
[ $RC -ne 0 ] && [ $REASON = 0 ] && OK=0 || OK=1
case_result R7-splitter-empty "Rejected (SPLITTER-OUTPUT-EMPTY)" "rc=$RC reason=$REASON" "$OK" "$(head -1 "$GDIR/r7.out")"

# ---------------------------------------------------------------- Group 2
# classification-level cases (the SAME classifier the runner uses)
# R8 success-looking output WITHOUT the closure marker — not classified PROVED
printf 'kprove finished.\nNo closure marker here.\n' > "$GDIR/fake-success.log"
OUT=$(python3 "$CLS" --rc 0 --log "$GDIR/fake-success.log"); ST=$(echo "$OUT" | sed -n 's/.*status=\([^ ]*\).*/\1/p')
[ "$ST" = "INVALID-SUCCESS" ] && OK=0 || OK=1
case_result R8-no-closure-marker "NOT classified PROVED (INVALID-SUCCESS)" "status=$ST" "$OK" "$OUT"
# old GENSPEC behavior contrast: the 1W loop accepted rc=0 with no #Top
E=0; EXP_RC=0; if [ "$E" = "$EXP_RC" ]; then OLDV=OK; else OLDV=FAIL; fi
case_result R8b-old-genspec-would-accept "Old 1W check says OK for the same evidence" "old-check=$OLDV" "0" "run_1w_ghost.sh L138 shape: [ \"\$E\" = \"\$EXP_RC\" ] — the defect C3 fixes"

# R9 GH-T stuck signature (REAL fresh-run log) — classified FAILED-STUCK
GTLOG=$FRESHRUN/phase1x/transcripts/ghost/kpg_1x_GH-T.log
if [ -f "$GTLOG" ]; then
  OUT=$(python3 "$CLS" --rc 1 --log "$GTLOG"); ST=$(echo "$OUT" | sed -n 's/.*status=\([^ ]*\).*/\1/p')
  [ "$ST" = "FAILED-STUCK" ] && OK=0 || OK=1
  case_result R9-gh-t-stuck-signature "FAILED-STUCK from the fresh diagnostic" "status=$ST" "$OK" "$OUT"
else
  case_result R9-gh-t-stuck-signature "FAILED-STUCK from the fresh diagnostic" "NOT RUN (no fresh log at $GTLOG)" "1" "run the fresh 1X battery first"
fi

# R10 genuine designed-negative preserves its expected failure classification
GNLOG=$FRESHRUN/phase1x/transcripts/ghost/kpg_1x_SRW3G2_GH2-NEG.log
if [ -f "$GNLOG" ]; then
  OUT=$(python3 "$CLS" --rc 1 --log "$GNLOG"); ST=$(echo "$OUT" | sed -n 's/.*status=\([^ ]*\).*/\1/p')
  [ "$ST" = "FAILED-STUCK" ] && OK=0 || OK=1
  case_result R10-designed-negative-preserved "FAILED-STUCK, never rc=0" "status=$ST" "$OK" "$OUT"
else
  case_result R10-designed-negative-preserved "FAILED-STUCK, never rc=0" "NOT RUN (no fresh log)" "1" "run the fresh 1X battery first"
fi

# R11 timeout — classified TIMEOUT (classifier path; no 1200s budget burned)
OUT=$(python3 "$CLS" --rc 124 --log "$GDIR/fake-success.log"); ST=$(echo "$OUT" | sed -n 's/.*status=\([^ ]*\).*/\1/p')
[ "$ST" = "TIMEOUT" ] && OK=0 || OK=1
case_result R11-timeout-classification "TIMEOUT (never proof/success)" "status=$ST" "$OK" "$OUT (classifier-level; a real 1200s timeout is deliberately not burned)"

# ---------------------------------------------------------------- Group 4
# gate mutations on SANDBOX COPIES of the real ledgers (never the originals)
if [ -f "$REPO/phase1x/claims/claims-1x.csv" ] && [ -f "$REPO/phase1x/claims/ghost-verdicts-1x.csv" ] && [ -f "$REPO/phase1x/claims/model-verdicts-1x.csv" ]; then
  mkroot() { # $1 = name → fresh fixture root with copies
    R=$TD/$1; mkdir -p "$R/phase1x/claims" "$R/phase1x/transcripts/ghost" "$R/phase1x/transcripts/model"
    cp "$REPO/phase1x/claims/"*.csv "$R/phase1x/claims/" 2>/dev/null
    cp "$REPO/phase1x/transcripts/ghost/"* "$R/phase1x/transcripts/ghost/" 2>/dev/null
    # model rows are the disclosed 1W fixture: link the ACTUAL 1W transcripts
    # read-only so the gate's transcript-presence check is exercised honestly
    for L in "$REPO"/phase1w/transcripts/model/*; do
      [ -e "$L" ] && ln -s "$L" "$R/phase1x/transcripts/model/$(basename "$L")" 2>/dev/null
    done
    echo "$R"; }

  # R15 ghost ledger missing a claim → RED with MISSING reason
  R=$(mkroot r15); grep -v '^ghost-GH-M,' "$R/phase1x/claims/ghost-verdicts-1x.csv" > "$R/g.csv" && mv "$R/g.csv" "$R/phase1x/claims/ghost-verdicts-1x.csv"
  python3 "$SUM" --root "$R" > "$GDIR/r15.out" 2>&1; RC=$?
  grep -q "ghost ledger MISSING expected claim(s): \['ghost-GH-M'\]" "$GDIR/r15.out" && REASON=0 || REASON=1
  [ $RC -ne 0 ] && [ $REASON = 0 ] && OK=0 || OK=1
  case_result R15-gate-missing-claim "GATE RED (MISSING ghost-GH-M)" "rc=$RC reason=$REASON" "$OK" "$(grep -m1 MISSING "$GDIR/r15.out" || echo none)"

  # R16 duplicated row → RED
  R=$(mkroot r16); grep '^ghost-GH-M,' "$REPO/phase1x/claims/ghost-verdicts-1x.csv" >> "$R/phase1x/claims/ghost-verdicts-1x.csv"
  python3 "$SUM" --root "$R" > "$GDIR/r16.out" 2>&1; RC=$?
  grep -q "duplicate tags: \['ghost-GH-M'\]" "$GDIR/r16.out" && REASON=0 || REASON=1
  [ $RC -ne 0 ] && [ $REASON = 0 ] && OK=0 || OK=1
  case_result R16-gate-duplicate-row "GATE RED (duplicate)" "rc=$RC reason=$REASON" "$OK" "$(grep -m1 duplicate "$GDIR/r16.out" || echo none)"

  # R17 substituted row (right count, wrong identity) → RED (missing + duplicate):
  # the substituted tag GH-T2 is itself an EXPECTED tag, so the count-preserving
  # substitution manifests as MISSING ghost-GH-M + DUPLICATE ghost-GH-T2 — both
  # named alarms — while a count-only acceptance would have seen 48 rows and passed
  R=$(mkroot r17)
  python3 - "$R" << 'PYEOF'
import sys
r = sys.argv[1]
p = r + "/phase1x/claims/ghost-verdicts-1x.csv"
lines = open(p).read().splitlines(True)
out = []
for ln in lines:
    if ln.startswith("ghost-GH-M,"):
        out.append(ln.replace("ghost-GH-M,", "ghost-GH-T2,", 1))
    else:
        out.append(ln)
open(p, "w").write("".join(out))
PYEOF
  python3 "$SUM" --root "$R" > "$GDIR/r17.out" 2>&1; RC=$?
  grep -q "MISSING expected claim(s): \['ghost-GH-M'\]" "$GDIR/r17.out" && grep -q "duplicate tags: \['ghost-GH-T2'\]" "$GDIR/r17.out" && REASON=0 || REASON=1
  [ $RC -ne 0 ] && [ $REASON = 0 ] && OK=0 || OK=1
  case_result R17-gate-substituted-row "GATE RED (identity, not just count: MISSING + DUPLICATE)" "rc=$RC reason=$REASON" "$OK" "$(grep -m1 -E 'MISSING|duplicate' "$GDIR/r17.out" || echo none)"

  # R18 model ledger count mutation (45 rows) → RED exactly-46
  R=$(mkroot r18); tail -n +2 "$R/phase1x/claims/model-verdicts-1x.csv" | head -n -1 > "$R/m.csv" && head -1 "$R/phase1x/claims/model-verdicts-1x.csv" > "$R/mm.csv" && cat "$R/mm.csv" "$R/m.csv" > "$R/phase1x/claims/model-verdicts-1x.csv"
  python3 "$SUM" --root "$R" > "$GDIR/r18.out" 2>&1; RC=$?
  grep -q "model ledger: 45 rows, exactly 46 required" "$GDIR/r18.out" && REASON=0 || REASON=1
  [ $RC -ne 0 ] && [ $REASON = 0 ] && OK=0 || OK=1
  case_result R18-gate-model-count "GATE RED (exactly 46, shared set forbidden)" "rc=$RC reason=$REASON" "$OK" "$(grep -m1 'model ledger' "$GDIR/r18.out" || echo none)"

  # R19 designed failure relabelled rc 1→0 → RELABELING ALARM
  R=$(mkroot r19)
  sed -i 's/^ghost-GH-T,kprove,1,/ghost-GH-T,kprove,0,/' "$R/phase1x/claims/ghost-verdicts-1x.csv"
  sed -i 's/^ghost-GH-T,control,1,/ghost-GH-T,control,0,/' "$R/phase1x/claims/claims-1x.csv"
  python3 - "$R" << 'PYEOF'
import sys
r = sys.argv[1]
p = r + "/phase1x/claims/exit-codes-1x.csv"
out = []
for ln in open(p):
    if ln.startswith("ghost-GH-T,"):
        parts = ln.split(",")
        parts[1] = "0"
        out.append(",".join(parts))
    else:
        out.append(ln)
open(p, "w").write("".join(out))
PYEOF
  python3 "$SUM" --root "$R" > "$GDIR/r19.out" 2>&1; RC=$?
  grep -q "RELABELING ALARM" "$GDIR/r19.out" && REASON=0 || REASON=1
  [ $RC -ne 0 ] && [ $REASON = 0 ] && OK=0 || OK=1
  case_result R19-gate-relabel-alarm "GATE RED (RELABELING ALARM)" "rc=$RC reason=$REASON" "$OK" "$(grep -m1 ALARM "$GDIR/r19.out" || echo none)"

  # R20 exit-code mismatch (last-wins) → RED
  R=$(mkroot r20)
  python3 - "$R" << 'PYEOF'
import sys
r = sys.argv[1]
p = r + "/phase1x/claims/exit-codes-1x.csv"
out = []
for ln in open(p):
    if ln.startswith("ghost-GH-BASE,"):
        parts = ln.split(",")
        parts[1] = "7"
        out.append(",".join(parts))
    else:
        out.append(ln)
open(p, "w").write("".join(out))
PYEOF
  python3 "$SUM" --root "$R" > "$GDIR/r20.out" 2>&1; RC=$?
  grep -q "ledger rc=0 != exit-codes last-wins rc=7" "$GDIR/r20.out" && REASON=0 || REASON=1
  [ $RC -ne 0 ] && [ $REASON = 0 ] && OK=0 || OK=1
  case_result R20-gate-exitcode-mismatch "GATE RED (last-wins mismatch + unrecognized rc)" "rc=$RC reason=$REASON" "$OK" "$(grep -m1 'last-wins' "$GDIR/r20.out" || echo none)"

  # R21 missing transcript → RED
  R=$(mkroot r21); rm -f "$R/phase1x/transcripts/ghost/kpg_1x_GH-BASE.log"
  python3 "$SUM" --root "$R" > "$GDIR/r21.out" 2>&1; RC=$?
  grep -q "ghost-GH-BASE: no retained Phase 1X transcript" "$GDIR/r21.out" && REASON=0 || REASON=1
  [ $RC -ne 0 ] && [ $REASON = 0 ] && OK=0 || OK=1
  case_result R21-gate-missing-transcript "GATE RED (no transcript)" "rc=$RC reason=$REASON" "$OK" "$(grep -m1 'no retained' "$GDIR/r21.out" || echo none)"

  # R22 GH-T status downgraded to generic FAILED → RED (R5 preservation)
  R=$(mkroot r22)
  sed -i 's/ghost-GH-T,kprove,1,rc=1 (FAILED-STUCK),rc=1 #Top=0 stuck=1 backenderr=1 status=FAILED-STUCK/ghost-GH-T,kprove,1,rc=1 (FAILED-STUCK),rc=1 #Top=0 stuck=0 backenderr=0 status=FAILED/' "$R/phase1x/claims/ghost-verdicts-1x.csv"
  python3 "$SUM" --root "$R" > "$GDIR/r22.out" 2>&1; RC=$?
  grep -q "ghost-GH-T: observed status 'FAILED', the evidence-based classification is FAILED-STUCK" "$GDIR/r22.out" && REASON=0 || REASON=1
  [ $RC -ne 0 ] && [ $REASON = 0 ] && OK=0 || OK=1
  case_result R22-gate-gh-t-status "GATE RED (FAILED-STUCK preserved specifically)" "rc=$RC reason=$REASON" "$OK" "$(grep -m1 'FAILED-STUCK' "$GDIR/r22.out" | head -1 || echo none)"

  # ---------------------------------------------------------------- 1X follow-up
  # WS-A status-fidelity battery: the gate must recompute per-claim statuses
  # from the RAW transcripts and reject downgrades, stripped diagnostics,
  # injected errors, and identity substitutions — per claim, not just GH-T.
  # R23–R26: every designed-negative FAILED-STUCK row downgraded to the
  # coarse FAILED (observed field rewritten, stuck/backenderr zeroed, rc
  # kept at 1) is REJECTED by the status-triple AND the four-way recompute.
  IDX=23
  for TAG in ghost-GH-T2-NEG ghost-SRW3G2-GH2-NEG ghost-SRW3G3-GH3-NEG ghost-SRW3G4-GH4-NEG; do
    R=$(mkroot "rd$IDX")
    sed -i "s|^$TAG,kprove,1,rc=1 (FAILED-STUCK),rc=1 #Top=0 stuck=1 backenderr=1 status=FAILED-STUCK,|$TAG,kprove,1,rc=1 (FAILED-STUCK),rc=1 #Top=0 stuck=0 backenderr=0 status=FAILED,|" "$R/phase1x/claims/ghost-verdicts-1x.csv"
    python3 "$SUM" --root "$R" > "$GDIR/rd$IDX.out" 2>&1; RC=$?
    grep -q "STATUS TRIPLE MISMATCH" "$GDIR/rd$IDX.out" && grep -q "FOUR-WAY INCONSISTENCY" "$GDIR/rd$IDX.out" && REASON=0 || REASON=1
    [ $RC -ne 0 ] && [ $REASON = 0 ] && OK=0 || OK=1
    case_result "R$IDX-neg-downgrade-rejected" "GATE RED ($TAG FAILED-STUCK->FAILED downgrade rejected)" "rc=$RC reason=$REASON" "$OK" "$(grep -m1 'TRIPLE MISMATCH' "$GDIR/rd$IDX.out" || echo none)"
    IDX=$((IDX+1))
  done

  # R27: the GH-T RAW transcript with the stuck diagnostics stripped can no
  # longer support the recorded FAILED-STUCK — the gate must refuse it.
  R=$(mkroot r27)
  sed -i '/WarnStuckClaimState/d; /backend terminated/d' "$R/phase1x/transcripts/ghost/kpg_1x_GH-T.log"
  python3 "$SUM" --root "$R" > "$GDIR/r27.out" 2>&1; RC=$?
  grep -q "FOUR-WAY INCONSISTENCY — transcript recompute at rc=1 says FAILED " "$GDIR/r27.out" && REASON=0 || REASON=1
  [ $RC -ne 0 ] && [ $REASON = 0 ] && OK=0 || OK=1
  case_result R27-gh-t-log-stripped "GATE RED (stuck diagnostics stripped -> recompute FAILED)" "rc=$RC reason=$REASON" "$OK" "$(grep -m1 'FOUR-WAY' "$GDIR/r27.out" || echo none)"

  # R28: a PROVED transcript with #Top removed is INVALID-SUCCESS — refused.
  R=$(mkroot r28)
  sed -i 's/#Top//g' "$R/phase1x/transcripts/ghost/kpg_1x_GH-A.log"
  python3 "$SUM" --root "$R" > "$GDIR/r28.out" 2>&1; RC=$?
  grep -q "FOUR-WAY INCONSISTENCY — transcript recompute at rc=0 says INVALID-SUCCESS" "$GDIR/r28.out" && REASON=0 || REASON=1
  [ $RC -ne 0 ] && [ $REASON = 0 ] && OK=0 || OK=1
  case_result R28-success-log-no-top "GATE RED (#Top removed -> INVALID-SUCCESS)" "rc=$RC reason=$REASON" "$OK" "$(grep -m1 'FOUR-WAY' "$GDIR/r28.out" || echo none)"

  # R29: a PROVED transcript with an injected [Error] line is refused.
  R=$(mkroot r29)
  echo '[Error] injected-by-regression-control' >> "$R/phase1x/transcripts/ghost/kpg_1x_GH-A.log"
  python3 "$SUM" --root "$R" > "$GDIR/r29.out" 2>&1; RC=$?
  grep -q "FOUR-WAY INCONSISTENCY — transcript recompute at rc=0 says INVALID-SUCCESS" "$GDIR/r29.out" && REASON=0 || REASON=1
  [ $RC -ne 0 ] && [ $REASON = 0 ] && OK=0 || OK=1
  case_result R29-success-log-error-injected "GATE RED ([Error] injected -> INVALID-SUCCESS)" "rc=$RC reason=$REASON" "$OK" "$(grep -m1 'FOUR-WAY' "$GDIR/r29.out" || echo none)"

  # R30: claim/transcript IDENTITY substitution (GH-A and GH-BASE transcripts
  # swapped) — classifications would still match, the identity binding must
  # catch it: each transcript must carry ITS OWN per-claim spec filename.
  R=$(mkroot r30)
  cp "$R/phase1x/transcripts/ghost/kpg_1x_GH-A.log" "$GDIR/swap-a.log"
  cp "$R/phase1x/transcripts/ghost/kpg_1x_GH-BASE.log" "$R/phase1x/transcripts/ghost/kpg_1x_GH-A.log"
  cp "$GDIR/swap-a.log" "$R/phase1x/transcripts/ghost/kpg_1x_GH-BASE.log"
  python3 "$SUM" --root "$R" > "$GDIR/r30.out" 2>&1; RC=$?
  NIDENT=$(grep -c "IDENTITY MISMATCH" "$GDIR/r30.out" || true)
  [ $RC -ne 0 ] && [ "${NIDENT:-0}" -ge 2 ] && OK=0 || OK=1
  case_result R30-identity-mismatch "GATE RED (swapped transcripts caught by identity, >=2 alarms)" "rc=$RC identity-alarms=$NIDENT" "$OK" "$(grep -m1 'IDENTITY MISMATCH' "$GDIR/r30.out" || echo none)"

else
  for C in R15 R16 R17 R18 R19 R20 R21 R22 R23 R24 R25 R26 R27 R28 R29 R30; do
    case_result "$C-gate-mutation" "GATE RED (fixture mutation)" "NOT RUN (real ledgers not built yet)" "1" "run after the fresh battery + build_ledgers_1x.py"
  done
fi

# ---------------------------------------------------------------- Group 3
# runner-level cases in a SANDBOX clone (real runner code, mutated inputs)
SB=$TD/sandbox
git clone -q --no-hardlinks "$REPO" "$SB" 2>/dev/null && git -C "$SB" checkout -q phase1x-ghost-runner-hardening 2>/dev/null
if [ -f "$SB/phase1x/proofs/run_1x_ghost.sh" ]; then
  # R14/R13: stub splitter omitting GH-M → new runner LABELCHECK refuses BEFORE K
  python3 - "$SB" << 'PYEOF'
import sys
p = sys.argv[1] + "/scripts/split_ghost_claims.py"
s = open(p).read()
s = s.replace('print(" ".join(labels))',
              'labels = [l for l in labels if l != "GH-M"]\nprint(" ".join(labels))')
open(p, "w").write(s)
PYEOF
  bash "$SB/phase1x/proofs/run_1x_ghost.sh" LABELCHECK > "$GDIR/r14.out" 2>&1; RC=$?
  grep -q "MISSING expected label(s) \['GH-M'\]" "$GDIR/r14.out" && REASON=0 || REASON=1
  [ $RC -ne 0 ] && [ $REASON = 0 ] && OK=0 || OK=1
  case_result R14-runner-refuses-short-splitter "Runner exits nonzero BEFORE any K proof" "rc=$RC reason=$REASON" "$OK" "$(grep -m1 MISSING "$GDIR/r14.out" || echo none)"

  # R13/R6: stub splitter exiting 1 → runner SPLITTER-EXIT failure
  printf 'import sys\nsys.exit(1)\n' > "$SB/scripts/split_ghost_claims.py"
  bash "$SB/phase1x/proofs/run_1x_ghost.sh" LABELCHECK > "$GDIR/r13.out" 2>&1; RC=$?
  grep -q "ASSERTION FAILED: SPLITTER-EXIT" "$GDIR/r13.out" && REASON=0 || REASON=1
  [ $RC -ne 0 ] && [ $REASON = 0 ] && OK=0 || OK=1
  case_result R13-runner-splitter-failure "Runner fails the stage (SPLITTER-EXIT)" "rc=$RC reason=$REASON" "$OK" "$(grep -m1 'SPLITTER-EXIT' "$GDIR/r13.out" || echo none)"
  rm -rf "$SB"

  # R12 old-runner weakness: UNMODIFIED historical runner + short splitter exits GREEN
  SB2=$TD/sandbox2
  git clone -q --no-hardlinks "$REPO" "$SB2" 2>/dev/null && git -C "$SB2" checkout -q phase1x-ghost-runner-hardening 2>/dev/null
  mkdir -p "$SB2/phase1w/proofs" "$SB2/phase1w/claims"
  git -C "$SB2" show 34ef2321f2875682bd03adf7eb5f601e256cf7ad:phase1w/proofs/run_1w_ghost.sh > "$SB2/phase1w/proofs/run_1w_ghost.sh" 2>/dev/null
  python3 - "$SB2" << 'PYEOF'
import sys
p = sys.argv[1] + "/scripts/split_ghost_claims.py"
s = open(p).read()
s = s.replace('print(" ".join(labels))',
              'labels = [l for l in labels if l != "GH-M"]\nprint(" ".join(labels))')
open(p, "w").write(s)
PYEOF
  if [ -f "$SB2/phase1w/proofs/run_1w_ghost.sh" ]; then
    # Replicate the 1W-session invocation conditions faithfully: the historical
    # runner (34ef232) predates the 1X runner's LD_LIBRARY_PATH set-u guard, and
    # the 1W session always sourced the toolchain env.sh in the SHELL before
    # invoking it. Without the pre-source the historical runner dies at the
    # env.sh source (unbound LD_LIBRARY_PATH under set -u) BEFORE any stage —
    # an environment artifact, not the claim-count defect under demonstration.
    export LD_LIBRARY_PATH="${LD_LIBRARY_PATH:-}"
    if   [ -n "${KTOOLS:-}" ] && [ -f "$KTOOLS/env.sh" ]; then source "$KTOOLS/env.sh"
    elif [ -f /home/z/my-project/tools1v/env.sh ]; then source /home/z/my-project/tools1v/env.sh
    elif [ -f /home/z/my-project/tools/env.sh ]; then source /home/z/my-project/tools/env.sh
    else case_result R12-old-runner-weakness "defect demonstration" "NOT RUN (toolchain env.sh unavailable)" "1" "" ; fi
    if [ -n "${KROOT:-}" ]; then
    # Fresh-ledger condition (as on a pristine 1W checkout): the historical
    # runner has NO per-invocation truncation (its record() blindly appends —
    # the 1X runner truncates once per invocation AND pins per-stage row
    # counts), so the committed 1W ledger must be removed or the appended
    # battery would be indistinguishable from history.
    rm -f "$SB2/phase1w/claims/ghost-verdicts-1w.csv"
    bash "$SB2/phase1w/proofs/run_1w_ghost.sh" KOM MAIN > "$GDIR/r12.out" 2>&1; RC=$?
    ROWS=$(wc -l < "$SB2/phase1w/claims/ghost-verdicts-1w.csv" 2>/dev/null || echo 0)
    GREEN=$(grep -c "ALL GHOST VERDICTS AS EXPECTED" "$GDIR/r12.out" || true)
    # the weakness: green exit + 11 rows (a claim silently missing)
    if [ "$RC" = "0" ] && [ "$ROWS" = "11" ] && [ "${GREEN:-0}" -ge 1 ]; then OK=0; else OK=1; fi
    case_result R12-old-runner-weakness "OLD runner exits GREEN with 11/12 claims (defect shown)" "rc=$RC rows=$ROWS green=$GREEN" "$OK" "unmodified run_1w_ghost.sh @34ef232 + splitter dropping GH-M; all writes sandbox-local"
    # the fix: the NEW runner on the SAME stub refuses
    python3 - "$SB2" << 'PYEOF'
import sys
p = sys.argv[1] + "/scripts/split_ghost_claims.py"
s = open(p).read()
s = s.replace('print(" ".join(labels))',
              'labels = [l for l in labels if l != "GH-M"]\nprint(" ".join(labels))')
open(p, "w").write(s)
PYEOF
    bash "$SB2/phase1x/proofs/run_1x_ghost.sh" LABELCHECK > "$GDIR/r12b.out" 2>&1; RC=$?
    [ $RC -ne 0 ] && OK=0 || OK=1
    case_result R12b-new-runner-same-stub "NEW runner refuses the same input" "rc=$RC" "$OK" "$(grep -m1 'MISSING' "$GDIR/r12b.out" || echo none)"
    fi   # KROOT available (the R12 toolchain-replication block)
    rm -rf "$SB2"
  else
    case_result R12-old-runner-weakness "defect demonstration" "NOT RUN (historical script unavailable)" "1" ""
  fi
else
  case_result R12-old-runner-weakness "defect demonstration" "NOT RUN (branch not committed yet — sandbox clone lacks phase1x/)" "1" "commit the branch, then rerun"
  case_result R13-runner-splitter-failure "Runner fails the stage" "NOT RUN" "1" "commit the branch, then rerun"
  case_result R14-runner-refuses-short-splitter "Runner refuses before K" "NOT RUN" "1" "commit the branch, then rerun"
fi

echo "================================================================"
echo "Phase 1X regression suite — $PASS PASS / $FAIL FAIL"
echo -n "$RESULTS" | cut -c1-170
echo "================================================================"
[ $FAIL = 0 ] && exit 0 || exit 1
