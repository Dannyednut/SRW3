# SRW3 Implementation Package — Reconciled Claims Index

Package 1.0.0 (Phase 1K).  This index reconciles the proof inventory carried
by the packaged surface across the frozen phase trees.  Sources of record:
the frozen `claims-status.csv` / `claim-classification.csv` / `score.txt`
files and the frozen reports of each phase (paths cited per row).  The
package itself adds NO new proof obligations: it certifies byte-identity of
the packaged artifacts and re-runs the executable tiers.  Scientific labels
are transcribed verbatim from the frozen records — PROVED means mechanically
proved at the stated backend; nothing is relabeled here.

## 1. K proof ladder (mechanized, hs backend unless stated)

| phase | tree | inventory | PROVED | retained / NOT MECHANIZED | source of record |
|---|---|---|---|---|---|
| 1G | `phase1g/` | gate ladder (binding/negative/non-circ/record families) | per frozen transcripts (incl. designed-FAIL negatives `part3_fail_*`) | disclosed per log | `phase1g/transcripts/`, report |
| 1I-R1 | `phase1i-r1/` | 33-claim ladder | 31 | R1-ALL NOT MECHANIZED (kore circularity); OLD-ACCEPTS-CALLER-CONFIG NOT MECHANIZED (#Ceil) | `phase1i-r1/transcripts/k/score.txt` = `31 2` |
| 1I-R2 | `phase1i-r2/` | 40-claim ladder | 37 | R2-PIPELINE-HONEST/-FORGED, R2-ALL NOT MECHANIZED (hs stuck-term / kore classes) | `phase1i-r2/transcripts/k/score.txt` (legacy `3 0` notation, corrected by the R3 score convention) |
| 1I-R3 | `phase1i-r3/` | 51-claim ladder | 47 | R3-PIPELINE-HONEST/-FORGED NOT MECHANIZED (ErrorBottomTotalFunction); R3-ALL NOT MECHANIZED (stuck-configuration); R3-ANCHOR-IMMUTABLE = STRUCTURAL | `phase1i-r3/transcripts/k/claim-classification.csv`, `score.txt` = `47 3` |
| 1J | `phase1j/` | 42-claim ladder | 38 | J-EVIDENCE-STATE-CORRESPONDENCE, J-COMMIT-IMPLIES-SAFE-DESTINATION, J-COMMIT-UNSAFE-COMPOSITION-REJECTS NOT MECHANIZED on hs (keccak-hook class) — DEMONSTRATED on LLVM T1/T2/T3/T6 and CHECKED in Python; J-REACHABLE-COMMITTED-SAFE NOT MECHANIZED (frozen PI7-ALL kore class) — closure evidence: proved component lemmas + Python enumeration (3474 committed prefixes, 386 unsafe caught, 0 committed unsafe) + LLVM T2 | `phase1j/transcripts/k/claim-classification.csv`, `score.txt` = `38 4` |

Headline mechanized results carried by the package (verbatim from the frozen
ladders): `R3-ACCEPT-IMPLIES-COMMITP` (the guard verbatim, incl. anchor/root
re-checks), `R1/R2/R3-VALID-ACCEPT` (non-vacuity), the forged-verdict
rejection family, the receipt single-use and config-immutability frames, the
1J catalog byte-fixture (`J-CATALOG-CANON-FIXTURE`, 451-byte canon), the
3-app countermodel (`J-SAFE-UNSAFE-COMPOSITION`), frame preservation, and
the anchor discipline (`*-INIT-PINS-AUTHORIZED` / `*-INIT-ROOT-MISMATCH-REJECTS`).

## 2. Executable tiers (this package re-runs them fresh)

| tier | suite | frozen result | package re-run |
|---|---|---|---|
| Python | 1E authenticated state | suite PASS | `executions/suite_1e.txt` |
| Python | 1F execution evidence | 16/16 verdicts + 3/3 byte | `executions/suite_1f.txt` |
| Python | 1G frozen gate | 25/25 verdicts | `executions/suite_1g.txt` |
| Python | R1 binding attacks | 48/48 | `executions/regression_r1.txt` |
| Python | R2 provenance attacks | 87/87 | `executions/regression_r2.txt` |
| Python | R3 config-root attacks | 181/181 | `executions/regression_r3.txt` |
| Python | 1J adversarial matrix | 48/48 (J-A01..A24 + honest + det + enumeration) | `executions/attacks_1j.txt` |
| Python | 1J unittests | 27/27 | `executions/unittests_1j.txt` |
| LLVM | 1J krypto-shim suite (real keccak) | 14 executed demos + 5 kparse rejects (T0–T15) | frozen transcripts `phase1j/transcripts/llvm/`; re-run requires the pinned toolchain |
| K | kprove ladders | scores above | frozen logs; re-run requires the pinned toolchain |

## 3. Cross-layer conformance

22/22 byte-identical conformance fields between the K LLVM certificate
(real Keccak-256, `phase1j/transcripts/llvm/T0`) and the Python mirror
(`vectors/j_golden.json`), including the computed verdicts and the SafeJ
evaluations, with the disclosed verdict-surface normalization (R2/R3 mirror
artifact).  The package's integrity oracle (`MANIFEST.sha256` +
`verify_all.sh`) asserts byte stability of the package tree AS COMMITTED;
run-to-run conformance of the regenerated vectors is asserted SEMANTICALLY
(parsed key/value equality against the committed object, bytes restored
afterwards — the corrective Phase 1K protocol, replacing the `d32ad13`
byte-equality-of-regenerated-output requirement that is environment-
dependent).

## 4. Status labels used in this package

- **PROVED** — mechanically proved by kprove at the stated backend (log of record).
- **DEMONSTRATED** — concretely executed end-to-end on the LLVM backend with
  real keccak (transcript of record).
- **CHECKED / PASS** — executable Python tier (transcript of record).
- **NOT MECHANIZED** — the kprove attempt failed or timed out; the log is
  retained in the frozen tree and the concrete substitute is named.  A
  failed universal theorem accurately recorded is not a project failure;
  relabeling it would be.
- **ASSUMED** — recorded in the frozen assumption registers (1J audit §E):
  the authenticated anchor; keccak collision resistance; the frozen gate's
  soundness as used; the invariant language is the intended policy; the
  declared execution source's integrity; the input-side authenticity
  boundary.
- **Phase 1K packaging itself** — the package layout, entry points, and the
  compat layer are NEW additive artifacts (no proof obligations); the
  "implementation package" phase definition was not found in writing in the
  repository and is an ASSUMED interpretation per the established phase
  pattern (see the 1K report §1).
