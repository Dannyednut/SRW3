# SRW3 Phase 1I-R2 — Gate-Verdict Provenance Audit

Phase: 1I-R2 (branch `phase1i-r2-gate-provenance`, base `0b667af79659b783f813a416aad84d641b168034` =
tag `phase1i-r1-complete` = branch `phase1i-r1-formal-binding`).
Scope: the remaining trust boundary of Phase 1I-R1 — the MINT-side verdict
parameter.  This audit is the defect record, the isolation analysis, the
producer-exhaustiveness argument, and the correspondence discipline for
`phase1i-r2/semantics/srw3proto-r2.k`.  It does NOT start the novelty/
prior-art audit or Phase 1J (per the handoff's stopping rule).

---

## A. The defect (R2-F1) and its exact surface in R1

**R2-F1 (gate-verdict provenance).**  In
`phase1i-r1/semantics/srw3proto-r1.k` the gate-evaluation command is

```k
syntax PCmdI ::= ... | "pGateEval" "(" ProtoBlock "," Bytes "," Bytes "," String ")"
```

(line 181) and the mint rule (lines 216-235) stores the caller-supplied
fourth argument VERBATIM into the receipt:

```k
(-2:Int |-> SetItem(gateReceipt(B, ERC, ERP, V:String, H, N)) ...)
```

No rule of `SRW3PROTO-R1` ever evaluates `VerifyLineageG`.  A caller that
supplies the literal `"valid-g"` obtains a receipt whose derived decision is
`pdecValid` (`ProtoDecisionOfGate("valid-g") == pdecValid`), and if the
remaining accept-guard fields line up (the block carries the protocol-pinned
policy commitment and context digest, the decision field claims valid, the
execution results match, the parent/slot links hold — all of which the caller
can construct), `pAcceptR1` COMMITS.

**Mechanically reproduced witnesses (all retained):**

1. K witness claims over the UNMODIFIED R1 module
   (`phase1i-r2/proofs/old_r1_witness.k`, kprove on the R1 definition):
   `OLD-R1-GATE-MINTS-CALLER-VERDICT` (the caller string is stored verbatim),
   `OLD-R1-ACCEPTS-CALLER-VERDICT` (the accept fires and the chain extends —
   the security equalities appear as hypotheses precisely because R1 has no
   rule that could verify or refute them), `OLD-R1-PIPELINE-FORGED`
   (end-to-end).  Logs: `transcripts/k/kprove_OLD-R1-*.log`.
2. Executable witness (Python, real keccak): the UNMODIFIED R1 logic
   (`phase1i-r1/python/pi_r1_model.py`, imported unchanged) accepts a
   candidate after `gate_eval(..., "valid-g")` — `INJ-R1-accepts-injected-
   verdict` and `INJ-R1-receipt-verdict-is-caller-text` in
   `transcripts/attacks/r2-attack-suite.txt`.
3. K run transcript on the R1 definition showing the injected verdict stored
   in the receipt: `transcripts/legacy/` (the T-runs of the R1 definition).

The R1-era mitigations (no verdict/config argument on `pAcceptR1`; machine-
created receipts; pinned configuration) are intact and unaffected; R2 does
not modify them — R1's accept-side binding is SUBSUMED by the R2 accept
guard, and R1 itself is left byte-for-byte unchanged.

---

## B. The R2 machine surface and legacy-surface exclusion

`srw3proto-r2.k` imports ONLY the frozen Phase 1G gate module:

```k
requires "../../phase1g/semantics/srw3authz.k"
module SRW3PROTO-R2
  imports SRW3AUTHZ
```

`SRW3PROTO` (frozen 1I) and `SRW3PROTO-R1` are NOT imported.  Consequences
(all mechanically checkable on the kompiled definition):

1. **The legacy commands are not in the command language.**  The R2 command
   sort is `PCmdR2I` with exactly three productions (`pInitR2`, `pGateEvalR2`,
   `pAcceptR2`); the program sort is `PProgR2I` (`pConsR2`/`runNilR2`).  The
   legacy symbols `pInit`/`pAccept` (frozen 1I) and `pInitR1`/`pGateEval`/
   `pAcceptR1` (R1) have no production in any module reachable from
   `SRW3PROTO-R2` — a program containing them is ILL-FORMED.  Demonstrated by
   the kparse rejection transcripts `transcripts/demos/T9-…` and
   `T10a-d-…` (krun exit 113, parse error, for each legacy command name).
2. **The legacy transitions are not in the rule set.**  The R2 definition's
   complete rule inventory (enumerated from the kompiled `allRules.txt` and
   the source; audit-verified) is:
   - accessor/equation rules for `ProtoCfgR2`, `ProtoBlockR2`,
     `R2GateReceipt`, `CtxCanonR2`, `CfgEqR2`, `AzSecEqR2`,
     `GateInputMatchesBlockR2`, `GateAuthorityMatchesCfgR2`,
     `GateCtxAuthorizedR2`, `R2RecChildF`, `gr2DecisionOf`,
     `storedCfgR2Of`/`receiptsR2Of`/`cfgPinnedR2`, `blockAtR2`,
     `CommitChainLinkedR2`, the decision constants/mapping, the byte-certificate
     helpers inherited by the DEMO module (not the machine), plus
   - transition rules: `pConsR2`, `runNilR2`, `pInitR2` (fire/refuse),
     `pGateEvalR2` (two pool shapes), `pAcceptR2` (accept + [owise] reject).
   There is NO rule matching any legacy command and NO rule whose right-hand
   side contains the frozen `gateReceipt(...)` constructor or the frozen
   accept state update.  The old unsafe transition is not "avoided by the
   harness" — it does not exist in this machine (R2-LEGACY-SURFACE-EXCLUDED;
   claim + parse transcripts + this enumeration).
3. **No command carries a verdict, a receipt, or a configuration.**
   `pGateEvalR2(B, FC, RG, CERT, ERC, ERP)` — six arguments, all evidence
   objects/results, NO verdict of any sort; `pAcceptR2(B, ERC, ERP, CV)` —
   the CV Int is the declared config-version WITNESS (an equality check
   against the pin, not an authority input); no command takes a receipt or a
   `ProtoCfgR2` for gate/accept (only `pInitR2` takes one, and it refuses
   re-pinning).  (R2-NO-CALLER-VERDICT: syntax audit + parse transcripts.)

---

## C. Receipt producer exhaustiveness (the derivation chain)

The claim `R2-GATE-RESULT-DERIVED` ("every receipt verdict equals the result
of evaluating `VerifyLineageG` on the receipt-bound gate inputs") is carried
by three jointly exhaustive facts:

1. **The mint writes the computed verdict.**  Both `pGateEvalR2` rules write
   `gr2Verdict := VerifyLineageG(RG, AC_m, N, LH)` where `AC_m` is the
   machine-constructed context (`azCtx(FC, ProtoAuthorizedSecCtxR2(C,
   pbParentRootOf(B)), CERT, pcAuthPTOf(C), pcAuthGuestDOf(C),
   pcAuthCfgDOf(C))`), `N` is the machine slot counter and `LH` the machine
   lineage anchor.  The mint-shape claims (`R2-MINT-SHAPE-EXISTING-POOL`,
   `R2-MINT-SHAPE-EMPTY-POOL`) state exactly this RHS and are kprove-PROVED.
2. **The mint is the only producer.**  The pool (`<r2lineage>` key `-2`) is
   written by exactly two rules: the two `pGateEvalR2` rules (append) and
   `pAcceptR2` (consume).  `pInitR2` writes only key `-1`.  No rule writes a
   receipt anywhere else, and no command has a receipt-shaped parameter
   (section B.3).  Syntactic audit of the rule inventory (section B.2).
3. **The stored inputs are the checked inputs.**  The receipt stores the
   EXACT `FC/RG/CERT` the guard bound (`GateInputMatchesBlockR2`,
   `GateAuthorityMatchesCfgR2`) and the machine-constructed `AC_m`; the
   accept re-checks the binding on the stored objects (defense in depth) and
   the claims `R2-GATE-INPUT-BINDING`-shaped conjuncts appear verbatim in the
   `R2-ACCEPT-IMPLIES-COMMITP` / `R2-VALID-ACCEPT` guards.

Hence a receipt in the pool is always a minted receipt, and a minted
receipt's verdict is always the frozen gate's result over inputs bound to
the exact candidate.  The universal-closure form over arbitrary runs
(`R2-ALL`) remains the disclosed NOT-MECHANIZED item (section E).

---

## D. Correspondence discipline to the frozen 1I predicates

The handoff's preferred architecture (import the frozen gate; do NOT import
`SRW3PROTO`/`SRW3PROTO-R1`) forces R2 to REPRODUCE the 1I protocol
predicates rather than import them: importing `SRW3PROTO` would resurrect
the frozen `pAccept` command and rule as admissible surface — the exact
defect class R2 removes.  K admits exactly one `<k>` cell per definition,
so a module importing both the 1I and R2 configurations cannot compile; the
indirect correspondence chain below is the formally justified alternative
(the handoff's documented-limitation clause).

**What is reproduced with identical formulas** (tags and composition
byte-identical; frozen reference = `phase1i/semantics/srw3proto.k`):

| R2 predicate | Frozen 1I predicate (lines) | Tag/formula |
|---|---|---|
| `ProtoCfgCanonR2` fields 1..8 | `ProtoCfgCanon` (86-95) | 0x9C, same field order |
| `ProtoRootR2` | `ProtoRoot` (94-95) | LinH(canon) |
| `PolicyCommitmentR2` | `PolicyCommitmentI` (113-118) | 0x9D + PolicyAuthId(0xA5) |
| `ProtoAuthorizedSecCtxR2` | `ProtoAuthorizedSecCtx` (123-126) | same projection |
| `CtxCanonR2`/`CtxDigestR2` | `CtxCanonI`/`CtxDigestI` (129-134) | 0xA6 |
| `ProtoBlockR2` (10 fields) | `ProtoBlock` (163-167) | same order |
| `BlockCommitCanonR2`/`BlockCommitR2` | `BlockCommitCanon`/`BlockCommitI` (213-223) | 0x9E |
| `SRW3RootR2` | `SRW3RootI` (227-232) | 0x9F (comparison object) |
| `pdecValidR2/...` + `ProtoDecisionOfGateR2` | `pdecValid/...` + `ProtoDecisionOfGate` (140-154) | 1/0/2, fail-closed |
| `ExecValidPR2`/`SRW3ValidPR2`/`ValidPR2`/`CommitPR2` | `ExecValidP`/`SRW3ValidP`/`ValidP`/`CommitP` (240-266) | same composition |
| `CommitChainLinkedR2` | `CommitChainLinked` (289-301) | same discipline |

**The three legs of the correspondence:**

1. **K conformance claims** (`r2_proofs.k`, all PROVED): `R2-CORRESPONDENCE-
   CONFIG-ROOT`, `-POLICY-COMMITMENT`, `-CTX-DIGEST`, `-BLOCK-COMMIT` — each
   claim's right side is the FROZEN formula transcribed byte-for-byte from
   the cited lines, so the claim certifies the R2 predicate equals the
   frozen composition; plus the ported frozen ladder (PI1/PI2/PIB/PI5/PI7
   over the R2 forms).
2. **Cross-layer byte certificate** (`transcripts/crosslayer/
   r2_byte_certificate_k_raw.txt`, K LLVM + real keccak) reproduced digit-
   for-digit by the Python mirror (`KX-*` cases of `run_r2_attacks.py`),
   including the anchor to the FROZEN 1G transcript: `certid0 =
   89ffea587b63cc787989fe232899c98b6967eeed2e483247d17880dc8da68e95` equals
   the `certd0` recorded in `phase1g/transcripts/part4_k_demo_suite.txt` —
   the R2 objects sit on the frozen 1G certificate bytes exactly.
3. **This audit's line-by-line table** (above) for the textual identity.

**Deliberate R2 extensions (not correspondence items):** the pinned config
gains the gate-authority fields 9..13 (sched/spec/authPT/authGuestD/
authCfgD — the handoff §5.3 requirement that authority parameters be pinned,
NOT derived from the validated context); the machine tracks the second
(evidence-lineage) chain head `<r2linhead>`; the receipt carries the exact
gate inputs and the computed verdict.

---

## E. Trust boundaries and disclosed limitations (unchanged in kind from R1)

1. **Verdict source.**  The verdict is the frozen `VerifyLineageG` result.
   Its soundness rests on the frozen gate module (mechanized in Phase 1G:
   21-conjunct accept, first-fail rejections) and on the K/Python layers
   agreeing with it (byte certificate + KX).  R2 adds no trust.
2. **Haskell-backend hash abstraction (finding 1C-1).**  On the hs backend
   `Keccak256raw` has no evaluators: digest equalities are symbolic
   constraints.  R2's hs demos therefore retain the computed verdict as an
   unevaluated `VerifyLineageG(...)` application (T11) — the receipt
   STRUCTURE is concrete.  The CONCRETE decisions are the LLVM runs (real
   keccak via the pinned krypto shim, T1-T10) and the Python mirror (87/87).
3. **Keccak collision resistance.**  The digest equalities that distinguish
   a substituted policy/context/record from the pinned one rest on keccak
   collision resistance (as in 1I/1I-R1).  No concrete-inequality claim is
   made on the hs backend.
4. **Execution-evidence authenticity.**  The gate verifies the PRESENTED
   execution record (payload/trace/witness/replay layers, frozen).  That an
   off-chain executor's trace truthfully describes historical Ethereum
   execution remains OUTSIDE the model (1F/1H limitation, restated).
5. **Level discipline.**  R2 is a Level-III protocol-model result.  No
   Ethereum consensus integration, Engine-API change, or client support is
   claimed.
6. **R2-ALL (universal closure)** — retried; the kore circularity/implication
   blocker recurs (exact log retained).  The per-claim ladder + the
   producer-exhaustiveness audit (section C) + the parse-level surface
   exclusion (section B) are the mechanized substitutes.
7. **Upgrade path.**  There is deliberately NO config-upgrade transition
   (R1 discipline retained); policy upgrade is a deferred protocol-state
   transition requiring its own authorization semantics.

## F. Verdict-input inventory (the handoff §5.2 checklist, discharge map)

| Handoff binding requirement | Discharged by |
|---|---|
| payload digest ↔ ExecPayloadDigest(execCtxPayload) | `GateInputMatchesBlockR2` conjunct 1 (cert payload digest field) + the frozen L28 hash closure (`az_cert_bind_ok` conj 2) |
| candidate parent state root ↔ gate ctx parent root | conjunct 2 (direct structural) |
| candidate post-state root ↔ validated record state root | conjunct 3 (direct structural) |
| candidate effect digest ↔ record effect-trace digest | conjunct 4 (direct structural) |
| candidate evidence/lineage digest ↔ canonical commitment to the checked record/certificate | conjunct 5 (record's certificate digest; the frozen L28 conj 1 re-derives AzCertId(CERT)) |
| candidate policy commitment ↔ pinned-config commitment | accept-guard hash conjunct `pbPolCommitOf(B) ==K PolicyCommitmentR2(C)` |
| candidate security-context digest ↔ authorized SecCtx digest | accept-guard hash conjunct + `GateCtxAuthorizedR2` (field-wise) |
| gate SecCtx fields ↔ authorized projection | machine-CONSTRUCTED `AC_m` (by construction) + `GateCtxAuthorizedR2` re-check |
| authority params (authPT/authGuestD/authCfgD, sched/spec) ↔ protocol-pinned | pinned config fields 9..13 + `GateAuthorityMatchesCfgR2` + machine construction |
| HEAD ↔ applicable lineage parent of this candidate | machine lineage anchor `<r2linhead>`; the frozen gate verifies the record's own parent linkage against it |
| T ↔ its protocol meaning (slot) | T := `<r2next>`; mint requires `pbSlotOf(B) ==Int N` |
| no missing binding | two explicit heads + receipt fields (block, erc, erp, FC, RG, CERT, AC, verdict, head, slot, linHead, cfg) — nothing unchecked |
