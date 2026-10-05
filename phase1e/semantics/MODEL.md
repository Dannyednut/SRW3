# SRW3 Phase 1E — Authenticated State Model (FROZEN DESIGN)

Status: **FROZEN at Phase 1E model design** (this file is the normative model
specification for every Phase 1E implementation: Python reference, K
semantics, KEVM binding). Any deviation must be reported as a deviation, not
silently absorbed.

## 1. Research question (falsifiable)

Can the SRW3 commitment gate make its security decision depend on an
**authenticated state commitment**, so that a presented post-state is
cryptographically anchored to an authoritative state commitment rather than
merely internally self-consistent?

The answer is NOT presumed. A negative or partial result is an acceptable
outcome and is reported with the same rigor as a positive one.

## 2. The three-level distinction (never conflated)

```text
Level 1  presented record internal self-consistency        Phase 1D-R1 (DONE)
         — PresentedPost == Apply(PreState, TrueEffects)
           (canonical finite-map equality, L7) plus genuine
           crypto over the presented artifacts.

Level 2  anchored to an authoritative state commitment     Phase 1E (THIS PHASE)
         — the presented state additionally matches a
           Merkle root carried by an explicit, independent
           anchor. Represented by a fixed-depth binary
           Merkle tree over the canonical key universe.

Level 3  faithful to what execution actually did           NOT THIS PHASE
         (execution-effect authentication)                 (open; NOT YET MECHANIZED;
                                                            historically-true-effects
                                                            problem inherited from 1D-R1)
```

Phase 1E operates at Level 2 ONLY. No result of this phase may be worded as a
Level 3 result. The anchor's provenance is an explicit assumption (§9).

## 3. State and key universe

* `KVState` — the Phase 1D-R1 finite map `app -> slot -> value` (Ints).
* Keys are flattened to a single Int `k = app * 2^32 + slot`
  (`app, slot ∈ [0, 2^32)`), encoded big-endian 4+4 bytes. Injective by
  construction (fixed-width fields; NOT a cryptographic property).
* **Canonical key universe** of a record:
  `U = sort( keys(pre) ∪ keys(effects) ∪ keys(post) )` — the flattened
  key sets. The universe is DETERMINED by the artifacts the record already
  digests (inputD/effectD/stateD); the producer has no new universe freedom.
* **Capacity**: `|U| ≤ 256` (model parameter; depth D = 8). `|U| > 256` is a
  model REFUSE (`AUTH-CAPACITY`), never a silent truncation.
* **Reserved pad key** `PAD = (2^32-1) * 2^32 + (2^32-1)` fills the tree to
  exactly `2^D = 256` leaves as presence-0 leaves. A real key equal to PAD is
  a model REFUSE (`AUTH-PADKEY`), checked at tree build.

## 4. Fixed-depth binary Merkle tree

Depth D = 8, 256 leaves, always. Leaf i (0-based):

```text
leaf i      = Leaf(U[i])          presence = 1 if U[i] ∈ keys(post), value = post[U[i]]
                                    presence = 0 if absent (value field = 0)
PAD leaves  = Leaf(PAD), presence 0  (positions |U| .. 255)
```

Byte encodings (domain-separated by a 1-byte tag):

```text
leafBytes(k, pres, v) = 0x00 || i2b4(app(k)) || i2b4(slot(k)) || pres || i2b4(v)
                          (pres ∈ {0x00, 0x01}; v = 0 when pres = 0)
nodeBytes(l, r)       = 0x01 || l || r                    (l, r are 32-byte digests)
leafHash(i)           = Keccak256(leafBytes(...))
nodeHash(l, r)        = Keccak256(nodeBytes(l, r))
root                  = level-0 single nodeHash (8 reduction levels)
treeBytes(U, post)    = 0x02 || i2b4(8) || i2b4(|U|) || (leafBytes for all 256
                         positions, ascending index) — the FULL canonical tree
                         byte string (injective representation of (U, post);
                         used for cross-layer byte certificates and for the
                         structural injectivity argument)
```

`root = AuthRoot(U, post)` is a deterministic function of `treeBytes(U, post)`
(re-derived by reduction); both layers are compared cross-layer.

## 5. Proofs

* **Inclusion / non-membership proof** for key `k` (universe index `i`):
  ```text
  proof = i2b4(i) || sib[0] || ... || sib[7]   (8 sibling digests, bottom-up; 260 bytes)
  ```
  Verification recomputes `leafBytes(k, pres, v)` from the CLAIMED leaf
  content, walks the sibling path (bit 0 of the index selects left:
  `h = nodeHash(h, sib[d])`; bit 1: `h = nodeHash(sib[d], h)`), and accepts
  iff the recomputed digest equals the root.
  A proof is a **content-binding** proof: the verifier must be given (k, pres, v)
  and the index; the path alone proves nothing.
* **Update proof**: same siblings; the verifier first re-derives the OLD root
  from the old leaf content (must equal the current root), then re-derives the
  NEW root from the new leaf content. Deterministic; equality with the
  producer-side tree update is experiment E2.

## 6. Record extension (strictly additive)

The frozen 12-field `LinRec` (Phase 1D-R1) is untouched. The extended record is

```text
LinRecE = ( LinRec , stateRoot: 32 bytes , childE: 32 bytes )
```

with

```text
CanonCoreE = CanonCore(rec) || sigLen4 || sig || stateRoot
childE     = Keccak256(CanonCoreE)
```

i.e. the legacy canonical bytes are a strict PREFIX of the extended canonical
bytes. The legacy 12-layer chain runs UNCHANGED on the legacy projection
`linRecOf(LinRecE) = LinRec` (including the legacy child over the legacy
layout). The extension layers below run afterwards. The signature does NOT
cover stateRoot; childE does; the ANCHOR (§7) is what constrains stateRoot
externally. This trust nuance is reported, not hidden.

## 7. Verification modes (explicitly separated)

`VerifyLineageA(recE, ctx, tid, head)` — first-fail chain:

```text
[legacy 12 layers, unchanged]  → any legacy verdict fires unchanged
L13 STATEROOT  (Mode S) : stateRoot == AuthRoot(U, presentedPost)
                          where U = canonUnion(pre, eff, presentedPost)
L14 ANCHOR     (Mode A) : stateRoot == anchor        (anchor travels in the context)
L15 CHILDE              : childE == Keccak256(CanonCoreE)
"valid"
```

* **Mode S** (self-computed root): the verifier recomputes the root from the
  presented artifacts. Security content: a SECOND digest over the same
  content via a different encoding — representation-equivalent to the
  StateDigest binding (this equivalence is itself a Phase 1E finding,
  mechanized; it adds no new cryptographic assumption beyond 1D-R1).
* **Mode A** (anchored root): the verifier additionally checks stateRoot
  against `anchor` — an EXPLICIT context input standing for an independently
  published state commitment. Under collision resistance, a record accepted
  in Mode A presents a post-state whose canonical tree root IS the anchor:
  the producer cannot substitute a different state without breaking either
  L7 (self-consistency) or L14 (anchoring). The anchor's PROVENANCE (who
  computes/publishes/signs it) is NOT mechanized in this phase —
  see §9.

## 8. Gate semantics and the E-experiments

```text
E1 authenticated read        AUTH-READ: honest inclusion proofs verify;
                             content-mutated proofs fail. (K claim + Python mirror)
E2 authenticated update      AUTH-UPDATE: proof-based new root == tree-based new root.
E3 root-bound lineage        the extended record binds stateRoot into the lineage
                             (L13/L15; childE covers it).
E4 gate soundness            acceptance in Mode A implies
                             (legacy-valid ∧ L7 ∧ stateRoot == anchor) — the gate
                             theorem; anti-vacuity: concrete honest witness ACCEPTED.
E5 authenticated composition two-transition chain with root threading:
                             record n+1's anchor = record n's stateRoot.
E6 execution-binding boundary KEVM: the tree is computed over REAL EVM storage
                             with real keccak; the anchor is the root the KEVM run
                             computed — a demonstration of Level-2 machinery on
                             real execution, NOT a Level-3 result; anchor
                             provenance remains REQUIRES CLIENT/PROTOCOL SUPPORT.
```

## 9. Assumption census (explicit; nothing hidden)

```text
A-E1  Keccak256 collision resistance ....... REQUIRES CRYPTOGRAPHIC ASSUMPTION
A-E2  canonical-encoding injectivity ....... STRUCTURAL (fixed-width fields,
        (leaf/node/tree/proof/record)        ascending order; NOT cryptographic)
A-E3  anchor authenticity .................. ASSUMED input of the gate;
        (R* is the authoritative root)       provenance = REQUIRES CLIENT/
                                             PROTOCOL SUPPORT (not mechanized)
A-E4  model capacity ....................... |U| ≤ 256, keys < 2^32; overflow
                                             = explicit REFUSE (AUTH-CAPACITY)
A-E5  reserved pad key ..................... real keys ≠ PAD; violation =
                                             explicit REFUSE (AUTH-PADKEY)
```

## 10. Non-goals / boundaries (carried forward, unchanged)

* No claim that authenticated state implies authenticated execution effects.
* This model is NOT an Ethereum MPT and no "Ethereum MPT proof" claim is made.
  It is a minimal fixed-depth binary Merkle tree over the SRW3 canonical key
  universe, built to be fully executable and mechanizable.
* No result tier moves upward because a demo passes. Evidence tiers:
  PROVED BY K / PROVED BY KEVM-BOUND K / DEMONSTRATED BY KEVM /
  REFUTED — COUNTEREXAMPLE / EXPERIMENTALLY VALIDATED / ASSUMED /
  REQUIRES CRYPTOGRAPHIC ASSUMPTION / REQUIRES CLIENT/PROTOCOL SUPPORT /
  NOT YET MECHANIZED / BLOCKED.
