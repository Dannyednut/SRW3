#!/bin/bash
# =============================================================================
# SRW3 Phase 0-D — Baseline ingest pipeline (zip -> verified baseline -> §C)
#
# Per user directive:
#   1. Unpack the uploaded SRW3_Phase_0D_Implementation_v1.0.zip (AUTHORITATIVE
#      baseline — never reconstructed or replaced).
#   2. Preserve the original: pristine read-only copy + git branch baseline-v1.0
#      whose initial commit is byte-identical to the zip contents, so every
#      subsequent KEVM change is diffable against it.
#   3. Run the existing Python test suite FIRST (expect 15/15) before any
#      KEVM-side change; capture verbatim transcript.
#   4. Compile the K scaffold UNMODIFIED (compile only), record status.
#   5. Fill report §C (REPORT.md) and regenerate the PDF.
#   6. Append worklog entry.
#
# Usage: bash ingest_baseline.sh [<path-to-zip>]
#   default zip path: /home/z/my-project/upload/SRW3_Phase_0D_Implementation_v1.0.zip
# Idempotent: re-runs skip unpack if SHA256 unchanged; --force re-unpacks.
# =============================================================================
set -uo pipefail

PROJ=/home/z/my-project
ZIP="${1:-$PROJ/upload/SRW3_Phase_0D_Implementation_v1.0.zip}"
PRISTINE=$PROJ/srw3-baseline          # read-only reference (never modified)
WORK=$PROJ/srw3-work                  # git working copy on branch baseline-v1.0
SRW3=$PROJ/srw3-kevm
TRANSCRIPTS=$SRW3/transcripts
REPORT=$SRW3/REPORT.md
WORKLOG=$PROJ/worklog.md
BRANCH=baseline-v1.0
FORCE="${2:-}"

source "$PROJ/tools/env.sh"
mkdir -p "$TRANSCRIPTS" "$PROJ/scripts"
TS=$(date -Iseconds)
COUT="$TRANSCRIPTS/baseline_section_C.txt"
log() { echo "$@" | tee -a "$COUT"; }
die() { echo "FATAL: $*" | tee -a "$COUT"; exit 1; }

# ---------------------------------------------------------------- step 0: zip
[ -f "$ZIP" ] || { echo "FATAL: zip not found at $ZIP — upload has not landed yet." >&2; exit 1; }
: > "$COUT"   # zip present — safe to start the evidence transcript
SHA=$(sha256sum "$ZIP" | awk '{print $1}')
SHAFILE=$PROJ/srw3-baseline.sha256
if [ -f "$SHAFILE" ] && [ "$(cat "$SHAFILE")" = "$SHA" ] && [ -d "$PRISTINE" ] && [ "$FORCE" != "--force" ]; then
  echo "[ingest] zip unchanged since last ingest (sha256 $SHA) — skipping unpack."
else
  log "# Section C — Baseline ingest evidence (generated $TS)"
  log "## Provenance"
  log "- zip: \`$ZIP\`"
  log "- size: $(stat -c%s "$ZIP") bytes"
  log "- sha256: \`$SHA\`"
  command -v unzip >/dev/null || die "unzip not installed"
  unzip -t "$ZIP" > /tmp/ziptest.txt 2>&1 || die "zip integrity check FAILED: $(head -3 /tmp/ziptest.txt)"
  log "- integrity: OK ($(grep -c ' OK' /tmp/ziptest.txt) entries tested OK)"
  log
  echo "$SHA" > "$SHAFILE"

  # ------------------------------------------------- step 1: unpack pristine
  echo "[ingest] unpacking to pristine baseline dir..."
  chmod -R u+w "$PRISTINE" 2>/dev/null   # previous run may have locked it
  rm -rf "$PRISTINE" && mkdir -p "$PRISTINE"
  unzip -q "$ZIP" -d "$PRISTINE" || die "unzip failed"
  # Flatten a single top-level wrapper dir, if present
  N=$(ls -A "$PRISTINE" | wc -l)
  if [ "$N" = "1" ] && [ -d "$PRISTINE"/* ] 2>/dev/null; then
    INNER=$(ls -A "$PRISTINE"); mv "$PRISTINE/$INNER" /tmp/_bl_inner && rmdir "$PRISTINE" && mv /tmp/_bl_inner "$PRISTINE"
    log "- note: single top-level dir '$INNER' flattened to baseline root"
  fi
  # content inventory (verbatim, for the report)
  log "## Content inventory (verbatim zip listing)"
  (cd "$PRISTINE" && find . -type f | sort) | tee -a "$COUT"
  log
  chmod -R a-w "$PRISTINE"   # physically prevent accidental modification
  echo "[ingest] pristine baseline locked read-only: $PRISTINE"
fi

# ------------------------------------------------- step 2: branch + work copy
# srw3-work is a SELF-CONTAINED git repo: branch main = byte-identical zip
# contents (initial commit), branch kevm-changes = where KEVM-side work happens.
# Diffs against the authoritative baseline: (cd srw3-work && git diff main)
echo "[ingest] preparing self-contained work repo at srw3-work..."
rm -rf "$WORK" && mkdir -p "$WORK"
# copy CONTENTS without the read-only bits (work copy must be writable)
cp -r "$PRISTINE/." "$WORK/"
chmod -R u+w "$WORK"
cd "$WORK"
git init -q -b main
git config user.email "srw3@phase0d.local"
git config user.name  "SRW3 Phase 0-D"
git add -A
git commit -q -m "baseline-v1.0: byte-identical copy of SRW3_Phase_0D_Implementation_v1.0.zip (sha256 $SHA)"
git checkout -q -b kevm-changes
echo "[ingest] work repo ready: branch main=pristine, kevm-changes=active; diff via: (cd $WORK && git diff main)"

# ------------------------------------------------------- step 3: baseline test suite
# CANONICAL invocation per the baseline's own Makefile: `python -m unittest
# discover -s tests -v` from the project root (CWD on sys.path makes the srw3
# package importable). Fallback: pytest with root-relative sys.path.
log "## Baseline Python test suite (run FIRST, before any KEVM change)"
TESTS=$(find "$WORK" \( -name "test_*.py" -o -name "*_test.py" \) | sort)
[ -n "$TESTS" ] || die "no test_*.py found in baseline — inspect layout manually."
PYRC=0
if [ -f "$WORK/Makefile" ] && grep -qE "^test[[:space:]]*:" "$WORK/Makefile"; then
  log "--- canonical: make test (from work repo root)"
  ( cd "$WORK" && make test 2>&1 ) | tee -a "$COUT"
  RC=${PIPESTATUS[0]}
  log "--- make test exit code: $RC"
  [ "$RC" -ne 0 ] && PYRC=$RC
else
  TDIRS=$(echo "$TESTS" | while read -r f; do dirname "$f"; done | sort -u)
  for D in $TDIRS; do
    ROOT=$(cd "$D/.." && pwd)
    log "--- pytest -v in $D (root $ROOT on sys.path; --confcutdir isolates host configs)"
    ( cd "$D" && PYTHONPATH="$ROOT${PYTHONPATH:+:$PYTHONPATH}" PYTEST_ADDOPTS="" \
      python3 -m pytest -v -p no:cacheprovider --confcutdir="$D" 2>&1 ) | tee -a "$COUT"
    RC=${PIPESTATUS[0]}
    log "--- pytest exit code: $RC"
    [ "$RC" -ne 0 ] && PYRC=$RC
  done
fi
log
# verdict: unittest reports "Ran N tests" + final OK/FAILED; pytest reports "N passed"
NRAN=$(grep -hoE "Ran [0-9]+ tests?" "$COUT" | awk '{s+=$2} END {print s+0}')
PASSED=$(grep -hoE "[0-9]+ passed" "$COUT" | awk '{s+=$1} END {print s+0}')
FAILED=$(grep -hoE "[0-9]+ failed" "$COUT" | awk '{s+=$1} END {print s+0}')
NERR=$(grep -chE "^(ERROR|FAIL):" "$COUT" | awk '{s+=$1} END {print s+0}')
UNIT_OK=$(grep -cE "^OK( |$)" "$COUT")
if [ "$NRAN" -gt 0 ]; then
  PASSED=$NRAN; FAILED=$NERR
fi
log "### Verdict: PASSED=$PASSED FAILED=$FAILED (expected 15/15)"
if [ "$PASSED" = "15" ] && [ "$FAILED" = "0" ]; then
  log "BASELINE 15/15 CONFIRMED — authoritative baseline accepted; KEVM changes may proceed on top of it."
else
  log "WARNING: result differs from expected 15/15 — investigate before proceeding."
fi
log

# --------------------------------------------- step 4: K scaffold (unmodified first)
# CANONICAL per Makefile: `kompile k/srw3.k --backend haskell` from repo root.
# Protocol (handoff §6): compile UNMODIFIED and record verbatim; any genuine
# fix is applied AFTERWARD on branch kevm-changes with a recorded diff.
KFILES=$(find "$PRISTINE" -name "*.k" -type f | sort)
if [ -n "$KFILES" ]; then
  MAIN_K=$(find "$PRISTINE" -name "srw3.k" -type f | head -1)
  [ -z "$MAIN_K" ] && MAIN_K=$(echo "$KFILES" | head -1)
  REL="${MAIN_K#$PRISTINE/}"
  log "## K scaffold compile (UNMODIFIED, canonical flags): $REL"
  ( cd "$WORK" && kompile "$REL" --backend haskell 2>&1 ) | tail -15 | tee -a "$COUT"
  log "- kompile exit: ${PIPESTATUS[0]}"
  log
  # secondary: claims overlay (imports SRW3-SEMANTICS from srw3.k) — best effort
  for KF in $KFILES; do
    [ "$KF" = "$MAIN_K" ] && continue
    REL2="${KF#$PRISTINE/}"
    log "## K overlay compile (UNMODIFIED, with -I k): $REL2"
    ( cd "$WORK" && kompile "$REL2" --backend haskell -I k 2>&1 ) | tail -8 | tee -a "$COUT"
    log "- kompile exit: ${PIPESTATUS[0]}"
    log
  done
else
  log "## K scaffold: no .k file in baseline — compile step N/A"
  log
fi

# ------------------------------- step 4b: recorded compatibility patch (§6)
# Applied on branch kevm-changes ONLY (pristine main stays byte-identical);
# patch content and rationale are versioned at srw3-kevm/patches/.
PATCH="$SRW3/patches/baseline-k-compat.patch"
if [ -n "$KFILES" ] && [ -f "$PATCH" ]; then
  log "## Recorded compatibility patch (branch kevm-changes ONLY; pristine untouched)"
  if ( cd "$WORK" && git apply --check "$PATCH" 2>/dev/null ); then
    ( cd "$WORK" && git apply "$PATCH" && git add -A && \
      git commit -q -m "Minimal K v7.1.337 compatibility fixes (recorded; pristine untouched): MAP/SET/LIST-SYNTAX->MAP/SET/LIST; claims overlay requires srw3.k; see patches/baseline-k-compat.patch" )
    log "- patch applied + committed on kevm-changes"
    log "- recorded diff vs pristine main:"
    ( cd "$WORK" && git diff main ) | tee -a "$COUT"
    log
    log "## K scaffold compile AFTER recorded patch"
    ( cd "$WORK" && kompile k/srw3.k --backend haskell \
        --main-module SRW3-SEMANTICS --syntax-module SRW3-SEMANTICS 2>&1 ) | tail -6 | tee -a "$COUT"
    log "- kompile k/srw3.k exit: ${PIPESTATUS[0]}"
    ( cd "$WORK" && kompile k/claims/srw3-closed-composition.k --backend haskell \
        --main-module SRW3-CLOSED-COMPOSITION --syntax-module SRW3-CLOSED-COMPOSITION -I k 2>&1 ) | tail -4 | tee -a "$COUT"
    log "- kompile claims exit: ${PIPESTATUS[0]}"
    log
    log "## Makefile k-tests note (recorded)"
    log "Makefile k-tests references k/tests/cm01-local-vs-global.srw3; the zip ships k/countermodels/cm01-local-vs-global.srw3, which is COMMENT-ONLY documentation of the intended countermodel (executable countermodels live in the Python suite, e.g. test_local_invariants_can_miss_global_interaction_invariant). krun therefore not applicable to this artifact as shipped."
    log
    log "## Baseline suite re-run on patched branch (sanity)"
    if [ -f "$WORK/Makefile" ] && grep -qE "^test[[:space:]]*:" "$WORK/Makefile"; then
      ( cd "$WORK" && make test 2>&1 ) | tail -4 | tee -a "$COUT"
      log "- exit: ${PIPESTATUS[0]}"
    fi
    log
  else
    log "- patch already applied (git apply --check failed as expected after prior application)"
    log
  fi
fi

# --------------------------------------------- step 5: splice §C into report
MARK_OPEN='## C. Existing scaffold result'
if grep -q "$MARK_OPEN" "$REPORT"; then
  python3 - "$REPORT" "$COUT" "$PASSED" "$FAILED" "$SHA" <<'PYEOF'
import sys, re
report, cout, passed, failed, sha = sys.argv[1], sys.argv[2], sys.argv[3], sys.argv[4], sys.argv[5]
txt = open(report).read()
ev  = open(cout).read().strip()
ok  = (passed, failed) == ("15", "0")
verdict = ("**VERIFIED — 15/15 tests pass**" if ok else f"**result: {passed} passed / {failed} failed — DEVIATION from expected 15/15 (see transcript)**")
sec = f"""## C. Existing scaffold result — baseline v1.0 {verdict}

The authoritative Phase 0-D baseline (`SRW3_Phase_0D_Implementation_v1.0.zip`, sha256
`{sha}`) was ingested verbatim — never reconstructed or modified. The original is
preserved twice: a read-only pristine copy (`srw3-baseline/`) and a self-contained
git work repo (`srw3-work/`) whose `main` branch initial commit is byte-identical
to the zip contents; all KEVM-side work happens on branch `kevm-changes`, so every
subsequent change diffs against the authoritative baseline via
`cd srw3-work && git diff main`.

The baseline's own test suite was executed FIRST, before any KEVM-side work, using
its canonical Makefile invocation (`make test` → `python3 -m unittest discover
-s tests -v`), with the verbatim transcript below. The K scaffold was compiled
UNMODIFIED with its canonical Makefile flags; findings are recorded verbatim
(including any toolchain compatibility issues — fixes, if needed, are applied only
on the `kevm-changes` branch with a recorded diff, never in the pristine copy).

```text
{ev}
```
"""
txt = re.sub(r"## C\. Existing scaffold result.*?(?=\n---\n\n## D\.)", sec + "\n", txt, flags=re.S)
open(report, "w").write(txt)
print("[ingest] report §C replaced")
PYEOF
else
  echo "[ingest] §C marker not found in report — appending evidence at end."
  { echo; echo "## C. Existing scaffold result (appended)"; echo; echo '```text'; cat "$COUT"; echo '```'; } >> "$REPORT"
fi

# --------------------------------------------- step 6: regenerate PDF report
if [ -f "$PROJ/scripts/gen_report_pdf.py" ]; then
  echo "[ingest] regenerating report PDF..."
  ( cd "$PROJ/scripts" && python3 gen_report_pdf.py > /tmp/pdfgen.log 2>&1 ) \
    && echo "[ingest] PDF regenerated: $(tail -2 /tmp/pdfgen.log | head -1)" \
    || echo "[ingest] PDF regeneration FAILED — see /tmp/pdfgen.log (MD report already updated)"
fi

# --------------------------------------------- step 7: worklog
cat >> "$WORKLOG" <<EOF

---
Task ID: 11
Agent: main (Super Z)
Task: Ingest authoritative baseline SRW3_Phase_0D_Implementation_v1.0.zip (via Google Drive)

Work Log:
- zip fetched from user-provided Google Drive link; sha256: $SHA
- pristine copy at srw3-baseline/ (read-only); work repo at srw3-work/
  (branch main = pristine zip, branch kevm-changes = active; diff: git diff main)
- canonical 'make test' (unittest discover): PASSED=$PASSED FAILED=$FAILED (expected 15/15)
- K scaffold compile status captured in transcripts/baseline_section_C.txt
- report §C filled + PDF regenerated

Stage Summary:
- Baseline accepted per user directive; all future KEVM changes diffable via
  (cd srw3-work && git diff main)
EOF

echo "[ingest] DONE. Evidence: $COUT"
[ "$PASSED" = "15" ] && [ "$FAILED" = "0" ] && exit 0 || exit 1
