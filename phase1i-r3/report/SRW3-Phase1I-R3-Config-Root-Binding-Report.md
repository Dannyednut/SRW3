# SRW3 Phase 1I-R3 — Full Configuration-Root Binding Report

**Branch** `phase1i-r3-config-root-binding` · **Base** `82f06757db560545e0c844c6196c842426a760d8` (`phase1i-r2-complete`) · **Scope** Level-III protocol model only — no consensus-integration claim.

## 1. Executive summary

Phase 1I-R3 closes the last aliasing boundary of the Phase-1I commitment chain.  In the frozen R2 machine the configuration-root preimage (`ProtoCfgCanonR2`, tag 0x9C) committed to configuration fields 1–8 only, while fields 9–13 — the execution schedule, the specification version, and the gate-authority triple (proof type, guest digest, proof-config digest) — influenced gate authority yet were documented as "pin-internal".  Two machines could therefore display the SAME configuration root while enforcing DIFFERENT gate authority: the root a remote party uses to identify "the" configuration did not determine the authority parameters the gate enforces.

R3 delivers an isolated machine (`phase1i-r3/semantics/srw3proto-r3.k`, importing only the frozen Phase 1G gate) in which:

1. **The protocol root commits to all 13 configuration fields**, including the five authority fields added in R2, via a new versioned, domain-separated, length-delimited encoding (`ProtoCfgCanonR3`; the frozen 0x9C preimage is never reused).  The 349-byte golden preimage of the handoff's sample configuration is mechanically verified on the K Haskell backend, reproduced byte-for-byte by the Python reference encoder, and matched by the LLVM real-Keccak run.
2. **Configuration changes produce a different commitment and cannot silently reuse the old root.**  Each of the 13 fields is proven (concretely, per-field, on the Haskell backend) to change the canonical preimage; each of the five authority fields additionally carries the R2-alias witness (the legacy projection is UNCHANGED, the R3 preimage CHANGES); real-Keccak root changes are demonstrated on LLVM and in the golden vectors; and initialization refuses ANY mutated configuration re-presented under the old authorized root (decisive LLVM demo T5; K claim R3-INIT-ROOT-MISMATCH-REJECTS PROVED; Python INITROOT group).
3. **Initialization checks the computed root against an explicitly authenticated protocol root.**  The machine carries a dedicated immutable anchor cell (`<r3anchor>`) filled by the explicit authenticated external input `$SRW3R3ANCHOR` — reachable by no command and written by no rule.  `pInitR3` pins only when `ProtoRootR3(C)` equals that anchor (R3-INIT-PINS-AUTHORIZED PROVED); acceptance re-checks the receipt's anchor and computed root against the live machine (R3-REJECT-ANCHOR-MISMATCH PROVED).
4. **K proofs, LLVM demonstrations, Python tests, and cross-layer commitment checks agree.**  47/50 K claims PROVED on the Haskell backend; the three retained NOT-MECHANIZED labels inherit the known blocker classes (below); the LLVM shim suite executes the honest two-block pipeline with real Keccak; the Python suite passes 181/181 and the unittest suite 21/21; every digest of the cross-layer certificate agrees byte-for-byte between the K machine (shim) and Python; the frozen regression baselines show zero drift (11/11, 26/26, 30/30, 15/15, 17/17, 16/16, 48/48, 87/87).
5. **Proofs, assumptions, failed attempts, and regression results are documented accurately**: a per-claim machine-readable status table (`claims-status.csv` + `claim-classification.csv`), an unambiguous score convention, retained failure logs, a mechanical anchor-immutability scan, and an eight-entry assumption register (audit §H).

The key unresolved issue identified by the handoff — "the complete configuration must also be authenticated as protocol-authorized" — is closed INSIDE the model relative to an explicitly external trusted anchor, and the disposition reads exactly as the handoff requires:

> **complete configuration commitment closed; protocol-root authority remains an explicit assumption.**

This is not "end-to-end security closed": the governance question (who authorizes the anchor, and how it may change) is outside the model and remains open.

## 2. Starting point and ground rules

- **Base.**  `82f0675` = `phase1i-r2-complete` (frozen).  All work is additive under `phase1i-r3/`; `git diff 82f0675 HEAD -- phase1g phase1h phase1h-r1-fix phase1i phase1i-r1 phase1i-r2 k python-gen` is EMPTY; the two in-place-regenerated 1H-R1 transcript JSONs and `kore-exec.tar.gz` were restored byte-exact before committing (the disclosed R2-session behavior; audit §G).
- **Isolation.**  `SRW3PROTO-R3` imports only `SRW3AUTHZ`.  The legacy commands of 1I/R1/R2 are absent from the reachable syntax and the rule set; every legacy name is demonstrated ill-formed (`T10`, `T11a`–`T11f`).
- **Frozen formulas.**  `PolicyCommitment`, `CtxDigest`, `BlockCommit`, and the comparison `SRW3Root` keep the frozen tags/composition (PROVED correspondence claims); the ONLY replaced formula is the configuration-root preimage, superseded by the R3 domain-separated encoding; the frozen shape survives solely as the labeled regression-witness oracle `LegacyR2ProjectionR3W` in `proofs/r3_fixtures.k`.
- **Label discipline.**  PROVED (mechanized, Haskell backend unless stated) / DEMONSTRATED (concrete real-Keccak execution) / WITNESSED (concrete countermodel) / ASSUMED (named trust input) / REFUTED / NOT MECHANIZED (retained failure + error class + substitutes) are kept strictly separate throughout.

## 3. The repair design

**State (handoff §5).**  `<srw3protoR3>` carries the pinned 13-field configuration (reserved key −1), the receipt pool (−2), the protocol chain head, the separate evidence-lineage head, and the NEW immutable anchor cell `<r3anchor>` filled by `$SRW3R3ANCHOR`.  K admits one `<k>` cell per definition; the anchor is a SIBLING cell, not map data, so it is structurally outside the command stream's reach.

**The canonical encoding (handoff §3, normative).**

```text
ProtoCfgCanonR3(C) = "SRW3/ProtoCfg/R3"||0x00 || U32BE(1)
  || LP32(chainId) || U32BE(policyVersion) || LP32(policyDigest)
  || LP32(appSetDigest) || LP32(graphDigest) || LP32(clientConfigDigest)
  || LP32(execClientDigest) || LP32(fork) || LP32(schedule)
  || U32BE(specVersion) || U32BE(authProofType)
  || LP32(authGuestDigest) || LP32(authConfigDigest)
LP32(x) = U32BE(len(x)) || x ;   ProtoRootR3(C) = LinH(ProtoCfgCanonR3(C))
```

`U32BE` is unsigned 4-byte big-endian (the frozen `I2B4` discipline); every byte field is length-prefixed, so adjacent fields are unambiguous (the `("A","BC")` vs `("AB","C")` pair encodes differently — PROVED).  Integer validation is enforced in the Python encoder (negative/>2³²−1/bool → `ValueError`/`TypeError`); in K a garbage integer leaves `I2B4` undefined, so the configuration has no preimage and cannot pass the init equality — fail-closed by construction.

**The verdict is computed, never supplied (the R1/R2 discipline, retained).**  `pGateEvalR3` takes evidence objects and client-derived execution results only; it constructs the authority context from the PIN (authorized `SecCtx` + pinned authority triple), supplies the position (slot counter, lineage anchor), evaluates the frozen `VerifyLineageG`, and stores the computed verdict — together with the computed R3 root and the anchor — in the receipt.  `pAcceptR3` requires the DERIVED decision of the COMPUTED verdict (only `valid-g` maps to protocol-valid; fail-closed), re-checks every binding against the pinned configuration, the receipt's anchor and computed root, and consumes the receipt exactly once.

**Receipt fields (R3).**  candidate, execution results, exact gate inputs, computed verdict, protocol head, slot, lineage head, pinned configuration, **computed root `ProtoRootR3(cfg)`**, **anchor**.

## 4. The K proof ladder — 47 PROVED / 3 NOT MECHANIZED (retained) + 1 structural

Backend: Haskell (`kprove`); the proof definition is compiled from `r3_fixtures.k` (main module `SRW3PROTO-R3-FIXTURES`) because K proof modules admit only claims/simplification rules — the fixture module adds inert constants and no transition rules (audit §A/§F).  Full per-claim table: `transcripts/k/claims-status.csv` (+ `claim-classification.csv`); score convention: `score.txt` = proved/failed counted 1:1 over the 50-claim inventory (the R2 `3 0` ambiguity is explicitly corrected).

| Family | Claims | Result |
|---|---|---|
| Canon (13-field serialization) | R3-CANON-FIELD-ORDER (349-byte golden equality), R3-CANON-DOMAIN-PREFIX, R3-CANON-LENGTH-DELIMITED, R3-BINDS-FIELDS-1-8, R3-ROOT-BINDS-AUTHORITY-FIELDS-F09..F13 (×5), R3-R2-ALIAS-WITNESS, R3-DOMAIN-SEPARATION | 11/11 PROVED |
| Init / anchor | R3-INIT-PINS-AUTHORIZED, R3-INIT-ROOT-MISMATCH-REJECTS, R3-CONFIG-IMMUTABLE | 3/3 PROVED |
| Mint shape | R3-MINT-SHAPE-EXISTING-POOL, R3-MINT-SHAPE-EMPTY-POOL, R3-CONFIG-FRAME-GATE | 3/3 PROVED |
| Headline | R3-ACCEPT-IMPLIES-COMMITP (guard verbatim ⇒ CommitPR3, CommitP only in destination), R3-VALID-ACCEPT, R3-CONFIG-FRAME-ACCEPT | 3/3 PROVED |
| Decision / gatelink | R3-DECISION-BOUND, R3-GATELINK-VALID, R3-GATELINK-REJECT1..3 | 5/5 PROVED |
| Forged / computed rejection | R3-FORGED-VERDICT-REJECT, R3-FORGED-VERDICT-REJECT-AUTHTYPE | 2/2 PROVED |
| Fail-closed rejects | R3-REJECT-{NO-POOL, EMPTY-POOL, WRONG-CANDIDATE, STALE-HEAD, STALE-LINHEAD, WRONG-SLOT, GATE-INPUT-MISMATCH, CONFIG-SUB, ANCHOR-MISMATCH}, R3-RECEIPT-SINGLE-USE | 10/10 PROVED |
| Ported frozen ladder | PI1-COMMIT-SAFETY, PI2-{DECISION-REJECT, DECISION-UNKNOWN, EXEC-INVALID}, PI5-AUTHORITY-DESCENT, PI7-BASE | 6/6 PROVED |
| Correspondence | R3-CORRESPONDENCE-{POLICY-COMMITMENT, CTX-DIGEST, BLOCK-COMMIT, ROOT-R3} | 4/4 PROVED |
| Pipelines / closure | R3-PIPELINE-HONEST, R3-PIPELINE-FORGED, R3-ALL | **0/3 — NOT MECHANIZED (retained)** |
| Structural | R3-ANCHOR-IMMUTABLE (no rule writes `<r3anchor>`; no command takes it) | audit-verified scan + per-rule frame conjuncts |

The three retained labels inherit KNOWN blocker classes, not new ones:

- `R3-PIPELINE-HONEST` / `R3-PIPELINE-FORGED` — `ErrorBottomTotalFunction`: the same Haskell stuck-term boundary over the computed verdict that R2 recorded for its pipeline claims (logs retained).  Substitutes: the mechanized R3-VALID-ACCEPT (non-vacuity, PROVED) plus the concrete LLVM/Python pipelines below.
- `R3-ALL` — the kore circularity/implication blocker recorded since frozen PI7-ALL, R1-ALL, R2-ALL (2.7 MB log retained).  Substitutes: the per-claim ladder, the producer-exhaustiveness audit (audit §B), and the command-surface enumeration (audit §A).

**New R3-specific hs boundary (disclosed; `T12-hs-init-root-check-boundary.txt`).**  Because R3's init performs a REAL-KECCAK equality, the honest pipeline cannot be executed concretely on the Haskell backend at all (krun exits 124 with unevaluated `Keccak256raw` terms at the init check).  This boundary exists precisely because of the repair: R2's init had no root check because its root omitted fields 9–13.  Concrete pipeline evidence therefore lives on the LLVM shim and in Python; on the Haskell backend the equality is carried as a claim hypothesis (R3-INIT-PINS-AUTHORIZED, PROVED).

## 5. Concrete execution — LLVM + krypto shim (real Ethereum Keccak-256)

The demo definition is compiled with the pinned shim (multiblock-fix marker-checked).  The anchor is passed as the authenticated configuration input; its value is the Python-mirror real-Keccak root of the demo configuration — and the K machine recomputes that root with the shim and agrees byte-for-byte (`T0`: `cfgr3root = 207799d4…`; init passes).

| Transcript | Demonstration |
|---|---|
| T0 | cross-layer byte certificate: the complete 282-byte canonical preimage + root of the demo config, the schedule-mutated root (DIFFERENT), the frozen policy/ctx/block/SRW3 digests, both certificate identities (`certid0` anchors to the frozen 1G value), computed verdicts (`valid-g` ×2) |
| T1 | honest two-block pipeline under the SAME full config root: authorized init → computed verdict → commit ×2 (head = `b346c1b0…` → `53d8cc75…`, matching Python byte-for-byte) |
| T2 | gate-only: the receipt is minted (computed verdict + root + anchor); NO chain state moves |
| T3/T4 | accept with no receipt → fail-closed; re-initialization refused |
| **T5** | **schedule-mutated configuration (field 9 — the R2 alias class) re-presented under the authorized root → REFUSED (real-Keccak root mismatch); no pin** |
| T6 | the honest configuration on a machine anchored at a DIFFERENT protocol root → REFUSED |
| T7/T8/T9 | config-version substitution; slot-1 candidate at slot 0; evidence bound to a different payload — all refuse |
| T10, T11a–f | the verdict injection and every legacy command name are ILL-FORMED (kparse) |
| T12 | the Haskell-backend init-check boundary (disclosure transcript) |

## 6. Python mirror, golden vectors, and cross-layer agreement

`r3_model.py` mirrors the K machine rule-for-rule (guard order included; the anchor is set once OUTSIDE the command API — no method ever writes it).  The handoff pack's reference encoder is integrated VERBATIM (input hashes in `provenance/PROVENANCE.md`) and injects the frozen real-Keccak `H`; SHA3-256 is never substituted (the suite asserts the two disagree on the same preimage).

- **Golden vectors** (`vectors/config-root-r3.json`, generated + committed): the 349-byte golden preimage and root; 13 per-field mutation vectors (each preimage AND root differs); the length-ambiguity pair; the R2-alias witness (legacy preimages EQUAL, R3 roots DIFFER); domain-separation prefixes; the invalid-input table.
- **Unittests** (`tests/test_config_root_binding.py`): **21/21 PASS** — the pack's 11 reference tests verbatim (Part 1) + vector-file conformance + machine-level root-binding discipline (Part 2).
- **Adversarial suite** (`run_r3_attacks.py`): **181/181 PASS** across KX (cross-layer certificate, byte-for-byte vs the K shim run), HONEST, INITROOT (the decisive group: honest init; every field-1..13 mutation refuses under the old root; wrong-anchor machine refuses; a caller-supplied replacement root is INEXPRESSIBLE — arity TypeError), ROOTBIND, INTS, INJ (the injection is ill-formed; the UNMODIFIED R1 logic demonstrably accepts the caller-typed verdict — before side; R3 refuses with state unchanged), VERDICT (computed rejection classes), BIND, ALT, CFG, STALE, CROSSROOT (receipts cannot replay across roots/anchors/configs — even an out-of-model injected receipt is refused by the root/anchor/config conjuncts), POOL, MAL, LEG, DET (determinism).
- **Regression (zero drift)**: LID 11/11 · SCT 26/26 · attack matrix 30/30 · determinism 15/15 · reorg/replay 17/17 · fork-choice 16/16 · R1 attacks 48/48 · R2 attacks 87/87 — all frozen suites re-run from the R3 branch against the untouched frozen trees; transcripts under `transcripts/regression/` (the two invocation adaptations — cwd for the R1 suite's relative paths, PYTHONPATH for the R2 suite's stale absolute inserts — are disclosed in the transcript headers).

## 7. Trust boundaries and scientific claim limits

1. **Keccak collision resistance** (ASSUMED): "differing configurations ⇒ differing roots" is demonstrated concretely; the general statement is conditional; no hash-injectivity theorem is claimed.
2. **Protocol-root authority** (ASSUMED, explicit): `$SRW3R3ANCHOR` models the trusted genesis/config-root channel; governance, root updates, and anchor rotation are out of scope (no upgrade transition exists in the machine).  R3 proves complete commitment RELATIVE TO THAT ANCHOR.
3. **Gate soundness**: the verdict is the frozen `VerifyLineageG` result (mechanized in frozen Phase 1G); R3 adds no trust to the gate.
4. **Evidence authenticity**: caller-presented evidence objects are a faithful execution record only through the frozen gate's own replay/binding layers (unchanged from R1/R2; the Phase 1F/1H limitations stand).
5. **Haskell backend**: hash hooks uninterpreted (finding 1C-1); hash-class equalities are hypotheses on hs, concrete on LLVM/Python; the pipelines are hs-stuck (retained) — §4.
6. **Python mirror**: executable evidence, not a formal proof.
7. **Level-III model only**: nothing here modifies or claims to modify any real Ethereum consensus component.

## 8. Completion gates (handoff §9 checklist)

- [x] full 13-field canonical encoding implemented in K and Python (PROVED golden equality; byte-for-byte cross-layer agreement);
- [x] root checked against an immutable, explicitly authenticated protocol anchor (or the remaining external assumption clearly stated — §D-B of the audit);
- [x] all authority mutation attacks fail under the original root (K F09..F13 PROVED; LLVM T5; Python INITROOT/ROOTBIND);
- [x] honest init, valid gate, valid accept, and two-block continuation succeed (K R3-INIT-PINS-AUTHORIZED / R3-VALID-ACCEPT PROVED; LLVM T1; Python HONEST);
- [x] R3 headline and available negative claims actually run, logs retained (47 PROVED; 3 retained NOT MECHANIZED with error classes; 1 structural with a mechanical scan);
- [x] R2 and earlier frozen artifacts unchanged (audit §G; git-verified);
- [x] reports distinguish mechanized claims from demos and assumptions (§4 labels; `claim-classification.csv`).

## 9. Verdict

**CLOSED for complete configuration commitment (Level-III, relative to the explicit authenticated anchor) — with the protocol-root authority remaining an explicitly declared external assumption.**  The R2 alias is closed mechanically and concretely; initialization and acceptance are anchored to an authenticated protocol root that no caller and no command can substitute; invalid configurations cannot enter the machine under any root they do not hash to, and valid blocks still commit under the authorized root.  The named boundaries (collision resistance, anchor governance, evidence authenticity, hs hash hooks) are disclosed and unchanged.  No consensus-integration claim is made; Phase 1J / the prior-art novelty audit remain NOT started (next task only after review).
