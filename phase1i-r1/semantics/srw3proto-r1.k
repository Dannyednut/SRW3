// =============================================================================
// SRW3 Phase 1I-R1 — FORMAL COMMITMENT/GATE BINDING (REPAIRED TRANSITION)
//                    (phase1i-r1/semantics/srw3proto-r1.k)
//
// Backend: HASKELL.  Purely ADDITIVE over the frozen Phase 1I definitions
// (srw3proto.k is REQUIRED unchanged; the 1G/1H/1I chain is untouched).
//
// K ARCHITECTURE NOTE (why there is no new configuration declaration):
//   K allows exactly ONE <k> cell per definition, and the frozen module
//   already declares the <srw3proto> configuration.  The repair therefore
//   REUSES the frozen configuration verbatim (cells <k> <plineage> <pnext>
//   <phead> <pvalid>) and adds ONLY commands and rules.  This is the
//   maximal-additivity form of the repair: every frozen definition, rule
//   and cell initialization is literally the same module.
//
//   The handoff permits "a persistent configuration cell (or an equivalent
//   immutable protocol-root object)".  The equivalent immutable object used
//   here is a RESERVED METADATA REGION of the lineage map:
//
//     <plineage> ...Map of slot(Int >= 0) -> ProtoBlock (the committed chain)
//                     -1(Int) -> ProtoCfg      (THE PINNED CONFIGURATION)
//                     -2(Int) -> Set           (the gate-receipt pool)
//                </plineage>
//
//   Block slots are always >= 0 (accept requires pbSlotOf(B) ==Int N with N
//   counting from 0), so the negative keys can never collide with a block
//   slot; the frozen blockAt/CommitChainLinked recursions match only
//   ProtoBlock-valued entries and are unaffected (verified by the ported
//   PI7-BASE claim and the R1 chain claims).
//
// REPAIR TARGET (audit/FORMAL-BINDING-AUDIT.md):
//   F2  the frozen pAccept trusts a freely caller-supplied Bool SRW3OK;
//   F4  the model never stores the protocol configuration and pAccept
//       receives a caller-chosen ProtoCfg;
//   F3  PI7-STEP conditions the THEOREM on Commit_P instead of making the
//       TRANSITION enforce it.
//
// REPAIR DESIGN (handoff "Required design", A preferred + B elements):
//
//   1. NO VERDICT ARGUMENT SURVIVES.  The repaired accept command is
//      pAcceptR1(B, ERC, ERP, CV) — the caller cannot name a config and
//      cannot supply a verdict Boolean.  The only security input is a GATE
//      RECEIPT that the machine itself created.
//
//   2. GATE RECEIPT (in-model, unforgeable by construction): the ONLY rule
//      that creates a receipt is the gate-evaluation transition pGateEval;
//      the receipt pool starts EMPTY (absent = empty); an accept CONSUMES
//      its matching receipt exactly once (single use; no replay).  The
//      receipt binds the exact candidate block, the client-derived
//      execution results, the chain head and next-slot counter at gate time
//      (freshness), and the gate verdict.  The DECISION IS DERIVED BY THE
//      TRANSITION: grDecisionOf(R) = ProtoDecisionOfGate(grVerdictOf(R)) —
//      only the frozen "valid-g" verdict maps to pdecValid (1G discipline).
//
//   3. THE TRANSITION ENFORCES THE FULL PREDICATE.  The accept guard checks,
//      DIRECTLY (nothing delegated to the caller or to a theorem):
//        - receipt match:      same block, same ERC/ERP, same head, same
//                              slot, receipt decision == pdecValid;
//        - decision binding:   the block's decision field is pdecValid;
//        - execution validity: ExecValidP(B, ERC, ERP);
//        - policy binding:     pbPolCommitOf(B) ==K PolicyCommitmentI(C)
//                              with C read from THE PINNED CONFIGURATION;
//        - context binding:    pbCtxDOf(B) ==K CtxDigestI(
//                                ProtoAuthorizedSecCtx(C, pbParentRootOf(B)));
//        - structural links:   parent commitment == head, slot == counter;
//        - config identity:    the declared config version CV equals the
//                              pinned config's policy version (decidable
//                              witness; a version substitution rejects).
//
//   4. CONFIGURATION PINNED AT INITIALIZATION, IMMUTABLE THEREAFTER.
//      pInitR1 writes the pin (-1) and the genesis head (ProtoRoot(C))
//      together, and REFUSES to fire when a configuration is already pinned
//      (no in-model re-initialization; there is deliberately NO upgrade
//      transition in R1 — an upgrade without its own authorization
//      semantics would reintroduce the substitution attack; policy upgrade
//      is deferred as an explicit future protocol-state transition and
//      documented in the report).
//
//   5. FAIL-CLOSED EVERYWHERE.  No receipt (empty pool) -> reject.  Missing/
//      unknown verdict -> pdecReject/pdecUnknown (never valid).  Unpinned
//      configuration -> no gate/accept can fire.  Any failed guard falls to
//      the [owise] reject with state unchanged.
//
// TRUST BOUNDARY (stated, not hidden — audit section D):
//   (a) The verdict String is the abstracted output of the frozen Phase 1G
//       VerifyLineageG; its unforgeability rests on the frozen gate module
//       (mechanized separately) being the only producer of "valid-g".
//   (b) The policy/context digest equalities are symbolic constraints on
//       the Haskell backend (no Keccak256raw evaluators — finding 1C-1);
//       deciding them concretely is demonstrated in the Python mirror with
//       real keccak and rests on keccak collision resistance.
//
// SUPERSESSION NOTE: the frozen pInit/pAccept rules remain present in this
// definition (they cannot be removed additively) but are INERT for repaired
// programs: the repaired command surface is {pInitR1, pGateEval,
// pAcceptR1}, and no repaired program contains pInit/pAccept commands.
// The frozen transition's forged-verdict behavior is separately witnessed
// on the pure frozen definition (proofs/old_witness.k).
// =============================================================================

requires "../../phase1i/semantics/srw3proto.k"

module SRW3PROTO-R1
  imports SRW3PROTO

  // ===========================================================================
  // §R1.1  Gate receipts — the only in-model carrier of a gate verdict
  // ===========================================================================

  // A receipt is created ONLY by pGateEval (below).  Fields:
  //   - the exact candidate block (bound at accept by structural equality);
  //   - the client-derived execution results (child root, payload identity);
  //   - the frozen VerifyLineageG verdict string (abstract, boundary (a));
  //   - the chain head and next-slot counter AT GATE TIME (freshness: a
  //     receipt minted under a displaced head cannot authorize a commit —
  //     the reorg/stale-evidence exclusion).
  syntax GateReceipt ::= gateReceipt ( grBlock: ProtoBlock
                                    , grErc:   Bytes
                                    , grErp:   Bytes
                                    , grVerdict: String
                                    , grHead:  Bytes
                                    , grSlot:  Int )

  syntax ProtoBlock ::= grBlockOf   ( GateReceipt ) [function, total]
  syntax Bytes     ::= grErcOf     ( GateReceipt ) [function, total]
  syntax Bytes     ::= grErpOf     ( GateReceipt ) [function, total]
  syntax String    ::= grVerdictOf ( GateReceipt ) [function, total]
  syntax Bytes     ::= grHeadOf    ( GateReceipt ) [function, total]
  syntax Int       ::= grSlotOf    ( GateReceipt ) [function, total]

  rule grBlockOf(gateReceipt(B:ProtoBlock, _:Bytes, _:Bytes, _:String,
                              _:Bytes, _:Int)) => B:ProtoBlock
  rule grErcOf(gateReceipt(_:ProtoBlock, E:Bytes, _:Bytes, _:String,
                           _:Bytes, _:Int)) => E:Bytes
  rule grErpOf(gateReceipt(_:ProtoBlock, _:Bytes, P:Bytes, _:String,
                           _:Bytes, _:Int)) => P:Bytes
  rule grVerdictOf(gateReceipt(_:ProtoBlock, _:Bytes, _:Bytes, V:String,
                               _:Bytes, _:Int)) => V:String
  rule grHeadOf(gateReceipt(_:ProtoBlock, _:Bytes, _:Bytes, _:String,
                            H:Bytes, _:Int)) => H:Bytes
  rule grSlotOf(gateReceipt(_:ProtoBlock, _:Bytes, _:Bytes, _:String,
                            _:Bytes, S:Int)) => S:Int

  // THE DERIVED DECISION — computed by the transition, not supplied by the
  // caller.  ProtoDecisionOfGate (frozen, total) maps ONLY "valid-g" to
  // pdecValid; every other verdict maps to pdecReject (fail-closed).
  syntax Int ::= grDecisionOf ( GateReceipt ) [function, total]
  rule grDecisionOf(R:GateReceipt) => ProtoDecisionOfGate(grVerdictOf(R))

  // ===========================================================================
  // §R1.2  Reserved metadata region accessors (lineage-map keys -1 / -2)
  // ===========================================================================

  // The pinned configuration: RESERVED KEY -1 (literal).  Absent until
  // pInitR1.  (Literal Int keys are used so the map-matching equations
  // compile on the Haskell backend; named-key functions would leave the
  // key symbolic.)
  syntax ProtoCfgOrNone ::= ProtoCfg | "noCfg"
  syntax ProtoCfgOrNone ::= storedCfgOf ( Map ) [function, total]
  rule storedCfgOf(-1 |-> C:ProtoCfg REST:Map) => C:ProtoCfg
  rule storedCfgOf(REST:Map) => noCfg [owise]

  // The receipt pool: RESERVED KEY -2 (literal).  Absent = empty pool
  // (fail-closed).
  syntax Set ::= receiptsOf ( Map ) [function, total]
  rule receiptsOf(-2 |-> S:Set REST:Map) => S:Set
  rule receiptsOf(REST:Map) => .Set [owise]

  syntax Bool ::= cfgPinned ( Map ) [function, total]
  rule cfgPinned(-1 |-> _:ProtoCfg REST:Map) => true
  rule cfgPinned(REST:Map) => false [owise]

  // ===========================================================================
  // §R1.3  Repaired commands (first-class PCmdI items — they thread through
  // the frozen runNil/pCons command-list machinery unchanged)
  // ===========================================================================

  syntax PCmdI ::= "pInitR1" "(" ProtoCfg ")"
               // gate evaluation: candidate, client-derived child root,
               // client-derived payload identity, frozen gate verdict
               | "pGateEval" "(" ProtoBlock "," Bytes "," Bytes "," String ")"
               // accept: candidate + execution results + the DECLARED
               // config-version witness.  NO verdict, NO config.
               | "pAcceptR1" "(" ProtoBlock "," Bytes "," Bytes "," Int ")"

  // ---------------------------------------------------------------------------
  // pInitR1 — pins the configuration and anchors the genesis head at the
  // protocol root of the SAME config, from ONE argument.  Refuses to fire
  // when a configuration is already pinned (no re-initialization; the pin
  // is immutable thereafter — REPAIR F4).
  // ---------------------------------------------------------------------------
  rule <k> pInitR1(C:ProtoCfg) => .K ... </k>
       <phead> _:Bytes => ProtoRoot(C) </phead>
       <plineage> L:Map => L[-1 <- C] </plineage>
    requires notBool cfgPinned(L:Map)

  // Refused re-initialization ([owise]): when a configuration is already
  // pinned, pInitR1 consumes the command and changes NOTHING (fail-closed
  // restoration; the pin is immutable).
  rule <k> pInitR1(_:ProtoCfg) => .K ... </k>
       <plineage> L:Map </plineage>
       <pnext> N:Int </pnext>
       <phead> H:Bytes </phead>
       <pvalid> V:Bool </pvalid>
    [owise]

  // ---------------------------------------------------------------------------
  // pGateEval — the ONLY rule that creates a receipt.  Records the frozen
  // gate's verdict for THIS candidate under THIS head/slot.  Mutates NO
  // chain state (the head, counter and committed blocks are untouched — the
  // gate evaluates, it does not commit).
  // ---------------------------------------------------------------------------
  // Two explicit-shape gate rules (existing pool / no pool yet) so that the
  // RHS is a map CONS term — symbolic map-update terms do not reduce on the
  // Haskell backend and would block the proof ladder.
  rule <k> pGateEval(B:ProtoBlock, ERC:Bytes, ERP:Bytes, V:String) => .K ... </k>
       <pnext> N:Int </pnext>
       <phead> H:Bytes </phead>
       <plineage> ( -1:Int |-> C:ProtoCfg )
                  ( -2:Int |-> PS:Set )
                  L3:Map
               => ( -1:Int |-> C:ProtoCfg )
                  ( -2:Int |-> SetItem(gateReceipt(B, ERC, ERP, V, H, N))
                                       PS:Set )
                  L3:Map </plineage>

  rule <k> pGateEval(B:ProtoBlock, ERC:Bytes, ERP:Bytes, V:String) => .K ... </k>
       <pnext> N:Int </pnext>
       <phead> H:Bytes </phead>
       <plineage> ( -1:Int |-> C:ProtoCfg ) L3:Map
               => ( -1:Int |-> C:ProtoCfg )
                  ( -2:Int |-> SetItem(gateReceipt(B, ERC, ERP, V, H, N))
                                       .Set )
                  L3:Map </plineage>
    requires notBool ( -2:Int in_keys(L3:Map) )

  // ---------------------------------------------------------------------------
  // pAcceptR1 — the ONLY rule that extends the committed chain (REPAIR
  // F2/F3).  The guard IS the commitment predicate: every conjunct of
  // Commit_P is checked HERE, so R1-ACCEPT-IMPLIES-COMMITP states the
  // guard => Commit_P implication WITH NO COMMIT_P PREMISE.  The caller
  // cannot influence any conjunct:
  //   - the verdict/decision comes from the machine-created receipt;
  //   - the config comes from the pinned -1 entry;
  //   - the authorized context is derived from the pinned config and the
  //     candidate's parent root (the applicable lineage head — the 1I
  //     convention retained);
  //   - execution validity is checked against the receipt-bound execution
  //     results.
  // On accept the matching receipt is CONSUMED (single use; no replay).
  // ---------------------------------------------------------------------------
  rule <k> pAcceptR1(B:ProtoBlock, ERC:Bytes, ERP:Bytes, CV:Int) => .K ... </k>
       <plineage> ( -1:Int |-> C:ProtoCfg )
                  ( -2:Int |-> SetItem(R:GateReceipt) RS:Set )
                  L3:Map
               => ( -1:Int |-> C:ProtoCfg )
                  ( -2:Int |-> RS )
                  ( L3[pbSlotOf(B:ProtoBlock) <- B:ProtoBlock] )
       </plineage>
       <pnext> N:Int => N +Int 1 </pnext>
       <phead> H:Bytes => BlockCommitI(B:ProtoBlock, C:ProtoCfg) </phead>
       <pvalid> V:Bool => V:Bool </pvalid>
    requires grBlockOf(R)   ==K B
         andBool grErcOf(R) ==K ERC
         andBool grErpOf(R) ==K ERP
         andBool grHeadOf(R) ==K H
         andBool grSlotOf(R) ==Int N
         andBool grDecisionOf(R) ==Int pdecValid          // derived, fail-closed
         andBool pbDecisionOf(B) ==Int pdecValid          // decision binding
         andBool ExecValidP(B, ERC, ERP)                  // execution binding
         andBool pbPolCommitOf(B) ==K PolicyCommitmentI(C)     // policy binding
         andBool pbCtxDOf(B) ==K CtxDigestI(ProtoAuthorizedSecCtx(C,
                                    pbParentRootOf(B)))        // context binding
         andBool BytesEq(pbParentCommitOf(B), H)          // parent commitment
         andBool pbSlotOf(B) ==Int N                      // one block per slot
         andBool CV ==Int pcPolicyVOf(C)                  // config witness

  // REJECT (restore, [owise]): ANY failure — no pinned config, no receipt,
  // a receipt for a different candidate/head/slot, a rejection or unknown
  // decision, an execution mismatch, a policy/context mismatch, a
  // structural mismatch, a config-version substitution — leaves head,
  // counter, lineage map (committed chain AND metadata region) COMPLETELY
  // unchanged.
  rule <k> pAcceptR1(_:ProtoBlock, _:Bytes, _:Bytes, _:Int) => .K ... </k>
       <plineage> L:Map </plineage>
       <pnext> N:Int </pnext>
       <phead> H:Bytes </phead>
       <pvalid> V:Bool </pvalid>
    [owise]

endmodule
