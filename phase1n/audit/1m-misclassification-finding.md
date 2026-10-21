# SRW3 Phase 1N — audit: the 1M universal-side claims were trivially
# provable (the WarnTrivialClaim misclassification of record)

**Finding 1N-F1.**  The Phase 1M rollup (`phase1m/transcripts/k/
claims-status-1m.csv` and the Workstream-D commit message of record)
classifies `MD-INV-ALLPATH-REACHABILITY` and `MD-INV-COMMITTED-PREFIX-SAFE`
as `FAILED(rc=1)` "genuine failed attempts" (the universal theorem's
composition and its prefix corollary).  The LOGS OF RECORD say otherwise:

* `kprove_MD-INV-ALLPATH-REACHABILITY.log` (lines 1-3):
  `Warning (WarnTrivialClaim): Claim proven without rewriting at
  md_proofs.k:186:5-196:81` followed by `#Top` — the claim closed with NO
  rewriting.  The non-warning content of the whole 650-line log is exactly
  that pair.
* `kprove_MD-INV-COMMITTED-PREFIX-SAFE.log`: the same signature
  (`md_proofs.k:201:5-205:51`, `#Top`).

**Why the claims closed trivially.**  Both claims state `RUN => RUN` (the
destination identical to the source) with the safety conclusion ALREADY
inside the hypothesis (`JInvJ` contains `SafeJ`; the prefix claim's
requires contains `SafeJ(P,S) ==K true` directly).  An implication whose
destination is its hypothesis closes vacuously.

**Why the CSV says rc=1.**  kprove exits nonzero on a trivially-proven
claim (the WarnTrivialClaim path), so the runner's exit-code discipline
recorded `FAILED(rc=1)`.  The classification is therefore mechanically
consistent but SEMANTICALLY misleading: the universal composition was
never genuinely attempted at the kore level; the claim SHAPE was wrong.

**Disposition.**  Nothing in the frozen 1M tree is modified (the frozen-
tree verification of record covers this file).  The 1M honest disposition
("the universal theorem is NOT MECHANIZED") STANDS — a fortiori.  What
changes is the diagnosis: the 1M composition boundary was not (only) the
B5/B5'/B2 prover boundaries; the ALLPATH claim as stated never reached
them.  Phase 1N's `ABS-UNIV-STEP`/`-TAIL`/`ABS-PREFIX-SAFE` residuals are
the FIRST genuine composition-attempt residuals of the project, and 1N's
runner enforces the WarnTrivialClaim guard so the misclassification cannot
recur (any trivially-closing PASS/ATTEMPT claim is an ALARM).

**Verification command** (re-run on this commit):
```
kprove phase1m/proofs/md_proofs.k -d <md-def> --spec-module MD-PROOFS \
  --claims MD-INV-ALLPATH-REACHABILITY   # -> WarnTrivialClaim, rc=1
rg -c 'WarnTrivialClaim' phase1m/transcripts/k/kprove_MD-INV-ALLPATH-REACHABILITY.log
```
