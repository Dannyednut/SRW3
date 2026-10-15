# SRW3 Phase 1G — Authority-Rooted State and Execution Evidence (MODEL.md)

**Status: FROZEN at Phase 1G start.** This is the normative model specification.
Everything executable (K abstract, KEVM, Python) must implement exactly this.

The frozen Phase 1D-R1 / 1E / 1F layers are NOT modified. The Phase 1G
extension is purely additive (the `linCtxP` / `linRecE` / `execCtx` discipline
continues as `azCtx` / `linRecG`).

## 1. The research question and the authority chain

Phase 1G attacks the AUTHORITY BOUNDARY left open by Phases 1E (A-E3: anchor
authenticity ASSUMED) and 1F (A-F3: trace authenticity is a verifier-domain
boundary; general closure REQUIRES CLIENT/PROTOCOL SUPPORT).

> Can SRW3 obtain and bind its authoritative state root and execution
> evidence from the execution/consensus layer WITHOUT circular trust, so
> that the commitment gate evaluates security obligations over evidence
> whose authority is grounded in the protocol/client execution process
> rather than merely supplied as an external assumption?

The modeled chain:

```text
Consensus-authorized payload
      | authorizes (level 0 -> 1)
      v
Execution-client validation/execution   (or proof-backed equivalent)
      | derives
      v
authoritative pre-state  ->  execution-derived effects  ->  authoritative post-state
      | commits
      v
post-state commitment  ->  SRW3 security gate  ->  commit/reject
```

The rejected degenerate form (`producer says root = R; SRW3 trusts R`) is the
Phase 1E/1F boundary itself and is NOT re-modeled as progress.

## 2. The four separations (never collapsed)

```text
Evidence validity    Verify(root, evidence) = true        (structural/crypto check)
Evidence authority   root = protocol/client-authoritative  (a PROVENANCE relation)
Execution validity   execution(payload, preState) = postState
SRW3 security validity  postState + effects satisfy inherited obligations
```

The authority relation investigated:

```text
Authority -> Authenticity -> Execution validity -> State/effect binding
          -> Security validity -> Commitment
```

Level separation from prior phases is PRESERVED: L1 (1D-R1 presented-record
self-consistency), L2 (1E anchored state), L3 (1F execution-effect binding)
all keep their verdicts; Phase 1G adds the authority axis ON TOP (a new gate
`VerifyLineageG` whose accept implies the full 1F accept plus authority).

## 3. Authority objects

```text
AuthzDomain ::= domConsensus | domExecution | domProof | domPolicy
AuthzSrc    ::= azSrc(domain, id:Bytes, level:Int)
AzStep      ::= azStep(domain, id:Bytes, level:Int)          -- one chain step
AuthzCert   ::= azCert(payloadD, parentRoot, execId, childRoot, effectD,
                       rel, src, chain:List, policyV, proofPub)
SecCtx      ::= secCtx(policyV, chainId, appSetD, graphD, lineageHead)
AzCtx       ::= azCtx(fctx:ExecCtx, sec:SecCtx, cert:AuthzCert,
                      authPT, authGuestD, authCfgD)           -- the G context
```

`rel` — the authority RELATION carried by the certificate:

| rel | relation            | required src domain | mode                |
|-----|---------------------|---------------------|---------------------|
| 1   | consensus-authorized payload, client-executed | domConsensus | the Engine-API-modeled path |
| 2   | re-execution-derived | domExecution       | **Mode A**          |
| 3   | proof-checked        | domProof            | **Mode B**          |

Any other `rel` value is `invalid-authtype` (an unknown authority relation is
a model refuse, never silent).

**Authority levels** (the authority DAG ranking; authority flows strictly
from lower to higher):

| domain       | level | role                                   |
|--------------|-------|----------------------------------------|
| domConsensus | 0     | protocol authorization root (payloads) |
| domPolicy    | 0     | protocol authorization root (policy)   |
| domExecution | 1     | evidence producer (client execution)   |
| domProof     | 1     | evidence producer (proof system)       |

The certified OBJECT (an SRW3-layer authority claim over a payload/execution/
root tuple) sits at level 2; sources must come from levels 0-1.

## 4. Authority graph and NoCircularAuthority

The certificate structure IS the authority graph fragment: nodes = protocol
roots (level 0), evidence producers (level 1), the certified object (level
2); edges = `authorizes` (consensus->payload), `derives` (client/proof ->
state/effects/roots), `verifies` (proof system -> evidence tuple), `binds`
(certificate -> the five bound fields), `attests` (NO authority — an
attestation without an authorized source is rejected), `commits` (SRW3 gate
-> commitment).

**NoCircularAuthority (mechanized):**

```text
AzNonCircular(cert, ctx) =
    certId NOT-IN chain-ids                      -- a witness never cites itself
    ∧ srcId != certId                            -- nor is its own id the source
    ∧ AzChainOk(chain, src.level, ctx)           -- strict level decrease,
                                                 -- EVERY step's identity
                                                 -- authorized (context-derived),
                                                 -- terminating at a level-0
                                                 -- protocol root (consensus
                                                 -- or policy), or (src.level=0)
                                                 -- an empty chain
```

Strict level decrease + termination at level 0 implies acyclicity (levels
are naturals; a cycle would need a non-decreasing step). EVERY chain step
carries an AUTHORIZED identity (checked against the context-derived sets):
the producer cannot park an arbitrary claimed id in the chain and call it
consensus. The fully self-referential certificate (its own id as its own
source) is a hash fixpoint — excluded mechanically by the own-id checks and
computationally by A-G1.

## 5. Authorized identities — context-derived, never certificate-derived

Every authorized identity is a deterministic function of the VERIFICATION
CONTEXT (chainId, fork config, policy version, pinned proof descriptor). No
check ever consumes the certificate to define what counts as authoritative —
this is the §18 non-vacuity requirement at the definitional level.

```text
ConsensusId(chainId)                    = H(0xA1 || chainId)
ExecClientId(chainId, configD)          = H(0xA2 || chainId || configD)
ProofSysId(pt, guestD, proofCfgD)       = H(0xA3 || pt_4 || guestD || proofCfgD)
PolicyAuthId(policyV)                   = H(0xA4 || policyV_4)
```

The authorized proof descriptor `(authPT, authGuestD, authCfgD)` is PINNED IN
THE CONTEXT (A-G3): presenting a certificate sourced at a different proof
system is `invalid-authsrc` (CM-G10). The execution-client identity is
fork-config-bound: the client authorized under fork A is not the authorized
client under fork B (CM-G6 at the authority layer).

## 6. Canonical encodings (domain tags)

New tags, distinct from all frozen tags (`0x00/0x01/0x02` tree, `0x03` trace,
`0x11/0x12/0x13` identity components, `0x1F` execId, `0x57` witness):

| tag   | object                                   |
|-------|------------------------------------------|
| 0x8C  | authority-certificate body               |
| 0x8D  | proof public inputs (rel=3)              |
| 0x8E  | access-list (BAL) object                 |
| 0xA1..0xA4 | authorized-identity preimages       |

```text
StepCanon(azStep(D, id, lvl)) = domByte_1 || id || lvl_4
ChainBytes(chain)             = concat(StepCanon(s) for s in chain order)
SrcCanon(src)                 = domByte_1 || srcId || srcLevel_4
CertBody(cert) = 0x8C || payloadD_32 || parentRoot_32 || execId_32
                 || childRoot_32 || effectD_32 || rel_1 || SrcCanon
                 || ChainBytes || policyV_4 || proofPub
certId = H(CertBody)
```

The record carries `azCertD = certId`; the gate recomputes it from the
presented certificate (the certificate is bound INTO the lineage).

**Proof public inputs (rel=3 only):**

```text
proofPub = H(0x8D || payloadD || parentRoot || chainId || sched_8 || spec_4
             || childRoot || policyV_4 || appSetD || graphD || lineageHead)
proofPub = empty for rel != 3
```

Beyond the EIP-8025-style bindings (payload identity, chain id, schema/fork,
child root) SRW3 adds: **security-policy version, application-set digest,
interaction-graph digest, lineage head** (§17 below). rel != 3 with a
non-empty proofPub, or rel = 3 with a non-recomputable proofPub, is
`invalid-authbind`.

## 7. SecurityContext — the policy binding (the SRW3 bridge)

```text
SecCtx = secCtx(policyV, chainId, appSetD, graphD, lineageHead)
```

`policyV` binds the applicable invariant/obligation version, `appSetD` the
application set, `graphD` the interaction graph, `lineageHead` the lineage
state the evidence is evaluated against. The certificate carries `policyV`;
the gate requires `cert.policyV == sec.policyV` (`invalid-policy`, CM-G8).
This is the architectural bridge between execution validity and SRW3
security validity: the evidence is evaluated UNDER a pinned security
context, and the binding is part of the accept condition.

The SECURITY POLICY'S OWN authority (who authorizes policyV) is protocol/
governance input: A-G7. It is modeled as a level-0 authority root
(domPolicy) but its authorization is NOT derived inside the model — an
honest, disclosed boundary (no infinite regress inside the model).

## 8. Additive record extension: LinRecG

```text
LinRecG    = (base: LinRecF, azCertD: Bytes, azPolicyV: Int)
CanonCoreG = CanonCoreF(base) || azCertD || policyV_4
childG     = H(CanonCoreG)
```

`CanonCoreF` is a STRICT PREFIX of `CanonCoreG`; the base `childF` (and
`childE`, and the 1D `child`) are carried unchanged; the legacy chains run
unchanged on the projections. Extending adds two fields; deleting none.

## 9. Verification context and Gate_G (first-fail, total)

```text
AzCtx = ( fctx: ExecCtx,        -- the full 1F context (incl. AuthCtx + anchor)
          sec:  SecCtx,         -- the security context
          cert: AuthzCert,      -- the PRESENTED authority certificate
          authPT, authGuestD, authCfgD )   -- the PINNED authorized proof descriptor
```

VerifyLineageG(recG, ctx, tid, head) — first-fail; every frozen layer fires
first. The inherited 1F accept condition is its first eight conjuncts (the
full 1F accept, 8 atomic conjuncts over the F-projection):

```text
[ VerifyLineageA == valid-a            (the 1E chain: legacy 12 verdicts,
                                        corrected-composition, capacity,
                                        padkey, state-root, anchor, childe)
  invalid-execbounds/execconfig/execid/efftrace/effdecl/witness/effbind
  -> valid-f ]                          (the 1F layers, unchanged)
```

then the SEVEN new authority layers (circularity is checked BEFORE source
authorization so that a self-referencing certificate is diagnosed as
circular even when its source identity could not be authorized):

```text
invalid-authtype    rel not in {1,2,3}                          (L23)
invalid-authrel     src.domain != domain required by rel        (L24)
invalid-authlevel   src.level != level(domain)                  (L25; CM-G3)
invalid-authcircle  AzNonCircular fails: certId cited in own
                    chain or as own source, or the chain does
                    not strictly decrease to a level-0
                    protocol root                               (L26; CM-G1/2)
invalid-authsrc     src.id != the context-derived authorized
                    identity for its domain                     (L27; CM-G10)
invalid-authbind    certId recomputation mismatch, or any of
                    payloadD/parentRoot/execId/childRoot/
                    effectD fails to bind, or the proofPub
                    rule (rel=3) fails                          (L28; CM-G4/5/6/7)
invalid-policy      cert.policyV != sec.policyV                 (L29; CM-G8)
valid-g                                                          (L30)
```

**The full accept condition `valid-g` is 21 atomic conjuncts**: the 14 of
`valid-f` (1E chain counted as: legacy-chain, corrected-composition,
capacity, padkey, state-root, anchor, childe, execbounds, execconfig,
execid, efftrace, effdecl, witness, effbind) plus the 7 new authority
conjuncts (authtype, authrel, authlevel, authsrc, authcircle, authbind,
policy).

## 10. What Gate_G acceptance means — and does not mean

**Means (authority inheritance).** Under valid-g, all 21 conjuncts hold: the
full Level-1/2/3 certificates, PLUS the presented certificate is
non-circular (never cites itself, strictly level-decreasing, terminating at
a level-0 protocol root), sourced at an authorized, context-derived
identity, bound field-by-field to the record (payload, parent root,
execution identity, child root, effect digest), and bound to the security
policy version. In particular the ANCHOR (A-E3) is no longer a bare
assumption at the Gate_G level: valid-g implies
`anchor == stateRoot == cert.childRoot` where `cert` is non-circular and
protocol-rooted — A-E3 is REPLACED for the G-gate decision by an explicit
authority certificate (the replacement theorem). The frozen valid-a verdict
itself is unchanged (frozen layer discipline).

**Does not mean (the surviving boundary).** The model's protocol roots
(consensus identity for chainId; the pinned authorized producer identities;
the policy version) are protocol-given INPUTS (A-G2/A-G3/A-G7). Authority is
INHERITED by SRW3, not created: the gate verifies that a certificate's
authority chain terminates at a protocol root and never at itself, but the
protocol root's own authority is the explicit, minimal assumption that
replaces the unstructured A-E3. In a real deployment the consensus->
execution boundary is the Engine API and the root becomes authoritative
inside the consensus process: REQUIRES CLIENT/PROTOCOL SUPPORT (the
formal-adapter result is PROVED at the model layer; the deployment gap is
stated, not hidden).

## 11. The two authority paths (Mode A / Mode B)

**Mode A — re-execution authority (rel=2).** The authority source is the
authorized execution client's own re-execution of the consensus-authorized
payload. At Tier G2 the adapter IS the executing semantics: the certificate
is constructed FROM THE RUN (source identity = the authorized client for
(chainId, configD)), the effect digest binds the EXECUTION-DERIVED trace
digest, and `invalid-authbind` then requires presented == executed traces.
DEMONSTRATED at the KEVM layer; the same construction at the abstract layer
is PROVED (branch-wise).

**Mode B — proof-backed authority (rel=3).** The authority source is an
authorized proof system; the proof object stays ABSTRACT
(ExecutionProofVerifier: `VerifyExecutionProof(payload, parentRoot,
childRoot, evidence)`); SRW3 mechanizes the PUBLIC-INPUT BINDING (§6) and
the source authorization, NOT the proof math. The actual proving is
REQUIRES EXTERNAL PROOF SYSTEM (zk execution proof / STARK / SNARK /
proof-carrying execution). Neither mode eliminates A-G2: the payload must
be consensus-authorized in BOTH (rel=1 is the base; rel=2/3 re-use the
consensus root in their chains).

**Mode comparison finding.** Mode A closes the 1F trace-authenticity
boundary WHERE THE VERIFIER EXECUTES (client-side re-execution); Mode B
delegates it to an external proof system. Neither creates authority: both
INHERIT it from the consensus root of the chain.

## 12. Access-list analysis (EIP-7928-style BAL; analysis object, NOT a gate conjunct)

```text
BalEntry(app, slot, hasPost, postValue)
BalFootprintOk(bal, trace)  keyset(bal) == touched(app,slot) set of trace
                            (reads AND writes; each exactly once)
BalWritesOk(bal, trace, pre) for each entry:
                               written in trace  -> postValue == last write
                               read-only         -> postValue == current
                                                    (pre-state) value
BalCanon(bal) = 0x8E || n_4 || (app_4 || slot_4 || hasPost_1 || post_8)*
```

Findings (mechanized + demonstrated):

1. The BAL footprint is CHECKABLE against the digest-bound ordered trace —
   an omission (CM-G9) is detected (`BalFootprintOk` false) because SRW3
   holds an independent, order-preserving footprint source.
2. The BAL is NOT a security effect trace: it binds the touched-LOCATION set
   and post-execution VALUES, but NOT the order of same-slot writes (the F4
   class: two orderings have the SAME footprint and the SAME post-values)
   and NOT the read OBSERVATIONS (the oracle-staleness class: a false
   observation changes no BAL entry). Demonstrated: the stale-read attack
   that 1F's `invalid-effbind` rejects PASSES every BAL check.
3. Conclusion: `BAL ⊊ trace evidence`. A BAL-like object can serve as an
   additional footprint CROSS-CHECK inside SRW3; it cannot replace the
   order-preserving digest-bound effect trace, and the task brief's
   prohibition (access list = complete security effect trace) is confirmed
   mechanically.

## 13. Assumption census (nothing hidden)

| ID  | Assumption | Classification |
|-----|------------|----------------|
| A-G1 | Keccak256 collision resistance | REQUIRES CRYPTOGRAPHIC ASSUMPTION (inherits A-E1/A-F1) |
| A-G2 | The consensus identity for chainId is the protocol's authorization root (the payload-authorization relation is protocol-given) | PROTOCOL ASSUMPTION — the STRUCTURED replacement of A-E3; in deployment the Engine-API boundary: REQUIRES CLIENT/PROTOCOL SUPPORT |
| A-G3 | The authorized producer identity sets (execution client per (chainId, config); the pinned authorized proof descriptor) are protocol-pinned | CLIENT/PROTOCOL ASSUMPTION |
| A-G4 | Canonical-encoding injectivity (cert/step/sec canon; inherits A-F2) | STRUCTURAL |
| A-G5 | Fragment field bounds (1F §2 unchanged) | explicit REFUSE |
| A-G6 | Proof-system soundness for Mode B (the proof object is abstract) | REQUIRES EXTERNAL PROOF SYSTEM |
| A-G7 | The security policy version's own authority (governance) | PROTOCOL/GOVERNANCE ASSUMPTION (disclosed; no in-model derivation — no infinite regress) |

Prior assumptions inherited unchanged: A-E2/A-E4/A-E5 (1E), A-F1..A-F5 (1F),
the 1D census. A-E3 is SUPERSEDED at the Gate_G level (§10): the anchor
must now carry a non-circular protocol-rooted authority certificate for the
G-gate to accept; the bare-anchor assumption remains only inside the frozen
1E verdicts (unchanged by discipline).

## 14. Non-circularity theorem (the §18 candidate)

```text
AUTHORITY-NONCIRCULARITY (modeled form)
  valid-g(recG, ctx)  =>
      notBool AzOwnInChain(chain(cert), certId(cert))
      ∧ srcId(cert) != certId(cert)
      ∧ AzChainOk(chain(cert), srcLevel(cert))     -- strict decrease,
                                                   -- terminal level-0 root
      ∧ srcId(cert) == context-derived authorized identity
```

`IndependentAuthoritySource` is DEFINED IN CONTEXT TERMS ONLY (§5) — never
in terms of the certificate being validated (definitional non-vacuity).
Mechanization: branch-wise (the accept direction carries the conjuncts) +
ground instances; the fully symbolic chain-induction form is disclosed as
NOT YET MECHANIZED (the 1F EX3a/EX5d-f-g-h precedent).

## 15. Theorem classes (the §26 list) and the report vocabulary

| class | statement (modeled form) | target tier |
|-------|--------------------------|-------------|
| G1 payload authority | valid-g ⟹ cert.payloadD == PayloadDigest(presented payload) | PROVED BY K (branch-wise) |
| G2 parent-root authority | valid-g ⟹ cert.parentRoot == threaded 1E parent root | PROVED BY K |
| G3 execution-result authority | binding half: cert.execId == recomputed ExecutionId; RESULT half (root = Root(execute(payload, pre))) = Mode A demonstrated / Mode B external | PROVED BY K (binding) + DEMONSTRATED (KEVM, Mode A) |
| G4 effect authority | valid-g ⟹ cert.effectD == rec.effTraceD == H(TraceBytes(presented trace)) | PROVED BY K |
| G5 child-root authority | valid-g ⟹ cert.childRoot == stateRoot == anchor path | PROVED BY K |
| G6 non-circular authority | §14 | PROVED BY K (branch-wise + ground; symbolic chain induction disclosed) |
| G7 authority-bound lineage | CanonCoreF strict prefix of CanonCoreG; legacy chains unchanged; childG binds cert+policy | PROVED BY K |
| G8 authority-bound commitment gate | branch-wise verdict characterization + accept direction | PROVED BY K (branch-wise; single form attempted) |
| G9 authority-bound closed-composition safety | the 3-record authority chain (Oracle -> Lending -> Liquidator) with per-record certificates + threading | DEMONSTRATED (+ K ground claims) |

AUTHORITY-CHAIN (§19 of the task brief): the combined single-implication
form is attempted and expected to hit the prover budget (EXGATE precedent);
the branch-wise content carries the same conclusions; disclosed verbatim if
blocked. The second half (SRW3AuthorityValid ∧ SecurityClosed ∧ GateComplete
∧ ContractSound ⟹ CommitmentIsSecurityValid) reduces, at the model layer, to
the gate's own accept direction over the inherited obligation surface —
stated with the honest tier attribution, never inflated.

## 16. Countermodels CM-G1..G10 (expected verdicts)

| ID  | construction | expected |
|-----|--------------|----------|
| CM-G1 | self-authorizing anchor: cert chain cites an unauthorized id (including a guessed self-id) as its consensus root | invalid-authcircle |
| CM-G2 | evidence certifies itself: the source id is a CERTIFICATE-derived id (the id of a sibling variant), never a protocol identity; the exact self-referential fixpoint variant is excluded by the own-id checks + A-G1 | REJECT (invalid-authsrc) |
| CM-G3 | client output as unquestionable authority: (a) client claims level 0; (b) client-sourced cert with NO consensus chain | (a) invalid-authlevel; (b) invalid-authcircle (chain fails to terminate at a protocol root) |
| CM-G4 | payload substitution: cert binds payload A, presented with payload B | invalid-authbind |
| CM-G5 | parent-root substitution: cert from parent A attached to the record at parent B (context honest) | invalid-authbind |
| CM-G6 | fork/config substitution: cert sourced at the client authorized under fork A, evaluated under fork B | invalid-authsrc |
| CM-G7 | child-root substitution: cert.childRoot = A, record root = B | invalid-authbind |
| CM-G8 | policy substitution: cert.policyV = 2 vs sec.policyV = 1 (all else honest) | invalid-policy |
| CM-G9 | access-list completeness failure: (a) omitted touched location — detected against the digest-bound trace; (b) the stale-read attack passes ALL BAL checks while the ordered-trace evidence rejects it | (a) BalFootprintOk = false; (b) BAL true ∧ verdict invalid-effbind — BAL is NOT a complete security effect trace |
| CM-G10 | proof-authority substitution: valid-format proof from an unauthorized proof type/configuration | invalid-authsrc |

## 17. Fragment boundaries (explicit)

The KEVM fragment is unchanged from Phase 1F (SLOAD/SSTORE/CALL/RETURN;
Read/Write/Call/Return; explicit bounds refuses). The authority fragment:
exactly ONE authorized consensus identity, ONE authorized execution client
per (chainId, config), ONE pinned authorized proof descriptor, ONE policy
authority per policy version — the minimal fragment in which the authority
graph is mechanizable; generalizing the identity sets is set-membership
plumbing, not new semantics, and is recorded as future work. The chain
length is unbounded in the definitions; the mechanized claims use concrete
chains of length <= 1 above the source (the fragment's honest shapes).
