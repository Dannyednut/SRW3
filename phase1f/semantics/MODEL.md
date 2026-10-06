# SRW3 Phase 1F — Execution-Effect Binding Model (MODEL.md)

**Status: FROZEN at Phase 1F start.** This is the normative model specification.
Everything executable (K abstract, KEVM, Python) must implement exactly this.

## 1. The research question and the three levels

Phase 1F attacks **Level 3**: `PresentedEffects == TrueEffects(execution)` —
can the SRW3 gate bind its security decision to authenticated evidence of
execution-derived effects, so that the lineage records what a concrete
execution ACTUALLY produced, rather than only (L1) a self-consistent
presentation or (L2) an anchored state representation?

The three levels are kept strictly separate everywhere in this phase:

```text
L1 (Phase 1D-R1, FROZEN):  post == Apply(pre, presented effects)
                           — presented-record internal self-consistency.
L2 (Phase 1E, FROZEN):     post anchored to an authoritative state commitment
                           (fixed-depth Merkle root == anchor).
L3 (Phase 1F, THIS PHASE): the digest-bound effects are evidenced by an
                           ordered, execution-derived effect trace, bound to
                           an execution identity and a witness structure.
```

No result at one level may be restated at another. In particular: a Level-3
BINDING result is a statement about the record↔trace↔identity↔state chain;
it is NOT, by itself, a statement that the trace is historically true. Trace
authenticity is an input-side property at the abstract layer (A-F3) and is
demonstrated (not proved) at the instrumented-execution layer (KEVM), where
the trace is derived by the semantics from real opcode execution and never
passes through producer hands.

## 2. The effect-trace fragment (minimal, explicitly bounded)

Vocabulary (op codes):

| op | event | KEVM source | fields |
|----|-------|-------------|--------|
| 1  | Read   | SLOAD  | (app, slot, value-read-now) |
| 2  | Write  | SSTORE | (app, slot, value-written) |
| 3  | Call   | CALL   | (app, target, call-value) |
| 4  | Return | RETURN | (app, offset, size) |

**Fragment boundary (explicit).** LOGn, CREATE/CREATE2, CALLCODE,
DELEGATECALL, STATICCALL, SELFDESTRUCT, gas accounting, and memory operations
are OUTSIDE the fragment. This is a documented under-approximation of EVM
effect vocabulary chosen because it is exactly the set the Phase-1B/1D/1E
obligation surface (storage-level obligations over REAL EVM storage) can
evaluate. Extending the vocabulary is future work and changes no frozen layer.

**Field bounds (model REFUSE, explicit, never silent).**
`0 ≤ app < 2^32`, `0 ≤ slot < 2^32` (matching the Phase 1E flat-key space
`k = app·2^32 + slot`), `0 ≤ a1 < 2^64`, `0 ≤ a2 < 2^64`. Violation is the
explicit verdict `invalid-execbounds`, an EX13-style model refuse.

## 3. Canonical, order-preserving, domain-separated encodings

Every `Bytes` production below is big-endian, fixed-width. `I2B4/I2B8` are
`Int2Bytes(4/8, ·, BE)`.

```text
EventBytes(exEvt(op, app, a1, a2)) = op₁ ‖ app₄ ‖ a1₈ ‖ a2₈        (21 bytes)
TraceBytes(T = e1..en)            = 0x03 ‖ n₄ ‖ EventBytes(e1) ‖ … ‖ EventBytes(en)
```

**Order is never destroyed.** Events appear in TraceBytes in exact trace
order; there is NO sorting, NO deduplication, NO set semantics anywhere in
the trace encoding. Two traces with the same multiset of events in different
orders have DIFFERENT TraceBytes (hence different digests) by construction.

EffectTraceDigest(T) = Keccak256(TraceBytes(T)).

Domain-separation tags (single leading byte): `0x03` trace, `0x11` payload,
`0x12` env, `0x13` config, `0x1F` execution id, `0x57` witness. These are
distinct from each other and from the Phase 1E tags (`0x00` leaf, `0x01`
node, `0x02` tree). Collision-resistance of Keccak256 itself is A-E1/A-F1.

## 4. Execution identity (ExecutionId)

```text
PayloadDigest = Keccak256(0x11 ‖ payloadBytes)          — the transition input
EnvDigest     = Keccak256(0x12 ‖ caller₂₀ ‖ callValue₈)  — who triggers, with what
ConfigDigest  = Keccak256(0x13 ‖ schedule₈ ‖ specVersion₄) — under which rules
ExecutionId   = Keccak256(0x1F ‖ parentStateRoot₃₂ ‖ PayloadDigest₃₂
                               ‖ ConfigDigest₃₂ ‖ EnvDigest₃₂)
```

Only fields with a demonstrated security role are included (the fragment
boundary: caller, value, payload, parent root, schedule/spec). Replay of the
same payload against a different parent root, a different caller/env, or a
different fork config yields a different ExecutionId — demonstrated by
negative controls F5/F6. `schedule₈` is the ASCII schedule name zero-padded
to 8 bytes (`"CANCUN" ‖ 0x00 0x00`); `specVersion₄ = 1`.

`parentStateRoot` is the Phase 1E state root of the PARENT record (threaded
lineage), so the execution identity is bound to the exact pre-state
representation the lineage anchors — PreRoot + ExecutionId + TrueEffects +
PostRoot is the binding chain.

## 5. The execution witness

```text
ExecWit(version=1, parentStateRoot, executionId, payloadDigest,
        declaredEffectsDigest, effectTraceDigest, postStateRoot, execConfigDigest)
WitBytes = 0x57 ‖ v₄ ‖ (each 32-byte field in the order above)
ExecWDigest = Keccak256(WitBytes)
```

Coherence (each checked by the gate; any failure = `invalid-witness`):
`w.parentStateRoot == ctx.parentStateRoot`, `w.executionId == rec.execId`,
`w.payloadDigest == PayloadDigest(ctx.payload)`,
`w.declaredEffectsDigest == linEffectDOf(rec)`,
`w.effectTraceDigest == rec.effTraceDigest`,
`w.postStateRoot == linStateRootOf(recE)`,
`w.execConfigDigest == ConfigDigest(ctx.config)`.

**Signature ≠ authenticity.** A producer signature over the witness (or any
record field) attests authorship, never historical truth. Nothing in this
phase treats a signature as evidence of execution authenticity.

## 6. Trace semantics: writes, replay, projection

```text
ExecTraceWrites(T): nested map; walk T in order; Write(app,slot,v) performs
  LinSetKV(map, app, slot, v) (last write wins); other events are state-silent.
ExecReplay(T, pre): working map W := pre; walk T in order:
  Read(app,slot,v): require v == LinIntAt(W, app, slot)   (0 when absent);
  Write(app,slot,v): W := LinSetKV(W, app, slot, v);
  Call/Return: no state effect.
  Returns (ok, W).
ExecReplayOk(pre, T, post) = ok ∧ LinCanonKV(post) == LinCanonKV(W).
```

ExecReplayOk is the verifier-side trace validation: it subsumes the Phase 1E
composition discipline (the trace's writes must EXACTLY produce the presented
post) AND validates every presented read observation against the replayed
working state — this is the mechanism that binds OBSERVATIONS (e.g., the
price an oracle read at execution time) into the record.

Lemma (mechanization target EX-WRITES-REPLAY): the replay's final map equals
`LinApplyEff2(pre, ExecTraceWrites(T))` — unconditional, structural induction
on T. Consequently `ExecReplayOk` decomposes as read-consistency ∧ the
corrected-composition byte equality over `ExecTraceWrites(T)`.

Projection π_P: `ExecProj(T)` drops Read events, keeping Write/Call/Return in
order. Verifier claims:
- EX-PROJ-W: `ExecTraceWrites(ExecProj(T)) == ExecTraceWrites(T)` — the
  composition half of the verdict needs only the projection;
- read sensitivity lives in the digest and the replay (the digest binds
  observations; the replay validates them). The full-trace digest therefore
  distinguishes traces the projection does not — bound to A-F1 for digest
  distinctness.

**No state→trace assumption anywhere.** The model never infers trace equality
from post-state equality nor the converse; equal final states with divergent
traces yield distinct digests and distinct `childF` (demonstrated F8).

## 7. Record extension (strictly additive): LinRecF

```text
LinRecF = (base: LinRecE, execId, effTraceDigest, execWDigest, execConfigDigest)
CanonCoreF = CanonCoreE(base) ‖ execId ‖ effTraceDigest ‖ execWDigest ‖ execConfigDigest
childF     = Keccak256(CanonCoreF)
```

`CanonCoreE` is a strict PREFIX of `CanonCoreF`; the base `childE` is carried
unchanged. The legacy (1D) and Level-2 (1E) verification chains run unchanged
on the projections.

## 8. Verification context and Gate_F (first-fail, total)

```text
ExecCtx = ( AuthCtx,                       — the 1E context (incl. anchor)
            execParentRoot,                — threaded parent state root
            execPayload, execConfig, execEnv,
            execTrace,                     — PRESENTED ordered trace
            execWitness )                  — PRESENTED witness
```

VerifyLineageF(recF, ctx, tid, head) — first-fail chain; every layer below
`VerifyLineageA` is unchanged and fires first:

```text
[ legacy 12 verdicts → corrected-composition → capacity → padkey
  → state-root → anchor → childe ]            (Phase 1E chain, unchanged)
invalid-execbounds   some event violates §2 bounds            (model REFUSE)
invalid-execconfig   execConfigDigest ≠ ConfigDigest(ctx.execConfig)
invalid-execid       execId ≠ ExecutionId(parentRoot, payloadDigest,
                                          configDigest, envDigest)  [recomputed]
invalid-efftrace     effTraceDigest ≠ Keccak256(TraceBytes(ctx.execTrace))
invalid-effdecl      H(canon(declared effects)) ≠ H(canon(ExecTraceWrites(trace)))
                     — THE LEVEL-3 CORE CHECK: PresentedEffects must be
                     byte-canonically EQUAL to the write projection of the
                     bound trace (effect equality made DECIDABLE, not
                     post-relative)
invalid-witness      ExecWDigest mismatch OR coherence failure (§5)
invalid-effbind      NOT ExecReplayOk(pre, ctx.execTrace, presented post)
valid-f
```

The full accept condition `valid-f` is the conjunction of **14** atomic
conjuncts: legacy-chain ∧ corrected-composition ∧ capacity ∧ padkey ∧
state-root ∧ anchor ∧ childe ∧ execbounds ∧ execconfig ∧ execid ∧ efftrace ∧
effdecl ∧ witness ∧ effbind. (The task brief listed 12 candidate conjuncts;
the actual count under the frozen layer decomposition is 14 — recorded here,
not silently reconciled.)

## 9. What Gate_F acceptance means — and does not mean

**Means (binding).** Under valid-f, every conjunct holds; in particular the
DECLARED effects are byte-canonically equal to the write projection of the
presented, digest-bound trace (the Level-3 core equality); the presented
post is exactly the result of applying those writes to the presented pre;
every presented read observation is replay-consistent; the execution identity is exactly the
domain-separated recomputation over (parent root, payload, config, env); the
witness coheres with the record and the context; and all Level-1/Level-2
certificates hold.

**Does not mean (authenticity boundary).** That the presented trace is the
trace the real execution produced. At the abstract layer the trace is a
presented input (A-F3): a producer able to forge ALL presented artifacts
consistently (trace + record + witness, co-signed) produces an internally
consistent Level-3 record — the same authorized-dishonest-producer boundary
as every prior phase. Closing that boundary requires the trace source to be
execution-derived: instrumented execution (demonstrated at the KEVM layer,
where the trace is built by the semantics from real opcode execution and
cannot pass through producer hands) or verifier re-execution (REQUIRES
CLIENT/PROTOCOL SUPPORT). Phase 1F claims the BINDING; the authenticity of
the trace SOURCE is explicitly out of scope for the abstract layer and
demonstrated (not proved) at the KEVM layer.

## 10. Assumption census (nothing hidden)

| ID | Assumption | Classification |
|----|------------|----------------|
| A-F1 | Keccak256 collision resistance (digest distinctness under differing preimages) | REQUIRES CRYPTOGRAPHIC ASSUMPTION (inherits A-E1) |
| A-F2 | Canonical-encoding injectivity (event/trace/witness/canon-F) | STRUCTURAL (fixed-width fields, order-preserving, domain tags) |
| A-F3 | Trace authenticity at the abstract layer (the presented trace is the execution's trace) | NOT ASSUMED by the gate — explicit verifier-domain boundary; closure requires REQUIRES CLIENT/PROTOCOL SUPPORT (re-execution / executor attestation); demonstrated by instrumented KEVM execution |
| A-F4 | Fragment field bounds (§2) | explicit REFUSE on violation (invalid-execbounds) |
| A-F5 | Parent-root threading authority (the threaded parent state root is the parent record's anchored root) | inherits A-E3 for the chain root; threading itself is mechanized |

## 11. Anchors and provenance independence

The Level-3 extension consumes the anchor as an input exactly as Phase 1E
does (A-E3 unchanged). Anchor provenance is NOT redefined, NOT derived from
execution evidence, and NOT circularly strengthened by this phase: provenance
remains REQUIRES CLIENT/PROTOCOL SUPPORT. The execution-binding chain
(PreRoot + ExecutionId + TrueEffects + PostRoot) is a NEW binding axis; it
neither subsumes nor replaces the state-anchoring axis.
