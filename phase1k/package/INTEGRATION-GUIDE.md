# SRW3 Implementation Package — Integration Guide

Package 1.0.0 (Phase 1K) · content base `phase1j-security-closure` @ `a91dbcc`
· claims level III.  This guide is the integrator-facing reference for the
packaged surface: installation, the command surface, the input model, the
fail-closed semantics, and the exact boundary of what the package claims.

---

## 1. Install

```sh
cd package
./install.sh                     # default: provision compat links if absent
./install.sh --adopt-quarantine  # move pre-existing dirs aside, then link
./install.sh --no-compat         # skip the compat layer (relocatable suites only)
```

`install.sh` performs exactly three steps, in order, and nothing else:

1. **Interpreter check** — requires `python3 >= 3.10` with the standard
   library (`hashlib`); `pycryptodome` is optional.
2. **Path-compat layer (disclosed environment fixture).**  Three frozen test
   files hardcode their historical checkout paths
   (`/home/z/my-project/srw3-kevm/...` in 1E/1F/1G,
   `/home/z/my-project/srw3b-work/...` in the R2 runner).  The package
   resolves this WITHOUT modifying a single frozen byte: `install.sh`
   creates the two symlink names pointing at THIS package directory, so the
   hardcoded paths resolve into the packaged copies.  If a target already
   exists, the default mode REFUSES (no clobbering); `--adopt-quarantine`
   renames the pre-existing directory aside (`<target>.phase1k-quarantined.<epoch>`)
   before linking.  When the compat layer is absent, the relocatable suites
   (1J runner, J unittests, R1/R3 runners) still run; the three
   hardcoded-path suites will fail at import time — this is disclosed, not a
   package defect.
3. **Self-integrity** — `sha256sum -c MANIFEST.sha256` over every packaged
   file.  Any mismatch aborts the install with a non-zero exit.

## 2. Run

```sh
./run_all.sh [OUT-DIR]     # default OUT-DIR: ../executions
./verify_all.sh
```

`run_all.sh` executes the full Python verification tier from THIS tree and
writes one transcript per tier into `OUT-DIR`:

| transcript | command | expected |
|---|---|---|
| `unittests_1j.txt` | `phase1j/tests/test_security_closure.py -v` | 27 tests OK |
| `attacks_1j.txt` | `phase1j/python/run_j_attacks.py` | 48/48 PASS; regenerates `phase1j/vectors/j_golden.json` in place |
| `regression_r1.txt` | `phase1i-r1/python/run_r1_attacks.py` | 48/48 |
| `regression_r2.txt` | `phase1i-r2/python/run_r2_attacks.py` | 87/87 |
| `regression_r3.txt` | `phase1i-r3/python/run_r3_attacks.py` | 181/181 |
| `suite_1e.txt` | `phase1e/python/test_auth_verify.py -v` | all OK |
| `suite_1f.txt` | `phase1f/python/test_exec_verify.py -v` | 16/16 + 3/3 byte |
| `suite_1g.txt` | `phase1g/python/test_authz_verify.py -v` | 25/25 |

Every runner exits with its failure count (0 = clean).  `attacks_1j`
regenerates `vectors/j_golden.json` from the packaged mirror; `verify_all.sh`
then re-checks the MANIFEST, so the regenerated vector file MUST still match
its packaged sha256 — this is the package's byte-stability oracle for the
golden vectors (determinism of the mirror across runs and, at packaging
time, byte-identity with the K/LLVM certificate values).

## 3. The input model (what an integrator must construct)

The mirror's normative pipeline (see `phase1j/python/j_model.py` and the
1J report §2) takes, in order:

1. **The authenticated protocol anchor** (`$SRW3R3ANCHOR` semantics): the
   explicit, externally authenticated 13-field R3 configuration root.  The
   package does not create, derive, or vote on anchors — the anchor is an
   assumption of record (1I-R3 disposition, unchanged in 1J).
2. **The policy catalog** (`JCatalog`): registered applications, flat 64-bit
   resources, n-ary hyperedges, and the declared finite typed invariant
   fragment (local bounds; sum over a key set; equality over a key set),
   canonically encoded under the domain-separated prefix
   `"SRW3/PolicyCat/J"||0x00` with content-class sub-roots 0xB1/0xB2/0xB3
   bound to the R3-rooted configuration fields 3/4/5.  Catalog CONTENTS are
   authenticated by the same anchor: a digest without its contents, or
   contents without their digest, refuses.
3. **The execution payload**: a 4-op program (`Read/Write/Call/Return` — the
   frozen 1F vocabulary) interpreted over the nested abstract state.  The
   trace, the effective write-delta, and the post-state are DERIVED by the
   machine, never asserted by a caller.  Anything outside the fragment
   (LOGn, CREATE/CREATE2, CALLCODE, DELEGATECALL, STATICCALL,
   SELFDESTRUCT, gas, memory ops, precompiles) or any out-of-range operand
   is an EXPLICIT refusal (`jExecUnsupported`/`jExecBounds`) — never a
   silent no-op.
4. **Evidence identity** (`EvidenceIDJ`, domain `"SRW3/Evidence/J"`): binds
   config root, catalog root, chain/fork, parent/post state roots (0xB4
   canon), payload digest, execution-source identity, trace digest,
   footprint digest, and policy-context digest into one identity.

## 4. The command surface and fail-closed semantics

The machine exposes four pipeline stages with single-producer receipts:

- `pExecJ` — the ONLY producer of exec receipts; every receipt field is
  machine-derived from the derived artifacts.
- `pGateEvalJ` — the ONLY producer of gate receipts; the verdict is
  COMPUTED by the frozen 21-conjunct gate (`verify_lineage_g`, imported
  unchanged from `phase1g`) over the machine-constructed authority context.
  No verdict, config, root, or anchor is ever a caller parameter (the R1/R2
  surface repairs, retained in J).
- `pCommitJ` — the ONLY chain-extending rule; consumes both receipts exactly
  once; re-checks the full R3-order requirement set (decidable conjuncts
  first, the computed policy result, hash-class conjuncts last) including
  the anchor/root re-checks; requires `SafeJ` on the DERIVED post-state;
  rejections leave every cell unchanged.
- Initialization (`pInitJ`) — pins the configuration under the anchor and
  enforces `J-INIT-SAFE` on the genesis (an unsafe genesis is refused at
  the pin).

Fail-closed liveness cost, stated plainly: unavailable evidence, catalog,
or closure data means the commit never fires.  Unavailability is never
interpreted as acceptance (`EvidenceMissing ⇏ SRW3Valid`).

## 5. The K proof tier

`semantics/` packages the proof-tier SOURCES byte-identically: the frozen
gate definition and its five kprove modules (`phase1g`), the R3 machine and
its 50-claim ladder (`phase1i-r3`), and the J machine with its 42-claim
ladder (`phase1j`).  The kprove logs, LLVM krypto-shim transcripts, and
regression transcripts live in the frozen trees (see `CLAIMS-INDEX.md` for
the per-claim pointers).  Re-running the K tier requires the pinned
toolchain (K v7.1.337, z3 4.13.3, LLVM-15 chain, libsecp256k1) and the
frozen runners (`run_j_proofs.sh`, `run_r3_proofs.sh`); the package does
not re-vendor the toolchain.

## 6. Non-claims (read before integrating)

- **No consensus integration.**  Level-III model only; the 1H Geth adapter
  was a shadow boundary and remains one.  Nothing here changes Ethereum.
- **The anchor is external.**  Protocol-root authority is an explicit
  assumption; governance is out of scope.
- **Finite fragment.**  Safety closure holds for the DECLARED finite
  effect/policy fragment (Option A).  Full-EVM evidence (Option B) is open.
  The universal reachability induction is NOT mechanized; its concrete
  substitutes are the proved component lemmas, the Python exhaustive
  sequence enumeration (3474 committed prefixes, 386 unsafe derived states
  caught by `Safe_P`, 0 committed unsafe), and the LLVM two-block pipeline.
- **Arbitrary-policy closure is NOT mechanized** (the typed fragment only).
- **Collision resistance** of Keccak-256 is assumed; the hs-backend keccak
  hook boundary classes are disclosed per claim in `CLAIMS-INDEX.md`.
- **Historical truth of presented traces** is not claimed — evidence
  correspondence and coverage are claimed for `EVM_F` only.
