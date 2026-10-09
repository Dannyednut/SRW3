# SRW3 Phase 1I-R1 — Formal Binding Audit (FORMAL-BINDING-AUDIT.md)

Scope: narrow formal audit of the Phase 1I K protocol model
(`phase1i/semantics/srw3proto.k`, `phase1i/proofs/pi_proofs.k`) at base
commit `e04fbb6147157fb11537de68618a001fd4b9afbe` (tag `phase1i-complete`).
This audit is source-level; each finding below is reproduced mechanically
(see `phase1i-r1/transcripts/`) before any repair is designed.

## A. The four source-level findings (confirmed)

### F1. `CommitP` is a pure predicate; the transition does not consult it

`CommitP(B, ERC, ERP, C, LH)` is *defined* as `ValidP(B, ERC, ERP, C, LH)`
(srw3proto.k §5, line 263–267), i.e. the conjunction of

* `ExecValidP(B, ERC, ERP)` — child post-state root and payload identity
  binding to the client-derived execution results;
* `pbDecisionOf(B) ==Int pdecValid` — a valid protocol decision field;
* `pbPolCommitOf(B) ==K PolicyCommitmentI(C)` — the config-authorized policy
  commitment;
* `pbCtxDOf(B) ==K CtxDigestI(ProtoAuthorizedSecCtx(C, LH))` — the authorized
  SecurityContext digest for the applicable lineage head.

The operational accept rule (`pAccept`, §6, lines 340–348) **never mentions
`CommitP`**. Its guard is exactly:

```
BytesEq(pbParentCommitOf(B), H)   // parent-commitment link
andBool pbSlotOf(B) ==Int N       // next-slot link
andBool SRW3OK:Bool ==K true      // caller-supplied verdict
```

### F2. The security verdict is a freely caller-supplied `Bool`

`pAccept(B, ERC, ERP, C, SRW3OK)` takes the verdict as a public Boolean
argument. Any caller that can name the command can pass `SRW3OK = true`
regardless of what the gate actually decided, regardless of execution
validity, and regardless of the policy/context binding. The [owise] reject
rule (lines 353–358) only fires when the guard fails — and the guard fails
only on the structural links or a `false` verdict. A block with
`pbDecisionOf(B) ==Int pdecReject` (the gate said *invalid-policy*) is
**operationally committed** by `pAccept(B, ERC, ERP, C, true)`.

Mechanical witness: `transcripts/k/OLD-ACCEPTS-FORGED.k` — a claim over the
**unmodified** frozen module whose only premises are the structural links
and `SRW3OK ==K true`, with destination the *extended* chain state. It is
proved by the frozen rule itself, demonstrating that the frozen transition
extends the committed chain with **no validity premise of any kind**
(`transcripts/k/kprove_OLD-ACCEPTS-FORGED.log`). The Python mirror
(`transcripts/attacks/`) reproduces the same acceptance concretely with real
keccak digests.

### F3. `PI7-STEP` conditions the theorem, not the transition

`PI7-STEP` (pi_proofs.k lines 196–213) adds
`CommitP(B, ERC, ERP, C, pbParentRootOf(B)) ==K true` to the claim's
`requires`, commented as "the semantic MEANING of the opaque verdict". This
proves a *conditional* step — but the condition exists only in the theorem.
The operational rule it claims to describe does not check `CommitP`, so the
theorem is a statement about a transition that never occurs as stated: the
reachable transition needs only `SRW3OK ==K true`. This is exactly the
"premise represented as a result" pattern the handoff forbids. PI7-STEP is
not *false* — it is *not about the machine*.

### F4. The protocol configuration is not pinned; `pAccept` receives a caller-chosen config

`pInit(C)` sets only `<phead> := ProtoRoot(C)` (lines 334–335). The K
configuration (lines 316–322) has cells `<k> <plineage> <pnext> <phead>
<pvalid>` — **no persistent protocol-configuration cell**. Every later
`pAccept(..., C, ...)` receives a *fresh caller-supplied* `C:ProtoCfg`, and
the rule neither stores it nor compares it with the initialization config.
Consequences:

* the head update `BlockCommitI(B, C)` commits under whatever config the
  caller presents at accept time (policy-commitment substitution at the
  transition level: initialize under C1, commit under C2);
* the authorized SecurityContext used in any claim is whatever config the
  claim instantiates, not a protocol-pinned one;
* nothing in the transition prevents implicit configuration mutation across
  an accept sequence.

## B. What the frozen layer gets right (retained)

* `CommitP`/`ValidP`/`SRW3ValidP` are correctly *defined* (the compound
  predicate is sound); the defect is operational, not definitional.
* The decision mapping `ProtoDecisionOfGate` is total and fail-closed:
  only `"valid-g"` maps to `pdecValid`; every other verdict maps to
  `pdecReject`; missing evaluation is `pdecUnknown` (never valid).
* The authorized values (policy commitment, SecurityContext) are derived
  from the configuration (level 0) and the applicable lineage head — never
  from block-supplied data (the 1G/SC-10 discipline at the protocol layer).
* The structural links (parent commitment, next slot) and the [owise]
  state-unchanged reject are correct and retained by the repair.
* The keccak abstraction discipline (finding 1C-1): the Haskell backend has
  no evaluators for `Keccak256raw`; every claim must treat digests as opaque
  symbolic Bytes. The repair keeps this discipline and states the exact
  boundary where it bites (see §D).

## C. Threat model for the repair (the decisive test)

An adversary controls command construction: it can submit `pAccept` with
arbitrary block fields, arbitrary execution results, an arbitrary verdict
Boolean (frozen model), and — after the repair — arbitrary `pGateEval`
arguments (candidate, execution results, verdict string). The adversary
**cannot** rewrite the machine: the initial receipt cell is empty, receipts
are created only by the gate-evaluation transition, and no command argument
flows into a cell without a rule putting it there.

Decisive test (handoff + assignment): an **invalid** block remains
uncommittable even when the caller attempts to supply an accepting verdict;
a **valid** block must still be able to commit (non-vacuity).

## D. Trust boundaries that remain after the repair (stated up front)

1. **Gate-verdict provenance.** The verdict `String` consumed by
   `pGateEval` is the abstracted output of the frozen Phase 1G
   `VerifyLineageG` evaluation. The protocol model binds the verdict to the
   candidate (receipt) and derives the decision (`ProtoDecisionOfGate`), but
   the *unforgeability of the string* `"valid-g"` rests on the frozen gate
   module (mechanized separately in Phase 1G) being the only producer.
   In-model, the only producer of receipts is `pGateEval` — this is the
   stated boundary.
2. **Hash collision resistance.** The policy-commitment and context-digest
   equalities (`pbPolCommitOf(B) ==K PolicyCommitmentI(C)`,
   `pbCtxDOf(B) ==K CtxDigestI(...)`) are enforced by the repaired accept
   rule. On the Haskell backend these are symbolic constraints (proved
   claims carry them); *deciding* them for concrete bytes requires a keccak
   evaluator (Haskell backend has none — finding 1C-1). Two configs with
   identical decidable fields but different preimages are distinguished only
   under keccak collision resistance — demonstrated concretely in the Python
   mirror; recorded as the named trust boundary on the K side.
3. **No consensus-layer claim.** As in Phase 1I: nothing here claims
   Ethereum protocol integration or consensus enforcement. This is a
   protocol-model result at Level III.

## E. Verdict of the audit

The Phase 1I operational model **does not** enforce the commitment predicate
it proves theorems about: the transition accepts a caller-forged verdict
(F2), and the configuration is not pinned (F4). The defensible conclusion of
Phase 1I stands *only* under the assumption that callers always pass the
honestly evaluated verdict — an assumption the transition itself does not
enforce. R1 closes this with the receipt-bound, config-pinned model in
`phase1i-r1/semantics/srw3proto-r1.k`.
