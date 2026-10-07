# SRW3 Phase 1G — Authority-Rooted State and Execution Evidence

**Status: PHASE 1G EXECUTED — the authority boundary is answered with a
qualified, boundary-honest result: authority is INHERITED, NOT CREATED. The
non-circular authority machinery is PROVED (branch-wise + accept direction),
the authority graph is mechanically acyclic, every self-authorizing /
substitution attack in the CM-G set is REJECTED at an exact diagnosed layer,
and the smallest authoritative integration point is DEMONSTRATED over real
EVM execution (Mode A). The protocol root's own authority is the explicit,
structured assumption A-G2 that replaces A-E3 — in deployment it is the
Engine-API boundary and remains REQUIRES CLIENT/PROTOCOL SUPPORT.**

This report was produced from the `phase1g` branch derived from the Phase 1F
closure commit (`b6c651e0...`), on a rebuilt toolchain (K v7.1.337, Z3
4.13.3-1, clang/LLVM-15 15.0.6-4+b1, KEVM v1.0.921 source, blockchain-k-plugin
@ 207ae512, krypto shim rebuilt with the keccak-multiblock fix). The frozen
layers were not modified: `git diff` over `k/`, `python-gen/`, `phase1e/`,
`phase1f/` against the Phase 1F tip is empty, and every Phase 1G extension is
additive (`azCtx` / `linRecG` discipline; the KEVM authority adapter requires
+ imports the frozen modules).

## 1. Research question and answer

**Question.** Can SRW3 obtain and bind its authoritative state root and
execution evidence from the execution/consensus layer WITHOUT circular
trust, so that the commitment gate evaluates security obligations over
evidence whose authority is grounded in the protocol/client execution
process rather than merely supplied as an external assumption?

**Answer: PARTIALLY PROVED — authority is formally INHERITABLE, and the
inheritance is mechanized end-to-end; the chain's ROOT is protocol-given.**
The gate was extended (additively) so that acceptance (`valid-g`, 21 atomic
conjuncts) requires, on top of the full Phase 1D-R1 + 1E + 1F certificate:

1. an AUTHORITY CERTIFICATE bound field-by-field to the record (payload
   digest, parent root, execution identity, child root, effect-trace
   digest) and to the security-policy version (`invalid-authbind`,
   `invalid-policy`);
2. the certificate's authority source to be an AUTHORIZED identity derived
   ONLY from the verification context — chainId, fork config, policy
   version, pinned proof descriptor — never from the certificate itself
   (`invalid-authsrc`, the definitional non-vacuity of
   `IndependentAuthoritySource`);
3. the authority relation to exist and to match the source domain, with the
   claimed level equal to the domain's level (`invalid-authtype`,
   `invalid-authrel`, `invalid-authlevel`);
4. the authority chain to be NON-CIRCULAR: the certificate never cites
   itself (neither in its chain nor as its own source), every chain step
   carries an authorized identity, levels strictly decrease, and the chain
   terminates at a level-0 protocol root — consensus or policy
   (`invalid-authcircle`);
5. the security context to be pinned (`policyV`, chainId, application set,
   interaction graph, lineage head) — the architectural bridge between
   execution validity and SRW3 security validity.

What this result IS NOT, stated plainly: the model's protocol roots
(consensus identity for chainId; the pinned producer identity sets; the
policy version's own authorization) are protocol-given INPUTS (A-G2/A-G3/
A-G7). SRW3 verifies that authority chains terminate at a protocol root and
never at themselves — authority is INHERITED by SRW3, not created. In a real
deployment the consensus→execution boundary is the Engine API and the root
becomes authoritative inside the consensus process: that last step is
REQUIRES CLIENT/PROTOCOL SUPPORT (PROVED for the formal adapter at the model
layer; the deployment gap is stated, not hidden). The Phase 1E/1F boundaries
(A-E3 as the bare-anchor assumption; A-F3 trace authenticity at the abstract
layer) are REPLACED at the Gate_G level by structured, checkable authority —
the frozen verdicts themselves remain unchanged (frozen-layer discipline).

## 2. Starting state and environment

The session began from a sandbox reset (the 7th). The repo was re-cloned
from GitHub; `phase1e` @ `8b26cb74` and `phase1f` @ `b6c651e0` were verified
on the fetched history before `phase1g` was derived (no history rewrite).
The toolchain was rebuilt from the pinned recipe with two recorded
deviations: (a) the K deb download truncated at 43/181 MB (resumed;
`dpkg-deb -c` verified: 488 archive entries, 432 files); (b)
`libclang-common-15-dev` is downloaded by `rebuild_env_1d.sh` but missing
from its extract loop — `stddef.h` was absent for the shim build (extracted
manually; the 1D recipe note anticipated the dependency). New setup script:
`scripts/phase1g/setup_env_1g.sh` (clang path patch, syslibs shims, shim
rebuild, env.sh). Symlinks are forbidden by the sandbox — the working repo
was renamed to the canonical path instead (recorded).

The frozen Python layers re-verify transitively on every 1G case: the 1G
Python suite imports and RUNS the full 1D→1E→1F chains (the b02 mutation
re-demonstrates the 1F `L14-ANCHOR` catch).

## 3. The authority model (FROZEN)

`phase1g/semantics/MODEL.md` is the normative specification. Design points:

- **Four separations (never collapsed).** Evidence validity
  (`Verify(root, evidence) = true`), evidence authority
  (`root = protocol/client-authoritative`), execution validity
  (`execution(payload, pre) = post`), SRW3 security validity (obligations
  satisfied). The investigated relation: Authority → Authenticity →
  Execution validity → State/effect binding → Security validity →
  Commitment.
- **Authority domains and levels.** `domConsensus`/`domPolicy` at level 0
  (protocol authorization roots), `domExecution`/`domProof` at level 1
  (evidence producers); the certified object sits at level 2. Authority
  flows strictly from lower to higher.
- **AuthorityCertificate.** `azCert(payloadD, parentRoot, execId, childRoot,
  effectD, rel, src, chain, policyV, proofPub)` with `rel ∈ {1,2,3}`:
  1 = consensus-authorized payload executed by the authorized client (the
  Engine-API-modeled path), 2 = re-execution-derived (**Mode A**), 3 =
  proof-checked (**Mode B**). The source carries (domain, id, level); the
  chain carries the authority path above the source.
- **Authorized identities are CONTEXT-derived** (tags `0xA1..0xA4`):
  `ConsensusId(chainId)`, `ExecClientId(chainId, configD)`,
  `ProofSysId(authPT, authGuestD, authCfgD)` (the descriptor PINNED in the
  context), `PolicyAuthId(policyV)`. No check ever consumes the certificate
  to define what counts as authoritative — the §18 requirement at the
  definitional level.
- **NoCircularAuthority.** `certId ∉ chain-ids ∧ srcId ≠ certId ∧
  AzChainOk(chain, srcLevel, ctx)`: strict level decrease, EVERY chain step
  authorized (context-derived checks — a producer cannot park an arbitrary
  claimed id and call it consensus), termination at an authorized level-0
  protocol root (empty chain valid iff the source is itself level 0). Strict
  decrease + level-0 termination imply acyclicity. The fully
  self-referential certificate is a hash fixpoint — excluded mechanically by
  the own-id checks and computationally by A-G1.
- **SecurityContext.** `secCtx(policyV, chainId, appSetD, graphD,
  lineageHead)` — the policy binding is part of the accept condition
  (`invalid-policy`); the policy's OWN authority is protocol/governance
  input (A-G7, disclosed; no in-model derivation — no infinite regress).
- **Record.** `LinRecG = (LinRecF, azCertD, azPolicyV)`; `CanonCoreG =
  CanonCoreF ‖ azCertD ‖ policyV₄` — CanonCoreF a STRICT PREFIX; childE and
  childF carried unchanged (mechanized: AZR3/AZR4).
- **proofPub (Mode B public inputs).** `H(0x8D ‖ payloadD ‖ parentRoot ‖
  chainId ‖ sched₈ ‖ spec₄ ‖ childRoot ‖ policyV₄ ‖ appSetD ‖ graphD ‖
  lineageHead)` — beyond the EIP-8025-style bindings (payload identity,
  chain ID, schema/fork, child root), SRW3 adds the security-policy version,
  application set, interaction graph, and lineage head.
- **Domain tags** `0x8C/0x8D/0x8E/0xA1..0xA4` — collision-free against the
  frozen set (audited: the frozen tags are `0x00..0x03`, `0x11..0x13`,
  `0x1F`, `0x57`).

## 4. Gate_G (first-fail, total; 21 atomic conjuncts)

`VerifyLineageG(recG, azCtx, tid, head)`: the full 1F chain fires first
(all its verdicts unchanged), then the SEVEN new authority layers —
`invalid-authtype` (rel ∉ {1,2,3}), `invalid-authrel` (rel↔domain
mismatch), `invalid-authlevel` (claimed level ≠ domain level; CM-G3a),
`invalid-authcircle` (NoCircularAuthority fails; CM-G1/2/3b — checked
BEFORE source authorization so self-referencing certificates are diagnosed
as circular even when their source could not be authorized), `invalid-
authsrc` (source ≠ context-derived authorized identity; CM-G6/G10),
`invalid-authbind` (certId recomputation + the five field bindings + the
proofPub rule; CM-G4/5/7), `invalid-policy` (CM-G8) — and `valid-g`.

**A-E3 replacement (the §7 experiment).** Under valid-g:
`anchor == stateRoot == cert.childRoot` where the certificate is
non-circular and protocol-rooted — the anchor is no longer a bare assumption
at the Gate_G level; it must CARRY authority. The frozen `valid-a` verdict
is unchanged (the replacement applies to the commitment decision, which now
requires valid-g).

## 5. Mechanized proofs (Haskell backend, kprove)

`phase1g/proofs/` — 28 claims; 21 PROVED, 3 designed-fail, 4 disclosed
(the per-claim raw outputs + exit codes are recorded verbatim):

| Group | Claims | Outcome |
|---|---|---|
| Record binding: CanonCoreF strict prefix, childG binding, childE/childF invariance | AZR1-AZR4 | 4 PROVED |
| Gate_G branch-wise verdict exactness (each new verdict exactly its layer condition) | AZB1-AZB7 | 7 PROVED |
| Accept direction (the 21-conjunct accept ⟹ valid-g, no acceptance slack) | AZBACC | 1 PROVED |
| Authority-binding theorem classes under the full accept (payload/parent/execId/effect/childRoot) | AZG1-AZG5 | 5 PROVED |
| Negative controls (designed fail: circular/unauthorized must never be accepted; vacuity probe) | NCG1-NCG3 | 3 designed NOT-PROVED (correct) |
| Single-implication forms over fully symbolic data | AZR5, AZNCS, AZCHS, AZCHG | 4 NOT PROVED — DISCLOSED |

The four disclosed attempts share the 1F EXGATE boundary: they require
UNFOLDING a hash over a symbolic certificate (the premise-side
`AzCertBindOk` contains `AzCertId(C)`, which cannot evaluate for symbolic
C — the NC1 keccak-injectivity precedent). Their CONTENT is carried by the
proved claims: AZR5's five field equalities are AZG1-AZG5 (PROVED under the
full accept) plus the digest binding consumed by AZBACC; the non-circularity
content of AZNCS is consumed by AZBACC (the accept direction) and AZB4
(the verdict exactness); AZCHG's anchor half is carried by AZG5 + the frozen
1E anchor layer + the CM demonstrations (stale anchors rejected at
`L14-ANCHOR`; child-root substitution rejected at `invalid-authbind`).

Non-vacuity: the accept premise is SATISFIABLE — `valid-g` is a permanent
demo case for rel=1/2/3 on the LLVM backend with real keccak + secp256k1,
mirrored by the Python suite; NCG3 (the vacuity probe) fails as designed.

## 6. The abstract demonstration suite (LLVM, real krypto)

`srw3authz-demo.k` — 8 partitioned programs (the concatenated suite exceeds
the 3 GB sandbox as ONE term; the 1F precedent; no case skipped) —
**7/7 PASS** plus the byte program:

| Case | Construction | Verdict |
|---|---|---|
| pos0 | honest oracle record, rel=1 consensus-authorized | valid-g |
| pos1/pos2 | lending threaded on R0's root (rel=1); liquidation with a Mode A certificate (rel=2, chain = [consensus root]) | valid-g ×2 |
| pos3 | Mode B over R0 (rel=3, authorized proof descriptor, proofPub bound incl. policy/appSet/graph/lineageHead) | valid-g |
| g1 (CM-G1) | self-authorizing anchor: chain cites an unauthorized id as its consensus root | invalid-authcircle |
| g2 (CM-G2) | the source id is a CERTIFICATE-derived id (never a protocol identity) | invalid-authsrc |
| g3a (CM-G3a) | the client claims level 0 | invalid-authlevel |
| g3b (CM-G3b) | client-sourced certificate with NO consensus chain | invalid-authcircle |
| g4 (CM-G4) | payload substitution | invalid-authbind |
| g5 (CM-G5) | parent-root substitution | invalid-authbind |
| g6 (CM-G6) | fork/config substitution: the client authorized under fork A, evaluated under fork B | invalid-authsrc |
| g7 (CM-G7) | child-root substitution | invalid-authbind |
| g8 (CM-G8) | policy substitution (cert policyV=2 vs SecCtx policyV=1) | invalid-policy |
| g9 (CM-G10) | proof from an unauthorized proof type | invalid-authsrc |
| g9b (CM-G10) | authorized proof source, proofPub does not recompute | invalid-authbind |
| g10 | unknown authority relation (rel=4) | invalid-authtype |
| g11 | rel↔domain mismatch | invalid-authrel |
| bal1 | honest BAL: footprint + post-values bind | true |
| bal2 (CM-G9a) | omitted touched location — detected against the digest-bound trace | false (detected) |
| bal3 (CM-G9b) | the STALE-READ attack: BAL footprint=true ∧ writes=true while the ordered-trace evidence says invalid-effbind | THE FINDING |
| bal4 (CM-G9) | order blindness: XT2/XT2x share footprint and post-values; trace digests differ | BAL cannot see order |

## 7. Python mirror and mutation harness

`phase1g/python/` mirrors the K semantics exactly (`authz_model.py`) and
re-runs the full case table (`test_authz_verify.py`: **25/25**) plus the
hostile-mutation harness (`authz_mutations.py`: **18/18 as expected**) —
the producer re-signs and re-digests everything forgeable (including
arbitrary certificates with recomputed ids); rejections land at the
documented first-fail layers (m01 digest flip → AUTHBIND; m02 self-chosen
consensus id → AUTHSRC; m03 chain-cites-a-certificate → AUTHCIRCLE; m04
level-0 client → AUTHLEVEL; m05 no consensus chain → AUTHCIRCLE; m06b
non-decreasing chain → AUTHCIRCLE; m07 foreign proofPub → AUTHBIND; m08
unauthorized proof type → AUTHSRC; m09 policy substitution → POLICY; m10
foreign execId → AUTHBIND; m11 foreign childRoot → AUTHBIND; m12 rel/domain
mismatch → AUTHREL; m13 unknown rel → AUTHTYPE; m14 foreign payload →
AUTHBIND; m15 stale parentRoot → AUTHBIND). Documented boundaries: b01 (the
honest rel=2 certificate is accepted — whether the source really is the
protocol's client is the context-pinning assumption A-G3), b02 (the 1F
fully-consistent hidden-write forgery is still caught by the FROZEN Level-2
anchor BEFORE any authority layer runs).

## 8. The authority adapter over real EVM execution (Tier G2)

`k/kevm/srw3-authz-evm.k` (+ demos; `part5_kevm_authz.txt`):

- **The certificate is constructed FROM THE RUN** — Mode A (rel=2): the
  source is the authorized execution client for (chainId, config), the
  authority chain carries the consensus root, and the certificate's effect
  digest binds the EXECUTION-DERIVED trace (the 1F instrumented tracer), so
  `invalid-authbind` forces presented-trace-digest == executed-trace-digest:
  at this layer the presented evidence IS the executed evidence.
- **Demos** (real keccak + secp256k1; commit/lineage atomicity preserved):
  - `evm_authz_commit` — honest run + adapter certificate: **valid-g →
    COMMIT** (the lineage record now carries the authority certificate);
  - `evm_authz_selfauth` — the SELF-AUTHORIZING variant (the client claims
    LEVEL 0, CM-G3a): **invalid-authlevel → REJECT + RESTORE** — the model
    does not accept "client output as unquestionable authority" even at the
    execution layer;
  - `evm_authz_tamper` — tampered presented trace: **invalid-effdecl →
    REJECT + RESTORE** (the FROZEN 1F chain diagnoses first — the layering
    discipline holds over real execution).
- **Memory-ceiling workarounds (documented, no case skipped).** (a) The
  adapter's certificate takes the F record as an ARGUMENT (projections
  only) — recomputing the Merkle build inside the cert OOM-killed the
  commit demo. (b) The KEVM harness evaluates the F chain ONCE and then the
  seven authority layers in isolation (`#w3AzVerdict` — the same verdict
  surface with the F half guaranteed by the dispatch; the integrated
  `VerifyLineageG` remains the canonical form, proved at the abstract layer
  and green in the abstract demos). The first-fail cascade over real EVM
  state is 9³ PE-chain evaluations — a sandbox-ceiling artifact, not a
  semantic one.
- Model chain identity `#w3AzChainId = 0x00000001` (matches `-cCHAINID=1`;
  the KEVM config plumbing is not modified — fragment boundary).

## 9. Cross-layer byte consistency

`scripts/phase1g/part6_crosslayer.py` (`part6_crosslayer_bytes.txt`): **10/10
byte-equality checks MATCH** across Python ↔ K-abstract (llvm, real krypto):
cert body, certId, consensus/exec-client/proof-system/policy identities,
proofPub, childG, CanonCoreG, BAL canon.

`scripts/phase1g/part6b_kevm_cert.py` (`part6b_kevm_cert.txt`): **7/7 MATCH**
across Python ↔ the REAL KEVM run — the AUTHORITY CERTIFICATE of the actual
execution is rebuilt in Python from first principles (payload, the
`#w3FParRoot` parent root, the recomputed execution identity, the 1F anchored
child root, the EXECUTION-derived trace digest, the Mode A source, the
consensus-rooted chain) and is byte-identical to the certificate the real run
committed (the commit run's `linAzCertD` == the dbg carrier's certId == the
Python rebuild = `a36cfab4...4b9fef`); the executed-trace digest == the
presented-trace digest (`4a3a1f19...`); the authorized consensus/exec-client
identities match. Three-layer byte consistency: **Python ↔ K-abstract ↔ KEVM
(real execution) — 17/17 MATCH**.

## 10. Prior-art positioning (targeted, live-fetched; `part7_prior_art.txt`)

Sources fetched this session (sha256 recorded in the transcript): EIP-8025
(Draft, Core), EIP-7928 (Last Call, Core), EIP-8159 (Last Call, Networking),
the Engine API spec (engine_newPayloadV1).

| Technique | What it already provides | The SRW3 delta |
|---|---|---|
| EIP-8025 execution proofs | opt-in consensus-layer stateless payload verification; public input binds NewPayloadRequest + chain ID + schema + validation result; verified proofs are "a supplementary validity signal, not a replacement for re-execution" | 8025 does NOT make proof-checked authority load-bearing; no security-policy binding, no lineage, no authority structure. SRW3's proofPub additions (policyV, appSetD, graphD, lineageHead) and the rel/level/chain non-circularity are the delta; the proof math stays REQUIRES EXTERNAL PROOF SYSTEM (8025 is the natural host) |
| EIP-7928 BALs (enforced) | accounts + storage locations + post-execution values; tx-level write attribution; `storage_reads` = read-only KEYS ONLY | structurally confirms the 1G BAL findings: read OBSERVATIONS absent (the oracle-staleness class invisible), intra-tx same-slot order absent (F4 class invisible); BAL can serve as an independent footprint CROSS-CHECK (bal2: omission detected) but is NOT a security effect trace |
| EIP-8159 BAL exchange | p2p transport of BALs | networking only; no authority, no commitment mediation |
| Engine API | the consensus/execution boundary; `{status, latestValidHash}` | exactly the modeled level-0→1 edge; the root becomes authoritative through the consensus process; the smallest SRW3 insertion point that does NOT violate the separation is a post-execution hook exposing (payload, parentRoot, result, childRoot, evidence) — making a gate REJECT consensus-visible is REQUIRES CLIENT/PROTOCOL SUPPORT (Tier G3, not attempted) |
| Stateless witnesses / zkEVM | state-piece authentication; generic execution validity | the frozen standing distinction (generic validity ≠ SRW3 security validity) applies verbatim; complementary as a future Mode-B proof source |

No surveyed system models AUTHORITY as distinct from authenticity with a
non-circularity obligation. The comparison upgrades no evidence tier.

## 11. The two authority paths — comparison finding

**Mode A (re-execution, rel=2)** closes the 1F trace-authenticity boundary
WHERE THE VERIFIER EXECUTES: demonstrated at Tier G2, where the certificate
is derived from the run itself and the presented evidence must equal the
executed evidence. **Mode B (proof-backed, rel=3)** delegates the execution
claim to an external proof system: SRW3 mechanizes the public-input binding
and the source authorization; the proof math is REQUIRES EXTERNAL PROOF
SYSTEM. **Neither mode eliminates A-G2**: both INHERIT authority from the
consensus root of the chain (the Mode B certificate's chain also terminates
at consensus). "Do not assume proof-backed execution is automatically more
authoritative" — confirmed: Mode B's authority is exactly as rooted, and
its execution claim is as strong as the proof system's soundness (A-G6),
whereas Mode A's execution claim is as strong as the client's own
re-execution inside the verifier's trust domain.

## 12. Consensus boundary (§9 questions, answered by the model + prior art)

Who authorizes the payload — the consensus layer (level 0; the Engine-API
modeled edge). Who authorizes the execution context — the protocol pins the
fork config and the authorized client identity per (chainId, config). Who
determines the expected parent — the consensus chain (the payload's
parentRoot binding). Who determines the expected resulting root — the
execution client derives it; consensus makes it authoritative by
authorizing the payload whose execution produced it. Who can invalidate —
consensus (via fork choice), not the EL alone (Engine API: `{status:
INVALID}` is a response, not a finality decision). At which layer does the
root become authoritative — inside the consensus process (fork choice /
finalization), which is exactly why the model's root is protocol-given
(A-G2). At which layer may SRW3 legally reject — at its own commitment
point: SRW3's REJECT is a refusal to commit security obligations, NOT a
consensus invalidation (the separation is preserved by construction).

## PHASE 1G RESULTS

```
Research question:               can SRW3 obtain and bind its authoritative
                                 state root and execution evidence from the
                                 execution/consensus layer without circular
                                 trust?
Status:                          PARTIALLY PROVED — authority is formally
                                 INHERITABLE and the inheritance is mechanized
                                 end-to-end (21 kprove claims PROVED); the
                                 chain's ROOT is protocol-given (A-G2): the
                                 deployment-side grounding is REQUIRES
                                 CLIENT/PROTOCOL SUPPORT

Authority model:                 AuthzDomain(level 0: consensus/policy; level 1:
                                 execution/proof) + AuthorityCertificate(rel
                                 1/2/3) + authority chain + SecurityContext;
                                 authorized identities CONTEXT-derived only
Authority graph:                 nodes = protocol roots, evidence producers,
                                 the certified object (level 2); edges =
                                 authorizes/derives/verifies/binds/commits;
                                 attestation carries NO authority; acyclicity
                                 = strict level decrease + level-0 termination
                                 (mechanized in AzChainOk/AzNonCircular)

Payload authority:               PROVED BY K (AZG1: accept binds
                                 cert.payloadD == PayloadDigest(presented))
Parent-root authority:           PROVED BY K (AZG2: cert.parentRoot == the
                                 threaded 1E parent root)
Execution authority:             binding PROVED BY K (AZG3: cert.execId ==
                                 the recomputed ExecutionId); result authority
                                 DEMONSTRATED BY KEVM (Mode A re-execution;
                                 presented == executed forced by authbind);
                                 Mode B REQUIRES EXTERNAL PROOF SYSTEM
Effect authority:                PROVED BY K (AZG4: cert.effectD == the
                                 digest-bound ordered trace digest)
Child-root authority:            PROVED BY K (AZG5: cert.childRoot ==
                                 stateRoot; with the frozen anchor layer this
                                 is the A-E3 replacement at the Gate_G level)

Authority source:                context-derived identities only (0xA1..0xA4);
                                 the certificate is never an input to its own
                                 authorization (definitional non-vacuity)
Authority verification:          recomputation at every layer (certId, source
                                 identity, chain steps, level discipline,
                                 binding, policy)
Authority provenance:            the chain terminates at an authorized level-0
                                 protocol root; provenance beyond that root is
                                 protocol-given (A-G2) — REQUIRES CLIENT/
                                 PROTOCOL SUPPORT in deployment

Non-circularity theorem:         AZB4 (verdict exactness) + AZBACC (accept
                                 consumes the non-circularity conjunct):
                                 PROVED BY K branch-wise; the single-form
                                 AZNCS disclosed (symbolic-hash boundary);
                                 the fully self-referential certificate is a
                                 hash fixpoint (mechanically excluded +
                                 computationally infeasible under A-G1)
G1:                              PROVED BY K (AZG1)
G2:                              PROVED BY K (AZG2)
G3:                              binding PROVED BY K (AZG3); result DEMONSTRATED
                                 BY KEVM (Mode A); Mode B REQUIRES EXTERNAL
                                 PROOF SYSTEM
G4:                              PROVED BY K (AZG4)
G5:                              PROVED BY K (AZG5)
G6:                              PROVED BY K (branch-wise: AZB4+AZBACC; the
                                 symbolic chain-induction form NOT YET
                                 MECHANIZED, disclosed)
G7:                              PROVED BY K (AZR1-AZR4: strict prefix +
                                 childG binding + legacy invariance)
G8:                              PROVED BY K (AZB1-AZB7 branch-wise + AZBACC
                                 accept direction; single form disclosed)
G9:                              DEMONSTRATED (the 3-record authority chain,
                                 rel=1/1/2 + Mode B over R0, per-record
                                 certificates + lineage-head threading; the
                                 abstract composition claims are ground
                                 demos + the proved per-record certificate)

CM-G1:                           REJECT (invalid-authcircle)
CM-G2:                           REJECT (invalid-authsrc; the exact-fixpoint
                                 variant excluded by the own-id checks + A-G1)
CM-G3:                           REJECT (a: invalid-authlevel; b:
                                 invalid-authcircle) — also demonstrated at
                                 the KEVM layer (evm_authz_selfauth)
CM-G4:                           REJECT (invalid-authbind)
CM-G5:                           REJECT (invalid-authbind)
CM-G6:                           REJECT (invalid-authsrc — the client of fork A
                                 is not the authorized client under fork B)
CM-G7:                           REJECT (invalid-authbind)
CM-G8:                           REJECT (invalid-policy — the lineage pins the
                                 policy version)
CM-G9:                           (a) omission DETECTED against the digest-bound
                                 trace (bal2); (b) the stale-read attack PASSES
                                 every BAL check while the ordered-trace
                                 evidence REJECTS it (bal3) — access list is
                                 NOT a complete security effect trace (also
                                 confirmed at the EIP-7928 spec level:
                                 storage_reads are keys only)
CM-G10:                          REJECT (invalid-authsrc; proofPub mismatch is
                                 invalid-authbind — g9b)

Phase 1E integration:            DONE — the anchor must now CARRY a non-
                                 circular protocol-rooted certificate for the
                                 Gate_G decision (the A-E3 replacement);
                                 the frozen 1E verdicts unchanged
Phase 1F integration:            DONE — the full 1F chain fires first; the
                                 certificate binds the 1F execution identity
                                 and trace digest; at the KEVM layer the
                                 certificate's effect digest binds the
                                 EXECUTION-DERIVED trace (presented == executed)
Lineage integration:             DONE — LinRecG additive; CanonCoreF strict
                                 prefix; azCertD + policyV committed into the
                                 record (childG); legacy chains unchanged
Gate integration:                DONE — the commitment decision requires
                                 valid-g (21 conjuncts); no authoritative
                                 evidence = no security-valid commitment

Access-list analysis:            BAL = footprint + post-values (+tx-level
                                 write attribution); read observations and
                                 intra-tx same-slot order structurally absent;
                                 usable as an independent footprint CROSS-CHECK
                                 only; confirmed against EIP-7928's spec
Execution-proof analysis:        abstract ExecutionProofVerifier; public-input
                                 binding mechanized (incl. the SRW3 additions
                                 beyond EIP-8025); proof math REQUIRES
                                 EXTERNAL PROOF SYSTEM; 8025 currently treats
                                 proofs as supplementary — not load-bearing

KEVM result:                     3/3 demos PASS — honest -> valid-g COMMIT;
                                 self-authorizing (level-0 client) ->
                                 invalid-authlevel REJECT+RESTORE; tampered ->
                                 invalid-effdecl REJECT+RESTORE (frozen 1F
                                 chain diagnoses first)
Client-boundary result:          the adapter IS the smallest authoritative
                                 integration point (post-execution state root
                                 + execution evidence -> authority statement);
                                 demonstrated, not enshrined
Consensus-boundary result:       modeled as the level-0 authorization root;
                                 making a gate REJECT consensus-visible is
                                 REQUIRES CLIENT/PROTOCOL SUPPORT

Python/K consistency:            10/10 authority-layer byte checks MATCH
                                 (P <-> K-abstract, llvm real krypto) + 7/7
                                 Python <-> REAL KEVM RUN (the authority
                                 certificate of the actual execution rebuilt
                                 byte-identically in Python; the commit run's
                                 linAzCertD == the dbg certId == the rebuild)
                                 + 25/25 verdict cases + 18/18 mutations
K/KEVM consistency:              the same module chain (SRW3AUTHZ imported by
                                 the KEVM harness); the 1F tracer supplies the
                                 execution-derived trace; the authority fields
                                 evaluate identically (shared definitions)

What is proved:                  21 kprove claims — the record binding (prefix,
                                 childG, invariances), the branch-wise Gate_G
                                 certificate (7 verdicts exact + accept
                                 direction), the five authority-binding
                                 classes (G1/G2/G3-binding/G4/G5)
What is demonstrated:            the 3-record authority chain (rel=1/1/2 +
                                 Mode B), all CM-G attacks rejected at exact
                                 layers, the BAL findings, the KEVM adapter
                                 over real execution (valid-g COMMIT; self-
                                 authorization REJECTED at the EVM layer)
What is assumed:                 A-G1 keccak collision resistance; A-G2 the
                                 consensus identity as the authorization root
                                 (the structured replacement of A-E3); A-G3
                                 the pinned producer identity sets; A-G7 the
                                 policy version's own authority (governance)
What is refuted:                 "a certificate can carry its own authority" —
                                 every self-authorizing construction is
                                 rejected at an exact layer (CM-G1/2/3, NCG1/2
                                 designed-fail canaries); "access list =
                                 complete security effect trace" (CM-G9);
                                 "proof-backed authority is automatically
                                 stronger" (§11)
What requires client/protocol support:  the consensus-side grounding of A-G2
                                 (the Engine-API boundary); a consensus-visible
                                 commitment gate (Tier G3, not attempted);
                                 verifier re-execution as a service
What requires an external proof system:  Mode B's proof object (A-G6); the
                                 binding is mechanized, the math is not
What remains open:               the single-implication forms over symbolic
                                 data (AZR5/AZNCS/AZCHS/AZCHG — the symbolic-
                                 hash boundary, disclosed; content carried
                                 branch-wise); the tier-3 universal
                                 reconciliation (standing); generalizing the
                                 single-pinned identity sets to membership
                                 sets; symbolic chain-length induction

Authority-bound SRW3 conclusion: SRW3 can REQUIRE, CHECK, and COMMIT-ON
                                 inherited authority — every accepted
                                 commitment now carries a non-circular,
                                 context-authorized, field-bound authority
                                 certificate terminating at a protocol root —
                                 but SRW3 cannot CREATE the root's authority:
                                 the last step from "protocol-given" to
                                 "protocol-verified" is a client/protocol
                                 change, not a verifier-side one

Artifact SHA-256:                SRW3-Phase1G-Artifact-Bundle.zip + .sha256
                                 sidecar (MANIFEST 56 entries, round-trip
                                 ALL OK; the manifest carries every file's
                                 sha256 including this report)
Git branch:                      phase1g (derived from phase1f @ b6c651e0;
                                 no history rewrite of any milestone branch)
Git commit:                      (this closure commit)

Phase 1G completion verdict:     COMPLETE — all 17 completion criteria
                                 evaluated below; no criterion silently waived
```

## 13. Completion criteria evaluation (§28, all 17)

| # | Criterion | Verdict |
|---|---|---|
| 1 | Authority explicitly distinct from authenticity | SATISFIED (MODEL.md §2/§3; the four separations) |
| 2 | The authority chain formalized | SATISFIED (domains/levels/rel/chain/SecurityContext; §3) |
| 3 | At least one non-circular authority theorem mechanized or deliberately refuted | SATISFIED (branch-wise PROVED: AZB4+AZBACC; the single form disclosed; the refutation direction carried by NCG1/2 + CM-G1/2/3) |
| 4 | At least one authoritative-root path demonstrated | SATISFIED (pos0/pos1 rel=1: consensus-rooted certificates accepted; g6 fork-substitution rejected) |
| 5 | At least one authoritative-execution/effect path demonstrated | SATISFIED (pos2 rel=2 + the KEVM adapter: presented == executed forced; pos3 rel=3 binding) |
| 6 | Payload/parent/child/execution-context substitution attacks tested | SATISFIED (CM-G4/5/7 + CM-G6 fork + CM-G5 parent + F5/F6 inherited) |
| 7 | At least one self-authorizing/circular certificate attack rejected | SATISFIED (CM-G1/2/3a/3b + NCG1/2 canaries + the KEVM selfauth demo) |
| 8 | State authority connected to Phase 1E | SATISFIED (§4 A-E3 replacement; AZG5) |
| 9 | Execution/effect authority connected to Phase 1F | SATISFIED (§10; the certificate binds the 1F identity + trace digest) |
| 10 | Authority integrated into the lineage | SATISFIED (LinRecG; AZR1-AZR4) |
| 11 | Authority integrated into the commitment gate | SATISFIED (Gate_G; the KEVM commit now commits a G-record) |
| 12 | Python ↔ K consistency demonstrated | SATISFIED (10/10 + 7/7 bytes incl. the real KEVM run + 25/25 verdicts + 18/18 mutations) |
| 13 | KEVM binding demonstrated | SATISFIED (3/3 demos; shared module chain) |
| 14 | Current execution-proof and access-list prior art compared | SATISFIED (§10; live-fetched EIP-8025/7928/8159 + Engine API) |
| 15 | Real client/protocol changes explicitly identified | SATISFIED (§12: the Engine-API insertion point; consensus-visible rejection = REQUIRES CLIENT/PROTOCOL SUPPORT; Tier G3 not attempted) |
| 16 | No result silently assumes the authority relation it claims to prove | SATISFIED (A-G2/A-G3/A-G7 explicit; identities context-derived; the census in §14) |
| 17 | Full reproducible provenance package produced | SATISFIED (transcripts + pinned recipes + per-claim raw outputs + MANIFEST) |

## 14. Assumption census (nothing hidden)

| ID | Assumption | Classification |
|----|------------|----------------|
| A-G1 | Keccak256 collision resistance | REQUIRES CRYPTOGRAPHIC ASSUMPTION (inherits A-E1/A-F1) |
| A-G2 | The consensus identity for chainId is the protocol's authorization root | PROTOCOL ASSUMPTION — the STRUCTURED replacement of A-E3; in deployment the Engine-API boundary: REQUIRES CLIENT/PROTOCOL SUPPORT |
| A-G3 | The authorized producer identity sets (the execution client per (chainId, config); the pinned proof descriptor) are protocol-pinned | CLIENT/PROTOCOL ASSUMPTION |
| A-G4 | Canonical-encoding injectivity (cert/step/sec canon) | STRUCTURAL (inherits A-F2) |
| A-G5 | Fragment field bounds (1F §2 unchanged) | explicit REFUSE |
| A-G6 | Proof-system soundness for Mode B | REQUIRES EXTERNAL PROOF SYSTEM |
| A-G7 | The security policy version's own authority | PROTOCOL/GOVERNANCE ASSUMPTION (disclosed; no in-model derivation) |

Inherited unchanged: A-E2/A-E4/A-E5, A-F1..A-F5, the 1D census. A-E3 is
SUPERSEDED at the Gate_G level (§4). Implementation assumptions recorded in
the PROVENANCE (the KEVM memory-ceiling factorization; the model chainId
constant; the partitioned demo programs).

## 15. Artifact index

| Artifact | Path |
|---|---|
| Model spec (FROZEN) | `phase1g/semantics/MODEL.md` |
| K semantics (additive) | `phase1g/semantics/srw3authz.k` + demo `srw3authz-demo.k` |
| K proofs + negative controls | `phase1g/proofs/*.k` |
| Python reference + suites | `phase1g/python/{authz_model,test_authz_verify,authz_mutations}.py` |
| KEVM authority adapter + demos | `k/kevm/srw3-authz-evm.k`, `srw3-authz-evm-demos.k`, `k/kevm/demos/evm_authz_*.srw3evm` |
| Transcripts (Parts 1-7) | `phase1g/transcripts/` |
| Cross-layer + prior-art scripts | `scripts/phase1g/` |
| Report | `phase1g/report/SRW3-Phase1G-Authority-Report.{md,pdf}` |
| Provenance | `phase1g/provenance/PROVENANCE.md` |
