# SRW3 Phase 1K — Implementation Package Audit

Additive tree `phase1k/` · base `phase1j-security-closure` @ `a91dbcc`
(`phase1j-complete`, frozen) · package version 1.0.0

---

## A. Phase definition provenance (stated first, nothing hidden)

**No written Phase 1K specification exists in the repository.**  The claim
was verified mechanically before any package byte was written: `git grep`
over every commit reachable from every branch for `phase ?1k`,
`1K implementation`, and `implementation package` returns nothing; the repo
worklog ends at the Phase 1I-R3 section (Phase 1J never appended its own
section — backfilled by this phase); the 1J report's open items (Option B,
the universal induction, arbitrary-policy closure) are research openings,
not an implementation-package definition.

The phase definition is therefore **ASSUMED**, per the established phase
pattern (the user's one-line instruction style, the R1/R2/R3/1J working
agreement, and the standing completion gate): *an isolated additive branch
carrying the deliverable, with proof reports, concrete executions, and
regression results available for independent audit.*  For an
"implementation package" that means: assemble the verified surface into a
self-contained, byte-identity-certified, runnable package with disclosed
entry points — adding NO semantic change and NO new proof obligation.

This assumption is recorded here, in the report §1, and in
`package/CLAIMS-INDEX.md` §4.  If the intended 1K differs, the package is
additive and revertible; no frozen tree is affected.

## B. Byte-identity reconciliation (1:1)

`executions/byte-identity.txt` certifies every packaged artifact against its
frozen source at the base commit, per-file sha256:

- **48 copied artifacts: 48 IDENTICAL, 0 mismatches.**  Coverage: the full
  Python runtime surface (`python-gen`, `phase1e..phase1j` python dirs,
  1J tests + vectors, R3 vectors), the three K krun transcripts consumed by
  the runners' KX groups (R1 T2/T5, R3 certificate), and the K proof-tier
  sources (1G gate + 5 proof modules; R3 machine + ladder + runner; J
  machine + 42-claim ladder + runners).
- **7 additive artifacts** (no frozen source, listed as ADDITIVE):
  `VERSION`, `README.md`, `INTEGRATION-GUIDE.md`, `CLAIMS-INDEX.md`,
  `install.sh`, `run_all.sh`, `verify_all.sh`.
- `package/MANIFEST.sha256` (55 entries) is the package's own integrity
  oracle; `verify_all.sh` re-checks it on demand.

**Frozen-tree stability**: `git diff a91dbcc HEAD` over everything outside
`phase1k/` is EMPTY (enforced by the build script's pristine check and
re-verified at commit time).

## C. Entry points and disclosed mechanics

Three entry points, all new additive files:

1. **`install.sh`** — interpreter check (python3 >= 3.10, hashlib,
   **coincurve** probed with explicit remediation — the `lin_verify`
   dependency), the path-compat layer, self-integrity over the manifest.
   *Disclosed mechanics:* (a) the frozen 1E/1F/1G test files and the R2
   runner hardcode their historical checkout prefixes
   (`/home/z/my-project/srw3-kevm`, `/home/z/my-project/srw3b-work`); the
   compat layer symlinks exactly those two names to the package root —
   zero frozen bytes are edited; default mode REFUSES to clobber,
   `--adopt-quarantine` renames pre-existing trees aside; (b) `--no-compat`
   skips the layer (relocatable tiers still run; the hardcoded-path tiers
   will fail at import — disclosed, not a defect).
2. **`run_all.sh`** — the full Python tier.  *Disclosed mechanics:* the
   frozen suites locate sibling modules via `PYTHONPATH` exactly as the
   historical regression driver did (the package exports its own module
   dirs); the R1 runner resolves its KX transcripts relative to the CWD, so
   `run_all.sh` invokes it from its own directory (`runcd`), again matching
   the historical driver.
3. **`verify_all.sh`** — the byte-stability oracle: `sha256sum -c` over the
   manifest AFTER `run_all.sh` has regenerated `phase1j/vectors/
   j_golden.json` in place.  A pass therefore proves run-to-run determinism
   of the mirror AND byte-identity of the regenerated vectors with the
   packaged (K-certificate-conformant) copies.  Manifest fingerprint of
   record: see `provenance/provenance-hashes.txt` (regenerated at final
   manifest refresh).

## D. Completion gate, item by item

| gate item | package evidence | status |
|---|---|---|
| proof reports | `package/CLAIMS-INDEX.md` (reconciled inventory 1E..1J, statuses transcribed verbatim from the frozen `claims-status.csv`/`score.txt`/classifications; per-claim log pointers retained in the frozen trees); `executions/byte-identity.txt` (the package's own 48/48 byte-level verification) | DELIVERED |
| concrete executions | `executions/`: `unittests_1j.txt` (27 tests OK), `attacks_1j.txt` (48/48 PASS incl. the reachability enumeration 3474/386/0), `regression_r1.txt` (48/48 incl. KX vs packaged K transcripts), `regression_r2.txt` (87/87), `regression_r3.txt` (181/181 incl. KX), `suite_1e/1f/1g.txt` (OK; 16/16+3/3; 25/25), `verify_all.txt` (55/55 byte-stable incl. regenerated vectors), `k_tier/` (the FULL 1J LLVM suite re-run fresh from the PACKAGE-built interpreter with real keccak: T0/T2/T6 byte-identical to the frozen transcripts, anchor identical) — ALL EXECUTED FRESH FROM THE PACKAGE TREE | DELIVERED |
| regression results | the R1/R2/R3/1E/1F/1G tiers ARE the frozen regression suites, re-run from the package against the same expected counts; plus the in-repo frozen-tree regression tier (see below) | DELIVERED |

Independent auditability: every number above is reproducible by running
`./install.sh && ./run_all.sh && ./verify_all.sh` from the package with no
network access and no toolchain beyond python3 + coincurve; each transcript
carries the runner's own labels and exit code.

## E. Assumption register (nothing hidden)

1. **The 1K definition itself is ASSUMED** (§A) — the phase name is the
   user's instruction; no written spec exists in the repo.
2. The authenticated protocol anchor, keccak-256 collision resistance, the
   frozen gate's soundness as used, the invariant-language-is-intended-policy
   assumption, execution-source integrity, and the input-side authenticity
   boundary — inherited UNCHANGED from the frozen registers (1J audit §E;
   see `package/INTEGRATION-GUIDE.md` §6).
3. The package assumes a POSIX host with `python3 >= 3.10` and `sha256sum`;
   the compat layer assumes the hardcoded prefixes are creatable
   (`/home/z/my-project/...`) or skips them on refusal.
4. The Python tier is the fresh-execution surface; the K/LLVM tier is
   evidenced BOTH by the frozen transcripts (packaged where the runners
   consume them) AND by the fresh package-source LLVM rebuild executed in
   this environment (audit §F, report §5).  The kprove hs ladders were not
   re-run fresh — their frozen logs of record stand.

## F. Environment deviations of record

- **Sandbox reset recovery**: this container held none of the Phase 1E–1J
  state (no `srw3-1j/`, no toolchain, no remotes).  Recovery: the full repo
  was re-cloned from `Dannyednut/SRW3` (PAT-authenticated) with all
  branches/tags; the 1J state was verified at the `phase1j-complete` tag.
- **Stale-tree quarantine**: the pre-reset leftovers
  `/home/z/my-project/srw3-kevm/` (0-D/1C/1D era) and
  `/home/z/my-project/srw3b-work/` (1B era) would SHADOW the package's
  modules through the frozen hardcoded `sys.path.insert` lines (stale bytes
  would silently win the import race).  Both were moved aside by
  `install.sh --adopt-quarantine` (`<target>.phase1k-quarantined.<epoch>`)
  and replaced by the compat symlinks.  This quarantine is an environment
  repair, not a content change to any repo tree.
- **Dependency install**: `coincurve` was installed into the environment's
  python3.12 venv (`pip install coincurve`) — a runtime dependency of the
  frozen `lin_verify.py`, previously present in the historical environment.
- **Toolchain**: the pinned K toolchain (K v7.1.337, z3 4.13.3, LLVM-15
  chain, libsecp256k1) was rebuilt from the repo's recorded recipe with
  three recorded fixes (extract `libclang-common-15-dev`; flex on PATH;
  restore the pristine `llvm-kompile-clang` driver with one path
  substitution — the R2 recipe's driver patch breaks K v7.1.337).  On the
  rebuilt toolchain the FULL 1J LLVM suite ran fresh from the
  package-built interpreter with real keccak; the decisive transcripts
  (T0 certificate, T2 honest commits, T6 unsafe rejects, anchor) are
  byte-identical to the frozen 1J records.  The kprove hs ladders were
  not re-run fresh (disclosed; frozen logs stand).

## G. What this phase does NOT claim

- No new theorem, no new mechanization, no semantic change of any kind.
- No consensus integration; no end-to-end Ethereum enforcement claim.
- The package does not re-vendor the K toolchain or re-prove the frozen
  ladders as a condition of use; the proof tier's authoritative logs remain
  in the frozen trees.
- The 1E/1F/1G/R2 hardcoded-path compat layer is an environment fixture —
  NOT a modification of those files and NOT an endorsement of the hardcoded
  paths (they are disclosed frozen behavior).
- Level III only.  Everything in the frozen non-claim registers
  (INTEGRATION-GUIDE §6) applies verbatim to the package.

## H. Corrective disposition (post-independent-audit, verification repair)

The independent audit of the `d32ad13` completion state (findings K1-K4,
`PHASE1K_AUDIT_FINDINGS.md` in the Phase 1L handoff pack) established that
this audit's completion-gate row "verify_all.txt 55/55 byte-stable" was NOT
supported by the committed evidence: the saved transcript records the
manifest check FAILING on a fresh run (the regenerated `j_golden.json`
byte-compared against the committed copy — an environment-dependent
requirement).  Disposition:

- K1 REPAIRED: the wrapper now separates the two properties — semantic
  equivalence of the regenerated vector (checked key/value-for-key; result
  `executions/vector_semantics.txt`) and byte stability of the tree AS
  COMMITTED (`verify_all.sh` post-restoration; transcript
  `executions/verify_all.txt`, PASS).  The failing `d32ad13` transcript is
  archived at `executions/archive/verify_all_d32ad13_FAILED.txt`.
- K2 REPAIRED: the golden-vector spot check is exit-relevant (malformed
  vector or missing required field fails `verify_all.sh`); failing manifest
  paths are printed.
- K3 REPAIRED: README reconciled to the certificate (48 identical copied
  artifacts / 7 additive) with the count convention stated.
- K4 PRESERVED: fresh LLVM demonstrations remain demonstrations; the
  Haskell kprove ladders were not re-run fresh and their frozen logs stand;
  no unmechanized claim is reclassified.
- Tag `phase1k-complete` preserved at `d32ad13`; the repair is a NEW commit
  on this branch.  Completion gate item "byte-stability oracle" is now
  supported by fresh, reproducible, committed evidence.
