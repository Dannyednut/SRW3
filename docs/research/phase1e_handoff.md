# SRW3 — Phase 1E Handoff Note

Status: **BOUNDARY DOCUMENT — Phase 1E is NOT implemented here.**
This note defines the exact starting state and the next scientific question.
It was written on 2026-10-03 at Phase 1D-R1 repository closure.

## 1. Exact starting state for Phase 1E

| Item | Value |
|---|---|
| Branch to start from | `phase1d-r1-complete` |
| Scientific anchor commit (tagged) | `85f4be5ad5fc525540b17b7a27ea27eb34e700a3` |
| Documentation commit on top | the closure commit introducing `docs/research/` |
| Verified artifact package | `SRW3-Phase1D-R1-FINAL-Artifact-Bundle.zip` (rebuilt at closure; self-excluding MANIFEST, sidecar hash) |
| Offline ref carrier | `git/srw3-work-r1-final.bundle` (main, kevm-changes, phase1-start, phase1b, phase1c, phase1d-r1-complete, tag) |
| Toolchain pins | K v7.1.337 · Z3 4.13.3 · clang/LLVM-15 15.0.6-4+b1 · KEVM v1.0.921 · blockchain-k-plugin @ 207ae512 · libsecp256k1 0.5.0 |
| Established capability | self-contained verifiable lineage records with cryptographic binding, verified in Python + K (hs/llvm) + KEVM; L7 exact post-state equality; 21/21 hostile-mutation rejection; authorized-dishonest-producer rejection at the state-composition layer; 17/17 cross-layer byte consistency |

Phase 1E must begin by checking out `phase1d-r1-complete` and re-running the
permanent suites (L7 10/10, mutations 21/21, comparisons 33/33) before any
new work, so that regressions are attributable to Phase 1E changes only.

## 2. The distinction Phase 1E must preserve

```text
Phase 1D-R1 (DONE):
  self-contained verifiable lineage + cryptographic binding
  — records are internally verifiable; digests/signatures/commitments
    bind the PRESENTED artifacts; composition is exact-equality.

Phase 1E (NEXT, NOT DONE):
  authenticated state representation and stronger state-commitment binding
  — how an AUTHENTICATED state representation (for example Merkle/MPT-style
    commitments where appropriate) can be connected to the SRW3 lineage and
    commitment model, so that state claims are bound to a verifiable state
    structure rather than only to a flat presented map.
```

In Phase 1D-R1 the verifier checks `PresentedPost == Apply(PreState,
TrueEffects)` over presented finite maps. Phase 1E asks whether the state
side can carry its own authentication structure (inclusion proofs, state
roots, non-membership proofs) and whether the lineage/commitment model can
bind to that structure without weakening anything already established.

## 3. What Phase 1E must NOT assume

* **Do not assume success.** Whether authenticated state representation can
  be connected to the SRW3 commitment model without new assumptions is an
  open scientific question. A negative or partial result is an acceptable
  outcome and must be reported with the same rigor as a positive one.
* **Do not assume the existing trust posture changes.** The producer remains
  inside the authorized-dishonest threat model; an authenticated state
  representation does not by itself authenticate historically true execution.
* **Do not upgrade terminology.** The evidence-tier vocabulary
  (PROVED BY K / DEMONSTRATED BY KEVM / ASSUMED / REQUIRES CLIENT/PROTOCOL
  SUPPORT / NOT YET MECHANIZED) and the locked phrases ("presented-effect
  consistency", "cryptographically bound under stated assumptions") carry
  forward unchanged.

## 4. Standing constraints carried into Phase 1E

1. Additive semantics discipline: new K modules follow the `linCtxP` /
   `VerifyLineageP` precedent (additive parallel verdict layer; legacy
   definitions untouched). Frozen definitions are never edited to make a
   demo pass.
2. Every negative result gets a negative control; every fix gets a permanent
   regression suite (L7 suite precedent).
3. Historical transcripts are immutable evidence; new runs go to new files.
4. Packaging: self-excluding MANIFEST, separate ZIP sidecar, no agent-local
   absolute paths, portability + round-trip checks.
5. Git: no history rewrites of milestone branches; descendants only.
6. Any verifier change must re-run, at minimum: L7 permanent suite,
   21-mutation harness, authorized-dishonest-producer test, K composition
   suite (1 positive + 3 negatives), and the cross-layer byte checks.

## 5. Candidate first questions (non-binding, to be refined at Phase 1E start)

* State-root binding: can `stateD` (digest over canonical presented state)
  be complemented by a Merkle root over the same canonical encoding, with an
  inclusion-proof verifier that is still exact (no superset acceptance)?
* Canonical-encoding stability: is the injective `LinCanonKV` encoding a
  sound basis for path-addressable proofs (per-key leaf commitments), or
  does an authenticated representation require re-canonicalization?
* Non-membership: extra-key rejection currently rests on exact byte
  equality; which authenticated structures preserve non-membership without
  trusted sparsity assumptions?
* KEVM grounding: can an MPT-style state layer be demonstrated on real EVM
  storage (the `srw3-lin-evm.k` precedent) rather than only at abstract K?
* Assumption census: which new assumptions (e.g., verifiable state
  publication, client support for root verification) would Phase 1E
  introduce, and how do they classify in the evidence-tier vocabulary?

## 6. Known open problems inherited from Phase 1D-R1

* Historically true execution effects (vs presented-effect consistency) —
  NOT YET MECHANIZED.
* Cross-domain root anchoring (binding the lineage model to external state
  commitments) — REQUIRES CLIENT/PROTOCOL SUPPORT; this is adjacent to and
  partially overlapping with Phase 1E's question.
* The Phase 1D-R1 result is a concrete demonstration within the modeled
  verifier domain, not a general cryptographic theorem.
