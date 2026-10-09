# SRW3 Phase 1I-R1 — Provenance

## Lineage

- Branch `phase1i-r1-formal-binding` created from `phase1i` @
  `e04fbb6147157fb11537de68618a001fd4b9afbe` (tag `phase1i-complete`).
  Verified before any work: `git rev-parse phase1i-complete` returned the
  exact base commit in a fresh clone.
- No history rewriting: `phase1g`, `phase1h`, `phase1h-r1-fix`, `phase1i`
  are untouched (no amend, no force-push). During the session the frozen
  tree was twice dirtied by tooling and immediately restored from git:
  (1) an earlier draft of the PDF generator wrote to the Phase 1I report
  path before its output path was corrected (the frozen PDF was restored
  with `git checkout --`); (2) running the frozen 1H-R1 Python suites
  regenerates their transcript JSONs with rerun stamps — those two files
  were also restored from git. The committed tree contains ZERO
  modifications outside `phase1i-r1/` (plus worklog metadata and the new
  `scripts/gen_phase1i_r1_pdf.py`).
- All Phase 1I-R1 work is isolated under `phase1i-r1/` plus the explicitly
  necessary repository metadata (`scripts/gen_phase1i_r1_pdf.py`,
  `worklog.md`); the frozen material is byte-stable. The frozen Phase 1I
  definition kompiles unmodified and its claims re-prove against the same
  kompiled definition used for the frozen-model witness claims.
- The final Phase 1I-R1 commit SHA is the tip of
  `phase1i-r1-formal-binding` at push time, recorded in the repository
  worklog and the delivery record. A file cannot contain its own commit
  hash; MANIFEST integrity is anchored at bundle level (zip `.sha256`
  sidecar), following the Phase 1H/1H-R1/1I disclosure pattern.

## Pinned external artifacts (re-provisioned in this environment, verified)

| Artifact | Version / commit | Verification |
|---|---|---|
| K framework | v7.1.337 (pinned jammy .deb, extracted without root) | `kompile --version` = "K version: v7.1.337 / Build date: Thu Jun 18 12:59:56 UTC 2026" — matches the Phase 1I provenance record exactly |
| z3 | 4.13.3 (official Z3Prover x64 glibc-2.35 binary; the trixie-packaged z3 segfaults in this environment — the Phase 1I disclosure, reproduced) | `z3 --version` |
| flex | 2.6.4 (Debian pool, extracted; kompile dependency) | `flex --version` |
| libsecp256k1 | 0.5.0 (trixie) with soname .0/.1 copies for kore-exec | kore-exec links cleanly |
| libLLVM-15 | 15.0.6-4+b1 (bookworm pool) — needed by kore-expand-macros for hs-backend krun only | krun runs |
| Python | 3.12.14 (`/home/z/.venv`) + eth-utils + pycryptodome (keccak-256, original padding — validated against keccak256("") = c5d246...) | pip record |
| KEVM | NOT USED (the repair does not change the EVM binding) | — |
| LLVM backend toolchain (clang-15 chain + krypto shim) | NOT re-provisioned — the LLVM-tier digest demo is disclosed NOT RUN (same disclosure as Phase 1I); covered by the Python keccak mirror | — |

## Exact test commands (all run live)

```text
# K ladder — repaired model + frozen-model witnesses (Haskell backend)
source tools/env.sh
kompile phase1i-r1/semantics/srw3proto-r1.k --backend haskell \
  --main-module SRW3PROTO-R1 \
  -I phase1g/semantics -I phase1f/semantics -I phase1e/semantics \
  -I k/phase1d -I k/kevm/kproj-e1e/plugin -o /tmp/r1-hs
kompile phase1i/semantics/srw3proto.k --backend haskell \
  --main-module SRW3PROTO -I phase1g/semantics -I phase1f/semantics \
  -I phase1e/semantics -I k/phase1d -I k/kevm/kproj-e1e/plugin -o /tmp/proto-hs
bash phase1i-r1/proofs/run_r1_proofs.sh phase1i-r1/transcripts/k
#   -> 31 PROVED / 1 NOT MECHANIZED (R1-ALL, kore circularity blocker,
#      same as the frozen PI7-ALL; per-claim logs in transcripts/k/)

# krun demonstration transcripts (hs backend)
bash phase1i-r1/transcripts/run_demos.sh phase1i-r1/transcripts/demos
#   -> T1 BEFORE (frozen accepts the forged verdict) +
#      T2/T3/T4 AFTER (repaired rejects: forged verdict / no receipt /
#      config substitution) + T5 (honest path = disclosed hs boundary)

# Python adversarial suite (real keccak-256)
/home/z/.venv/bin/python3 phase1i-r1/python/run_r1_attacks.py
#   -> 48/48 PASS (CM1..CM8 on both logics + determinism + K cross-checks)

# Zero regression (frozen suites re-run from this branch)
/home/z/.venv/bin/python3 phase1h/python/test_lineage_r1.py           # 11/11
/home/z/.venv/bin/python3 phase1h/python/test_security_context_r1.py  # 26/26
/home/z/.venv/bin/python3 phase1i/python/run_attack_matrix.py         # 30/30
/home/z/.venv/bin/python3 phase1i/python/run_determinism_i.py         # 15/15
/home/z/.venv/bin/python3 phase1i/python/run_reorg_replay.py          # 17/17
/home/z/.venv/bin/python3 phase1i/python/run_forkchoice_compare.py    # 16/16
```

Test counts: K claims 31 PROVED (of 33 formulated; 2 disclosed NOT
MECHANIZED with retained attempts); krun demos 5 transcripts; Python R1
suite 48/48; frozen regressions LID 11 + SCT 26 + PI 30 + 15 + 17 + 16,
all exact.

## Known failed experiments / attempts (retained, not erased)

- `R1-ALL` (forall-closure): kore aborts with "The configuration's term
  unifies with the destination's term, but the implication check between
  the conditions has failed" — the same blocker as the frozen `PI7-ALL`.
  Log: `transcripts/k/kprove_R1-ALL.log`.
- `OLD-ACCEPTS-CALLER-CONFIG` (init-chained F4 witness): nested-keccak
  `#Ceil` definedness obligations cannot be discharged on the hs backend.
  Attempt log: `transcripts/k/kprove_OLD-ACCEPTS-CALLER-CONFIG-attempt.log`;
  the commented claim + blocker note live in `proofs/old_witness.k`.
- Symbolic `Set`-rest receipt-pool claims: alternative AC decompositions
  generate undischargable `#Ceil(Keccak256raw)` conditions — claims restated
  with singleton/empty concrete pool shapes (disclosed in the report, §4);
  the general-pool case is covered by the model semantics + Python mirror.
- Symbolic map-update RHS in the gate rule does not reduce on the hs
  backend — the rule was restated as two explicit cons-form rules
  (existing pool / no pool yet).
- First krun attempts failed on PGM parsing (a bare command is not a
  `PRunI` term — no subsort) and on the missing `--main-module` /
  libLLVM-15 provisioning; resolved before the transcripts were taken.
- The FIRST draft of `scripts/gen_phase1i_r1_pdf.py` briefly wrote to the
  Phase 1I report path (frozen tree); caught immediately and the frozen
  PDF restored from git before any commit. Recorded here for completeness.

## Known non-mechanized claims

- `R1-ALL` (forall-closure) — kore circularity implication check; content
  DEMONSTRATED by the exhaustive Python suites; base/step/reject pieces
  PROVED.
- `OLD-ACCEPTS-CALLER-CONFIG` (init-chained F4 witness) — nested-keccak
  `#Ceil` blocker; F4 witnessed single-step by `OLD-ACCEPTS-FORGED`, by the
  source-level audit, and concretely by Python CM4.
- LLVM-tier digest instantiation demo — toolchain not re-provisioned;
  covered by the Python keccak mirror (KX group + DET).

## Artifact hashes

See `provenance-hashes.txt` (PROVENANCE.md digest; MANIFEST integrity is
anchored at bundle level per the Phase 1H disclosure pattern) and
`MANIFEST.txt` (the generated-artifact snapshot, self-excluding).
