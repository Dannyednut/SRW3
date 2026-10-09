# SRW3 Phase 1I — Provenance

## Lineage

- Branch `phase1i` created additively from `phase1h-r1-fix` @
  `bf78b8c034f7bcab83cda2862be288d8524f824c` (tag `phase1h-r1-complete`).
- No history rewriting: `phase1g` @ `a71ba64`, `phase1g-complete` @
  `a71ba64`, `phase1h` @ `4cb9ab7`, `phase1h-r1-fix` @ `bf78b8c` are
  untouched (no amend, no force-push); verified before the work by
  `git diff origin/phase1g..phase1h -- k/ phase1e/ phase1f/ phase1g/` being
  empty (the 1H discipline) and after the push by branch SHAs being
  unchanged on the remote.
- All Phase 1I work is isolated under `phase1i/` plus explicitly necessary
  repository metadata (`scripts/gen_phase1i_pdf.py`, `worklog.md`); the
  frozen material is byte-stable.
- The final Phase 1I commit SHA is the tip of `phase1i` at push time,
  recorded in the repository worklog and in the delivery record. A file
  cannot contain its own commit hash; MANIFEST integrity is anchored at
  bundle level (zip `.sha256` sidecar), following the Phase 1H/1H-R1
  disclosure pattern.

## Pinned external artifacts (re-provisioned in this environment, verified)

| Artifact | Version / commit | Verification |
|---|---|---|
| Geth binary | 1.17.7-stable, commit `3d858f858a458effb2a563788aedf1fe65e1f0d3` (built 2026-09-30, Go 1.27.1), from `gethstore.blob.core.windows.net/builds/geth-linux-amd64-1.17.7-3d858f85.tar.gz` | `geth version` output matches the Phase 1H/1H-R1 provenance records exactly (unmodified client) |
| K framework | v7.1.337 (pinned; jammy .deb extracted without root) | `kompile --version` = "K version: v7.1.337, Build date: Thu Jun 18 12:59:56 UTC 2026" |
| z3 | 4.13.3 (official x64 glibc-2.35 binary; the trixie-packaged binary segfaults in this environment — disclosed) | `z3 --version` |
| flex | 2.6.4 (Debian pool, extracted; required by kompile) | `flex --version` |
| libsecp256k1 | the Phase 1C shim build (soname `.0`), LD_LIBRARY_PATH | kore-exec links cleanly |
| Python | 3.12.14 (`/home/z/.venv`) + eth-utils 6.0.0 + eth-account | pip record |
| KEVM | NOT USED this phase (the 1G chain is used at the abstract layer; no EVM-tier proofs attempted) | — |

## Toolchain notes / known environment issues (do not erase)

- The workspace was reset twice during this phase; the repository was
  re-cloned from `Dannyednut/SRW3` and the toolchain re-provisioned from
  the pinned recipes each time. All pinned digests re-verified.
- `z3` from the Debian trixie pool segfaults (library mismatch); the
  official Z3Prover 4.13.3 binary is used instead.
- `libsecp256k1.so.0` is absent from the base image; the Phase 1C shim
  build is reused via LD_LIBRARY_PATH.
- The LLVM-15 backend toolchain was NOT re-provisioned: the LLVM digest
  demo is disclosed as NOT run (section 9 of the report); the keccak
  instantiation is demonstrated by the Python mirror (DET-K1..K3).

## Exact test commands (all run live)

```text
# K ladder (Haskell backend)
source tools/env.sh
kompile phase1i/semantics/srw3proto.k --backend haskell \
  -I phase1g/semantics -I phase1f/semantics -I phase1e/semantics \
  -I k/phase1d -I k/kevm/kproj-e1e/plugin -o /tmp/proto-hs
bash phase1i/proofs/run_pi_proofs.sh phase1i/transcripts/k
#   -> 12 claims PROVED / 0 failed (PI2-POLICY-SUB, PI2-CTX-SUB, PI7-ALL
#      disclosed NOT MECHANIZED; per-claim logs in transcripts/k/)

# Python suites (pure model; no devnet)
python3 phase1i/python/run_attack_matrix.py          # PI-A1..A16 + cells  30/30
python3 phase1i/python/run_determinism_i.py          # DET-I1..I9 + K-mirror 15/15
python3 phase1i/python/run_reorg_replay.py           # RR/RP + GOV         17/17
python3 phase1i/python/run_forkchoice_compare.py     # FC-1..7 + CM-I1..I8 16/16

# Real-client prototype (fresh unmodified Geth devnet per run)
bash phase1h/devnet/reset_devnet.sh && \
  python3 phase1i/python/run_experiment.py           # required experiment PASS
                                                     # + separated performance

# Zero regression against phase1h-r1-fix (run from the phase1i branch)
python3 phase1h/python/test_lineage_r1.py            # 11/11
python3 phase1h/python/test_security_context_r1.py   # 26/26
bash phase1h/devnet/reset_devnet.sh && python3 phase1h/python/run_h.py
                                                     # 10/10 exact match
```

Test counts: K claims 12 PROVED (of 15 formulated; 3 disclosed NOT
MECHANIZED); attack matrix 30 assertions; determinism 15; reorg/replay +
governance 17; fork-choice + countermodels 16; required experiment 7
checks PASS; regression LID 11 + SCT 26 + H 10 exact-match.

## Known failed experiments / attempts (retained, not erased)

- PI2-POLICY-SUB / PI2-CTX-SUB on the Haskell backend: prover aborts while
  simplifying the claim (`No evaluators for function symbol:
  LblKeccak256raw...`); logs retained at
  `phase1i/transcripts/k/kprove_PI2-POLICY-SUB.log` /
  `kprove_PI2-CTX-SUB.log`.
- PI7-ALL `[circularity]`: kore aborts with "The configuration's term
  unifies with the destination's term, but the implication check between
  the conditions has failed"; isolated attempt retained at
  `phase1i/proofs/pi7all_only.k`; log at
  `phase1i/transcripts/k/kprove_PI7-ALL.log`.
- First required-experiment run: the respecting borrow (B') REJECTED
  because the violating borrow had already been EXECUTED by the shadow-mode
  client (state contamination); re-ordered (B' before B) — disclosed in the
  experiment transcript.
- First performance run: senders 10+ were unfunded at genesis
  (`insufficient funds`); perf senders moved onto the funded genesis
  accounts 3..9.
- z3 from the trixie pool segfaults in this environment; replaced by the
  official binary (disclosed above).

## Known non-mechanized claims

- PI2-POLICY-SUB, PI2-CTX-SUB (keccak evaluator absence on the Haskell
  backend) — DEMONSTRATED at the model level (Python PI-A5/A6/A7).
- PI7-ALL forall-closure (circularity implication check) — the content is
  DEMONSTRATED by the exhaustive Python suites; base/step/reject PROVED.
- LLVM digest-instantiation demo (toolchain not re-provisioned) — covered
  by the Python keccak mirror (DET-K1..K3).

## Artifact hashes

See `provenance-hashes.txt` (PROVENANCE.md digest; MANIFEST integrity is
anchored at bundle level per the Phase 1H disclosure pattern) and
`MANIFEST.txt` (the generated-artifact snapshot, self-excluding).
