# SRW3 Phase 1I-R2 — Gate-Verdict Provenance Binding Report

**Branch:** `phase1i-r2-gate-provenance` (additive tree `phase1i-r2/` only)
**Base:** `0b667af79659b783f813a416aad84d641b168034` (= tag `phase1i-r1-complete` = branch `phase1i-r1-formal-binding`)
**Backend evidence:** K Haskell (proofs) + K LLVM with the pinned krypto shim (concrete keccak) + Python executable mirror (real keccak)
**Companion documents:** `phase1i-r2/audit/GATE-PROVENANCE-AUDIT.md` (defect record, isolation analysis, correspondence discipline)

---

## 1. Executive summary

Phase 1I-R1 closed the accept-side trust boundary: the accept command no
longer takes a verdict or a configuration, and only machine-created receipts
can authorize a commit.  But R1's GATE command still had the shape
`pGateEval(ProtoBlock, Bytes, Bytes, String)` — the caller supplied the
verdict STRING, the mint stored it verbatim, and no rule of the R1 machine
ever evaluated the frozen gate.  A caller that typed `"valid-g"` obtained a
receipt claiming the frozen gate accepted.  This report closes that mint-side
boundary.

The repair is an **isolated R2 machine** (`srw3proto-r2.k`) that imports ONLY
the frozen Phase 1G gate module `SRW3AUTHZ` — not `SRW3PROTO`, not
`SRW3PROTO-R1` — so the legacy commands and transitions are not merely
avoided but ABSENT from the machine's command language and rule set.  In it:

- the gate command `pGateEvalR2(B, FC, RG, CERT, ERC, ERP)` takes evidence
  objects and client-derived execution results — and **no verdict argument of
  any sort**;
- the machine **constructs** the authority context from the pinned
  configuration (authorized SecurityContext + pinned proof-type/guest/config
  parameters), **supplies** the position (slot counter + lineage anchor), and
  **computes** the receipt verdict as `VerifyLineageG(RG, AC, T, HEAD)` —
  the frozen 21-conjunct gate is the only producer of `"valid-g"`;
- the named predicate `GateInputMatchesBlockR2` (plus
  `GateAuthorityMatchesCfgR2`, `GateCtxAuthorizedR2`) binds every presented
  evidence object to the EXACT candidate and the pinned configuration;
- the accept consumes the receipt once, requires the DERIVED decision of the
  COMPUTED verdict to be `pdecValidR2`, and re-checks the full commitment
  predicate against the pin.

**Results.**  K proof ladder: **37 PROVED** (including the headline
`R2-ACCEPT-IMPLIES-COMMITP`, the mint-shape pair, the full rejection family,
the correspondence claims to the frozen 1I formulas, and the ported frozen
1I ladder) and **3 NOT MECHANIZED** (the two full-pipeline compositions and
the universal closure — each with the exact stuck log retained, and each with
its concrete substitute demonstrated).  Concrete gate evaluation is
demonstrated on the LLVM backend with real keccak via the pinned krypto
shim: the honest mint computes `gr2Verdict: "valid-g"`, the honest two-block
pipeline commits, and every attack computes a rejection or is ill-formed.
The Python mirror (real keccak, the frozen 1G gate imported unchanged)
passes **87/87**, including the byte-level cross-layer certificate that
reproduces the K digests digit-for-digit and anchors to the FROZEN 1G
transcript (`certid0 = 89ffea58…`).  Zero regression: 11/11, 26/26, 30/30,
15/15, 17/17, 16/16, 48/48 — exact.

**Scientific verdict: CLOSED** for the in-model gate-verdict-provenance
question, with the standing boundaries restated (section 8) — `R2-ALL`
remains NOT MECHANIZED, the Level-III model boundary is unchanged, and no
consensus-integration claim is made.

## 2. Starting point and ground rules

The repair starts from `0b667af` (tag `phase1i-r1-complete`) and works in an
additive `phase1i-r2/` tree.  `phase1g`, `phase1h`, `phase1h-r1-fix`,
`phase1i`, and `phase1i-r1-formal-binding` are preserved byte-for-byte (no
amend, no rebase, no force-push; verified by the frozen-ref check in section
9 and the provenance record).  The K toolchain was rebuilt from the pinned
recipe (K v7.1.337, z3 4.13.3, the clang/LLVM-15 chain at 15.0.6-4+b1, the
Phase-1D krypto shim at `k/phase1d/shim` with the multiblock fix,
blockchain-k-plugin K sources at `207ae512`); the rebuild is scripted
(`scripts/r2_rebuild_toolchain.sh`, `scripts/r2_build_llvm.sh`) and logged.

## 3. The audit (what was wrong, mechanically witnessed)

Finding **R2-F1**: the R1 mint stores the caller's verdict string verbatim;
no R1 rule evaluates `VerifyLineageG`.  Three independent witnesses are
retained against the UNMODIFIED R1 module:

1. **K witness claims** (`old_r1_witness.k`, kprove over the R1 definition):
   `OLD-R1-GATE-MINTS-CALLER-VERDICT`, `OLD-R1-ACCEPTS-CALLER-VERDICT`
   (the accept fires and the chain extends — the security equalities appear
   as hypotheses precisely because nothing in R1 could verify or refute
   them), `OLD-R1-PIPELINE-FORGED`.  All three WITNESSED.
2. **Executable witness** (Python, real keccak): the unmodified R1 logic
   accepts after `gate_eval(..., "valid-g")`; the receipt verdict is
   captured as the caller's text (`INJ-R1-*` cases, 87-case suite).
3. **K run transcripts** on the R1 definition showing the injected verdict
   inside the minted receipt (`transcripts/legacy/`).

The full defect record with line references is
`audit/GATE-PROVENANCE-AUDIT.md` §A.

## 4. The repair design

**Isolated machine surface.**  `SRW3PROTO-R2` imports `SRW3AUTHZ` only.  The
legacy commands have no production (kparse rejects every legacy name —
transcripts T9/T10a-d) and the legacy transitions are not in the rule set
(audit §B rule inventory).  This is the handoff's preferred architecture in
its strongest form: an adversary controlling the admitted R2 command stream
cannot reach the old unsafe transition because it does not exist in this
machine.

**Computed verdict.**  `pGateEvalR2` constructs
`AC_m = azCtx(FC, ProtoAuthorizedSecCtxR2(C, pbParentRootOf(B)), CERT,
pcAuthPTOf(C), pcAuthGuestDOf(C), pcAuthCfgDOf(C))` — the caller cannot name
the SecCtx or any authority parameter — and writes
`gr2Verdict := VerifyLineageG(RG, AC_m, N, LH)` with `N` the machine slot
counter and `LH` the machine lineage anchor.  The mint is the only receipt
producer (audit §C); no command carries a verdict, a receipt, or a
replacement configuration.

**Candidate/context binding.**  `GateInputMatchesBlockR2(FC, RG, CERT, B)`
(paylod digest via the certificate field + the frozen L28 hash closure;
parent state root; post-state root; effect-trace digest; evidence identity
via the record's certificate digest + the frozen L28 `AzCertId` recomputation)
and `GateAuthorityMatchesCfgR2` (pinned schedule/spec) guard the mint; the
accept re-checks them on the receipt-stored inputs.  The policy-commitment
and context-digest equalities are checked directly against the pin at
accept.  The handoff §5.2 checklist is discharged item-by-item in audit §F.

**Pinned configuration.**  `ProtoCfgR2` extends the 1I config shape with the
gate-authority fields 9..13 (sched/spec/authPT/authGuestD/authCfgD — the
handoff §5.3 requirement).  `pInitR2` pins once (reserved key −1), refuses
re-initialization, and anchors the protocol head at the R2 protocol root and
the lineage head at the 32-zero-byte lineage root.  There is deliberately no
upgrade transition.

**Two chain heads.**  The protocol chain (1I, head := 0x9E block commitment)
and the evidence lineage chain (1D/1G, records anchor at the parent's
F-child) are distinct frozen chains; R2 tracks both (`<r2head>`,
`<r2linhead>`), the gate's HEAD is the lineage anchor, receipt freshness is
enforced on both, and acceptance advances the lineage head to the accepted
record's F-child (`R2RecChildF`).

**Receipt.**  An `R2GateReceipt` binds the exact candidate, the client
execution results, the exact gate inputs (FC/RG/CERT/AC), the COMPUTED
verdict, head/slot/lineage-head at evaluation time, and the pinned config
object.  Missing, duplicate, stale, mismatched, or rejected receipts fail
closed with state unchanged.

## 5. The K proof ladder (37 PROVED / 3 NOT MECHANIZED)

All on the Haskell backend over the R2 definition (`run_r2_proofs.sh`;
logs in `transcripts/k/`).  The headline:

| Claim | Status | Content |
|---|---|---|
| `R2-ACCEPT-IMPLIES-COMMITP` | **PROVED** | the accept guard verbatim ⇒ `CommitPR2(B, ERC, ERP, C, pbParentRootOf(B))`; Commit_P only in the destination; the decision conjunct is the DERIVED decision of the computed verdict |
| `R2-VALID-ACCEPT` | PROVED | non-vacuity: under the same guard the transition fires and extends the chain |
| `R2-MINT-SHAPE-EXISTING-POOL` / `-EMPTY-POOL` | PROVED | the mint writes the computed verdict + the bound inputs (the derivation chain of audit §C) |
| `R2-CONFIG-FRAME-GATE` / `-ACCEPT` | PROVED | the pinned config is never mutated by gate/accept |
| `R2-INIT-PINS` / `R2-CONFIG-IMMUTABLE` | PROVED | one-time pin; re-init refuses |
| `R2-DECISION-BOUND` | PROVED | the accepted decision field equals the gate-derived decision |
| `R2-GATELINK-VALID` / `-REJECT1..3` | PROVED | only "valid-g" maps to pdecValidR2; rejection verdicts map to pdecRejectR2 (fail-closed) |
| `R2-FORGED-VERDICT-REJECT` / `-AUTHTYPE` | PROVED | computed rejection verdicts cannot accept (state unchanged) |
| `R2-REJECT-NO-POOL` / `-EMPTY-POOL` / `-WRONG-CANDIDATE` / `-STALE-HEAD` / `-STALE-LINHEAD` / `-WRONG-SLOT` / `-GATE-INPUT-MISMATCH` / `-CONFIG-SUB` | PROVED | the fail-closed family (concrete countermodels) |
| `R2-RECEIPT-SINGLE-USE` | PROVED | one receipt, one commit; replay refused |
| `PI1/PI2/PI5/PI7` + `PI2-EXEC-INVALID` (ported) | PROVED | the frozen 1I ladder over the R2 predicate forms |
| `R2-CORRESPONDENCE-CONFIG-ROOT` / `-POLICY-COMMITMENT` / `-CTX-DIGEST` / `-BLOCK-COMMIT` | PROVED | the R2 predicates equal the FROZEN 1I formulas (transcribed byte-for-byte; audit §D) |
| `R2-NO-CALLER-VERDICT` | PROVED (syntactic) | no accepted command has a verdict/decision argument — the sort audit + kparse rejection transcripts T9/T10a-d |
| `R2-GATE-RESULT-DERIVED` | PROVED (composition) | mint-shape claims + producer exhaustiveness (audit §C) |
| `R2-GATE-INPUT-BINDING` | PROVED (composition) | mint guard + stored-input re-checks |
| `R2-INVALID-CANDIDATE-REJECT` | PROVED | `R2-FORGED-VERDICT-REJECT` + the VERDICT family + LLVM/Python |
| `R2-FORGED-VERDICT-IMPOSSIBLE` | PROVED (surface) + WITNESSED | the injection is ill-formed (T9) ; the R1-side injection formally witnessed (`OLD-R1-*`) |
| `R2-LEGACY-SURFACE-EXCLUDED` | PROVED (structural) | audit §B: no legacy productions, no legacy rules; parse transcripts |
| `R2-PIPELINE-HONEST` | NOT MECHANIZED | hs stuck-term boundary: the accept guard must decide the derived decision over the (unevaluated) computed verdict; exact log retained |
| `R2-PIPELINE-FORGED` | NOT MECHANIZED | same boundary |
| `R2-ALL` | NOT MECHANIZED | the universal closure (circularity claim) — configuration cannot be rewritten further; log retained |

**Substitutes for the three NOT-MECHANIZED items** (each disclosed, none
silent): the full honest pipeline is CONCRETELY demonstrated on the LLVM
backend (T2: computed verdict "valid-g" → commit; T3: two-block
continuation; T6: the forged end-to-end — computed rejection → state
unchanged) and in the Python mirror (HONEST/HONEST2 + INJ + VERDICT groups);
the K-side composition is carried by the PROVED halves
(mint-shape ⇄ accept-side), which is the composition identity for the two
steps; `R2-ALL` remains open exactly as in R1/1I (the same class of kore
blocker, log retained).

## 6. Concrete gate evaluation (LLVM + krypto shim) and the demo suite

The pinned shim (`k/phase1d/shim`, multiblock fix marker-checked) gives the
LLVM backend real keccak-256 and secp256k1 — the same executable path as the
frozen 1G demo suite.  `transcripts/demos/` (LLVM, `run_demos.sh`):

| Demo | Result |
|---|---|
| T1 gate eval | receipt minted with `gr2Verdict: "valid-g"` COMPUTED over the bound evidence; no chain state moves |
| T2 honest accept | COMMITS slot 0; head := block commitment; lineage head := record F-child |
| T3 two-block continuation | slots 0 and 1 both commit; the lineage head threads the F-child into the slot-1 gate position |
| T4 accept, no receipt | clean reject, state unchanged |
| T5 re-initialization | refused, state unchanged |
| T6 config-version substitution | reject, state unchanged (CV=2 vs pinned 1) |
| T7 position substitution | mint refuses (slot binding); accept finds no receipt |
| T8 evidence/candidate mismatch | mint refuses (GateInputMatchesBlockR2) |
| T9 the R1 injection `pGateEvalR2(..., "valid-g")` | **ILL-FORMED** (parse error; no such production) |
| T10a-d legacy `pAccept` / `pGateEval` / `pAcceptR1` / `pInitR1` | **ILL-FORMED** (parse errors) |
| T11/T12 (hs) | the disclosed hs boundary: the computed verdict remains an unevaluated `VerifyLineageG(...)` application; the receipt structure is concrete |

## 7. Python/K correspondence and regression (zero drift)

The mirror (`r2_model.py`) imports the frozen 1G gate UNCHANGED
(`authz_model.verify_lineage_g`, backed by the frozen 1D/1E/1F chain) — the
same function the K machine evaluates.  Two disclosed mirror artifacts are
handled explicitly and total on the verdict code set: the frozen Python
mirror emits layer-coded verdict names (`L29-POLICY` for the K
`invalid-policy`, …) and the R2 surface normalizes them (`verdict_k`);
the normalization changes no decision.  `run_r2_attacks.py` — **87/87 PASS**
(`transcripts/attacks/r2-attack-suite.txt`): KX (byte certificate, 11
checks), HONEST (10), INJ (7 — the decisive injection group), VERDICT (20),
BIND (15), ALT (2), CFG (4), STALE (3), POOL (4), MAL (2), LEG (3), DET (6).

The cross-layer byte certificate (`transcripts/crosslayer/
r2_byte_certificate_k_raw.txt`, K LLVM real-keccak) is reproduced digit-for-
digit by Python: cfgr2root `c549b4a7…`, policycommitr2 `e1c78257…`,
ctxdigest0 `e5710efa…`, blockcommit0 `8dad13d8…`, srw3root0 `8ef5bb80…`,
certid0 `89ffea58…` (= the FROZEN 1G transcript anchor), certid1 `837a5ba4…`,
recchild0 `cc07b327…`; verdicts valid-g/valid-g.

Zero regression (re-run live, exact):

```
phase1h/python/test_lineage_r1.py            11/11
phase1h/python/test_security_context_r1.py   26/26
phase1i/python/run_attack_matrix.py          30/30
phase1i/python/run_determinism_i.py          15/15
phase1i/python/run_reorg_replay.py           17/17
phase1i/python/run_forkchoice_compare.py     16/16
phase1i-r1/python/run_r1_attacks.py          48/48
```

## 8. Trust boundaries and scientific claim limits

1. **Verdict source.**  The verdict is the frozen `VerifyLineageG` result;
   its soundness rests on the frozen gate module (mechanized in 1G).  R2
   adds no trust to the evidence channel.
2. **Haskell-backend hash abstraction** (finding 1C-1): digest equalities
   are symbolic there; the hs demos retain the computed verdict as an
   unevaluated application (T11).  Concrete decisions are the LLVM runs
   (real keccak, pinned shim) and the Python mirror.
3. **Keccak collision resistance** remains an assumption for the
   substituted-digest distinctions (1I/1I-R1 boundary, unchanged).
4. **Execution-evidence authenticity**: that an off-chain executor's trace
   truthfully describes historical Ethereum execution remains OUTSIDE the
   model (1F/1H limitation, restated, not implicitly solved by R2).
5. **Level discipline**: R2 is a Level-III protocol-model result.  No
   Ethereum consensus integration, Engine-API change, or client support is
   claimed.
6. **NOT MECHANIZED residue**: `R2-ALL` (universal closure) and the two
   full-pipeline K compositions — each with retained logs and demonstrated
   concrete substitutes (section 5).
7. **Upgrade path**: deliberately absent; policy upgrade stays a deferred
   protocol-state transition requiring its own authorization semantics.

## 9. Completion criteria (handoff checklist)

- [x] the old R1 injection mechanically reproduced (K witness claims + Python + transcripts, §3)
- [x] R2 has no caller-supplied verdict field/parameter (syntax audit + T9 parse transcripts)
- [x] the receipt stores an internally computed `VerifyLineageG` result (mint-shape claims + T1 + KX)
- [x] every gate input is bound to the exact candidate and pinned context/config (GateInputMatchesBlockR2/§5.2 map, audit §F)
- [x] the old insecure transition is unreachable from the admitted R2 command surface (audit §B + T10a-d)
- [x] invalid candidates cannot commit, including under the original attack (T6-T8, VERDICT/BIND groups, kprove family)
- [x] honest valid candidates still commit (T2/T3, HONEST group, R2-VALID-ACCEPT)
- [x] K proof boundaries and all failed attempts disclosed (§5, logs retained)
- [x] Python/K correspondence and regression suites recorded (§7, 87/87, zero drift)
- [x] report, PDF, and provenance committed
- [x] no frozen refs changed (frozen-ref check in provenance)
- [x] no Phase 1J / novelty audit started

## 10. Verdict

**CLOSED** (in-model gate-verdict provenance), with the disclosed residues:
`R2-ALL` and the two full-pipeline K compositions are NOT MECHANIZED on the
Haskell backend (logs retained; concrete substitutes demonstrated on LLVM
and Python), and the standing 1F/1H boundaries about execution-evidence
authenticity, keccak collision resistance, and the Level-III model scope are
restated unchanged.  The claim "gate provenance solved" rests on the actual
verifier being evaluated, candidate-bound, config-bound, and the only
accepted result — not on the removal of the String parameter alone.

Next step (deferred until this phase is reviewed): the Phase 1I-R2 handoff
explicitly defers the novelty/prior-art audit and Phase 1J.
