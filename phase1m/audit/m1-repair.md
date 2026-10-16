# SRW3 Phase 1M — Workstream A audit: the L-FINDING-1 semantic repair

**Disposition:** COMPLETE at the claim level.  The cross-layer divergence is
repaired in a separately justified commit (handoff §0 prerequisite): the K
machine now produces the same explicit refusal diagnostic the Python mirror
always produced, with no receipt, no committed movement, and no over-
application.  Level III only; no consensus-integration claim.

## 1. The finding

Frozen 1J (`phase1j/semantics/srw3closure-j.k` @ a91dbcc, sha256
`6abfec54...`), line 1838: the unauthorized-source dispatch rule's
`<jlineage>` pattern was the SINGLE-ENTRY map
`-1:Int |-> C:ProtoCfgR3` (no tail).  In a fully-pinned machine (the config
pin plus any additional lineage entries — catalog pin, exec-receipt pool,
committed blocks) the pattern matched NOTHING: the K machine was STUCK — no
`jrefusedSource()` diagnostic, no receipt, no committed movement.  The
Python mirror (`j_model.py`) emits `(False, ('source',))` on every
initialized shape.  Fail-closed on both sides, but a CROSS-LAYER MISMATCH
(finding L-FINDING-1, reported in Phase 1L; the frozen T11 LLVM transcript
and the K claim `L-INV-EXEC-DISPATCH-SOURCE` are the retained witnesses).

## 2. The repair (one line)

`phase1m/semantics/srw3closure-j-m1.k` = the frozen machine with EXACTLY
ONE semantic edit (applied and roundtrip-verified by `scripts/make_m1.py`):

```diff
-       <jlineage> -1:Int |-> C:ProtoCfgR3 </jlineage>
+       <jlineage> -1:Int |-> C:ProtoCfgR3 REST:Map </jlineage>
```

The repaired rule matches ANY lineage CONTAINING the config pin.  `requires`
(`isExecOkJ(...)` and the source inequality) and RHS (`jrefusedSource()`)
are UNCHANGED.  The mint branches (source EQUALITY) and the
unsupported/bounds branches (RESULT SHAPE) remain disjoint from the source
class — the negative controls prove the partition holds.  The demo module
`srw3closure-j-m1-demo.k` is the frozen demo with the versioned requires /
module names only (roundtrip-verified by `scripts/make_m1_demo.py`).

## 3. Claim table (phase1m/proofs/m1_repair.k, hs backend, raw logs retained)

| claim | expected | raw | correct |
|---|---|---|---|
| M1-EXEC-DISPATCH-SOURCE | PASS | PROVED | yes — the repaired witness: the diagnostic fires in the fully-pinned machine, every other cell framed |
| M1-EXEC-DISPATCH-SOURCE-SINGLE-ENTRY | PASS | PROVED | yes — continuity: the single-entry shape still refuses |
| M1-EXEC-SOURCE-NOCOMMIT | PASS | PROVED | yes — committed state, lineage (incl. the -4 pool), slot, both heads, anchor: unchanged (identity destinations) |
| M1-NEG-SOURCE-AUTHORIZED-DIAGNOSTIC | FAIL | FAILED(rc=1) | yes — the authorized source does NOT take the refusal branch (concrete `jrefuseNoneJ` pinning) |
| M1-NEG-SOURCE-DIAG-BOUNDS | FAIL | FAILED(rc=1) | yes — a bounds result does NOT take the source branch (the dispatch partition) |
| M1-EXEC-OK-MINT-POOL | FAIL | FAILED(rc=1) | yes — the documented B3 pool-Ceil boundary retained (the kore residual `#Ceil(Keccak256raw(...))` is verbatim in the log) — the Workstream-B target, NOT a repair regression |

`claims-status-m1.csv` + `score-m1.txt`: 6 correct / 0 gate alarms.

## 4. OLD/NEW evidence pair

- OLD: `transcripts/k/kprove_OLD-L-INV-EXEC-DISPATCH-SOURCE.log` — the frozen
  1L witness claim re-run over the FROZEN definition (/tmp/l-hs from the
  frozen `j_invariant.k`): rc=1, "backend terminated because the
  configuration cannot be rewritten further" — the stuck witness reproduced.
- NEW: `transcripts/k/kprove_M1-EXEC-DISPATCH-SOURCE.log` — PROVED over M1.

## 5. LLVM transcripts (real Keccak, --hook-namespaces KRYPTO + krypto shim)

- `transcripts/llvm/anchor-m1.txt`: ANCHOR=
  `295e0b6d2215e20662693a20e9af41d58f09b07b77dedd92924c2f6029dec9df` —
  byte-identical to the frozen record.
- `T11-M1-llvm-unauthorized-source-refused-CORRECTED.txt`: the frozen T11
  program, byte-equal — the machine now CONSUMES the command and writes
  `jrefusedSource()`; krun exit 0; `<jstate>` unchanged (.Map), heads
  unchanged.  The frozen T11 (stuck) is retained unchanged in phase1j/.
- `T1-M1-llvm-honest-one-block-pipeline.txt`: the honest pipeline COMMITS
  (`<jnext>` 1, `<jhead>` advanced, `jrefuseNoneJ`) — the committed surface
  is byte-identical to the frozen T1 (no regression).

## 6. Python mirror cross-check (transcripts/attacks/m1_mirror_crosscheck.txt)

8/8 (`phase1m/python/run_m1_crosscheck.py`): the intended refusal
`(False, ('source',))` on BOTH fully-pinned shapes (A: pins only;
B: pins + committed block + consumed pools), no receipt, no movement
(state/head/linhead/slot/anchor byte-equal), authorized sources still mint.
**CROSS-LAYER AGREEMENT: YES** (K claims + T11-M1 + mirror).

## 7. Frozen regressions (fresh runs on the rebuilt pinned toolchain)

- 1J attack tier: 48/48 (`regression-1j-attacks-fresh.txt`)
- 1J unittests: 27/27 (`regression-1j-unittests-fresh.txt`)
- 1L adversarial tier: 56/56 (`regression-1l-tier-fresh.txt`)
- Frozen trees byte-stable: `git status` over phase1j/ phase1l/ k/ (outside
  the shim build dir) is EMPTY; the frozen 1J machine sha256 re-verified
  `6abfec54...` post-run.

## 8. Toolchain note (environment repairs, disclosed)

Sandbox reset #6: the repo re-cloned from origin/phase1l-universal-induction
@ 0aee3ee (the required starting point; the pre-reset phase1m work was
unpushed and is REDONE — this commit is that redo).  Toolchain rebuilt from
the pinned recipe (K v7.1.337 jammy deb, z3 4.13.3-1, LLVM-15 15.0.6-4+b1
chain, libsecp256k1-2 0.5.0-2+b1 +dev headers, mpfr 6.2.2): the K deb needs
its `prelude.md` present at the include root (symlinked from builtin/), the
`llvm-kompile-clang` driver's hardcoded `/usr/bin/clang++-15` substituted
with the extracted clang (the 1K fix of record), and the syslibs dev
symlinks (host libtinfo/jemalloc/unwind; mpfr from the pinned deb) on the
LIBRARY_PATH.  The frozen 1L definition kompile reproduces at 26.1s
(the recorded 25.4s + noise) — the validation gate of record.

## 9. Dispatch partition statement

For `jExecDispatch(SRC, PG, CL, VL)` in an initialized machine, the result
is decided by `ExecFragmentJ(S, PG)` and the source pin:
- `isExecUnsupportedJ` -> `jrefusedUnsupported(op)` (result shape);
- `isExecBoundsJ` -> `jrefusedBounds(op)` (result shape);
- `isExecOkJ` and source INEQUALITY -> `jrefusedSource()` (the repaired rule);
- `isExecOkJ` and source EQUALITY -> the ok-mint (the only receipt producer).
The classes are pairwise disjoint (by the result shape on the first two; by
the pin inequality on the last two); claims 1-3 + the two negative controls
mechanize the partition on the shapes the ladder pins.  The stuck
configuration for the unauthorized-source class is GONE (claim 1); no other
class is touched by the repair (the diff is one line).
