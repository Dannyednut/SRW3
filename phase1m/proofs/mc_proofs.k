// =============================================================================
// SRW3 PHASE 1M — THE WORKSTREAM-C PROOF LADDER (mc_proofs.k, hs)
//                    THE GATE-FAILURE PARTITION: EXPLICIT, NON-COMMITTING,
//                    DOMAIN-COVERED (the B4 removal, measured).
//
// One definition: the M3 machine (srw3closure-j-m3.k = M2 + the ONE [owise]
// gate-failure transition writing jrefusedGate()).
//
// THE PARTITION (the handoff §4 requirement, specified BEFORE the
// transition): for every well-formed pGateEvalJ command in any state,
// EITHER a gate-mint rule matches (the pool-exists mint, or the fresh-pool
// mint — the 10-conjunct guard) and the command is consumed with the
// machine-derived receipt minted, OR neither matches and the [owise]
// refusal consumes the command writing ONLY <jrefuse> := jrefusedGate().
// The partition is EXHAUSTIVE BY CONSTRUCTION (K's [owise] semantics: the
// rule fires iff no other rule for the command matches) and
// NON-OVERLAPPING ([owise] cannot fire when a mint matches).  The claims:
//
//   MC-GATE-COVERAGE — the domain-coverage claim: from a mint-compatible
//       initialized state with the guard UNPINNED (symbolic), the command
//       is CONSUMED on every path (both mint branches and the refusal
//       branch all end in <k> .K).  Over M2 this claim FAILS on the stuck
//       guard-false branch (the B4 stuck path — the OLD witness,
//       mc_old_proofs.k).  PROVED over M3 is the B4 removal, measured.
//   MC-GATE-REFUSE-NOCOMMIT / -WITNESS-EMPTYPOOL — the refusal path's
//       non-committing property on the CONCRETE-refuted mint shapes (the
//       1L convention: source patterns pinning CONCRETE pool shapes refute
//       the mint unifications syntactically, so the refusal is the only
//       live rule and every committed cell is framed UNCHANGED).
//   MC-NEG-REFUSE-ON-MINT — NEGATIVE CONTROL, MUST FAIL: with the mint
//       rules live (pools present, guards symbolic) the "refusal, nothing
//       else moves" destination is false on the mint branch (the pool
//       moves) — if this PROVED, the refusal over-applied (a GATE ALARM).
//
// LABEL DISCIPLINE: raw exit codes never relabeled; Level III only.
// =============================================================================

requires "../semantics/srw3closure-j-m3.k"

module MC-PROOFS
  imports SRW3CLOSURE-J-M3

  // ===========================================================================
  // §MC1. THE DOMAIN COVERAGE (the B4 removal, measured)
  // ===========================================================================

  claim // MC-GATE-COVERAGE-GATEPOOL: the DOMAIN COVERAGE over the
        // gate-pool-present shape: with -2 pinned present (the fresh-pool
        // mint is SYNTACTICALLY refuted), the live rules are the
        // pool-exists mint and the [owise] refusal — the claim closes iff
        // EVERY live branch consumes the command.  Over M3: mint -> .K,
        // refusal -> .K — the stuck path is GONE.  Over M2 the guard-false
        // branch is STUCK (no rule matches) and the claim FAILS — the OLD
        // witness (mc_old_proofs.k; the 1L B4 class).
    <k> pGateEvalJ(B:JBlockJ, FC:ExecCtx, RG:LinRecG, CERT:AuthzCert,
                   ERC:Bytes, ERP:Bytes) => .K </k>
    <jnext> N:Int </jnext>
    <jhead> H:Bytes </jhead>
    <jlinhead> LH:Bytes </jlinhead>
    <janchor> A:Bytes </janchor>
    <jlineage> ( -1:Int |-> C:ProtoCfgR3 )
               ( -3:Int |-> PCAT:JCatalog )
               ( -2:Int |-> PS:Set )
               ( -4:Int |-> SetItem(E:JExecReceipt) ES:Set )
               L2:Map </jlineage>
    <jrefuse> RF:JRefuse </jrefuse>
    [label(MC-GATE-COVERAGE-GATEPOOL)]

  claim // MC-GATE-COVERAGE-FRESH: the same over the NO-GATE-POOL shape
        // (the CONCRETE .Map tail refutes the pool-exists mint
        // syntactically): the live rules are the fresh-pool mint and the
        // [owise] refusal — every live branch must consume the command.
    <k> pGateEvalJ(B:JBlockJ, FC:ExecCtx, RG:LinRecG, CERT:AuthzCert,
                   ERC:Bytes, ERP:Bytes) => .K </k>
    <jnext> N:Int </jnext>
    <jhead> H:Bytes </jhead>
    <jlinhead> LH:Bytes </jlinhead>
    <janchor> A:Bytes </janchor>
    <jlineage> ( -1:Int |-> C:ProtoCfgR3 )
               ( -3:Int |-> PCAT:JCatalog )
               ( -4:Int |-> SetItem(E:JExecReceipt) ES:Set ) .Map </jlineage>
    <jrefuse> RF:JRefuse </jrefuse>
    [label(MC-GATE-COVERAGE-FRESH)]

  // ===========================================================================
  // §MC2. THE REFUSAL IS NON-COMMITTING (the concrete-refuted mint shapes)
  // ===========================================================================

  claim // MC-GATE-REFUSE-NOCOMMIT: on the JUST-INITIALIZED shape (the two
        // pins, NO pools — the CONCRETE .Map tail refutes both mint
        // unifications syntactically: their source patterns require the
        // -4 entry), the gate command takes the EXPLICIT refusal: the
        // command is consumed and ONLY the diagnostic is written; the
        // committed state, the slot counter, both heads, the anchor, and
        // the valid-bit are UNCHANGED.
    <k> pGateEvalJ(B:JBlockJ, FC:ExecCtx, RG:LinRecG, CERT:AuthzCert,
                   ERC:Bytes, ERP:Bytes) => .K </k>
    <jstate> S:Map => S:Map </jstate>
    <jlineage> ( -1:Int |-> C:ProtoCfgR3 ) ( -3:Int |-> PCAT:JCatalog ) .Map
            => ( -1:Int |-> C:ProtoCfgR3 ) ( -3:Int |-> PCAT:JCatalog ) .Map </jlineage>
    <jnext> N:Int => N:Int </jnext>
    <jhead> H:Bytes => H:Bytes </jhead>
    <jlinhead> LH:Bytes => LH:Bytes </jlinhead>
    <janchor> A:Bytes => A:Bytes </janchor>
    <jrefuse> _:JRefuse => jrefusedGate() </jrefuse>
    <jvalid> V:Bool => V:Bool </jvalid>
    [label(MC-GATE-REFUSE-NOCOMMIT)]

  claim // MC-GATE-REFUSE-WITNESS-EMPTYPOOL: the initialized machine with an
        // EMPTY exec pool (the CONCRETE .Set refutes the fresh-mint's
        // SetItem(E) ES source requirement syntactically; the pool-exists
        // mint's -2 requirement is likewise absent): the gate command takes
        // the EXPLICIT refusal and NOTHING moves.
    <k> pGateEvalJ(B:JBlockJ, FC:ExecCtx, RG:LinRecG, CERT:AuthzCert,
                   ERC:Bytes, ERP:Bytes) => .K </k>
    <jstate> S:Map => S:Map </jstate>
    <jlineage> ( -1:Int |-> C:ProtoCfgR3 ) ( -3:Int |-> PCAT:JCatalog )
               ( -4:Int |-> .Set ) .Map
            => ( -1:Int |-> C:ProtoCfgR3 ) ( -3:Int |-> PCAT:JCatalog )
               ( -4:Int |-> .Set ) .Map </jlineage>
    <jnext> N:Int => N:Int </jnext>
    <jhead> H:Bytes => H:Bytes </jhead>
    <jlinhead> LH:Bytes => LH:Bytes </jlinhead>
    <janchor> A:Bytes => A:Bytes </janchor>
    <jrefuse> _:JRefuse => jrefusedGate() </jrefuse>
    <jvalid> V:Bool => V:Bool </jvalid>
    [label(MC-GATE-REFUSE-WITNESS-EMPTYPOOL)]

  // ===========================================================================
  // §MC3. THE NEGATIVE CONTROL (the refusal must not over-apply)
  // ===========================================================================

  claim // MC-NEG-REFUSE-ON-MINT: NEGATIVE CONTROL — MUST FAIL.  With the
        // mint rules LIVE (the pools present, the guard unpinned), the
        // "refusal, nothing else moves" destination is FALSE on the mint
        // branch (the gate pool moves; the diagnostic stays jrefuseNoneJ).
        // If this PROVED, the refusal over-applied onto the mint path —
        // a GATE ALARM (the partition's non-overlap is broken).
    <k> pGateEvalJ(B:JBlockJ, FC:ExecCtx, RG:LinRecG, CERT:AuthzCert,
                   ERC:Bytes, ERP:Bytes) => .K </k>
    <jstate> S:Map => S:Map </jstate>
    <jlineage> ( -1:Int |-> C:ProtoCfgR3 )
               ( -3:Int |-> PCAT:JCatalog )
               ( -2:Int |-> PS:Set )
               ( -4:Int |-> SetItem(E:JExecReceipt) ES:Set )
               L2:Map
            => ( -1:Int |-> C:ProtoCfgR3 )
               ( -3:Int |-> PCAT:JCatalog )
               ( -2:Int |-> PS:Set )
               ( -4:Int |-> SetItem(E:JExecReceipt) ES:Set )
               L2:Map </jlineage>
    <jnext> N:Int => N:Int </jnext>
    <jhead> H:Bytes => H:Bytes </jhead>
    <jlinhead> LH:Bytes => LH:Bytes </jlinhead>
    <janchor> A:Bytes => A:Bytes </janchor>
    <jrefuse> _:JRefuse => jrefusedGate() </jrefuse>
    <jvalid> V:Bool => V:Bool </jvalid>
    [label(MC-NEG-REFUSE-ON-MINT)]

  // ---------------------------------------------------------------------------
  // THE CONCRETE WRONG-SLOT COVERAGE PAIR (the decidable B4 witness): the
  // block's slot is pinned to 7 while the machine's slot counter is pinned
  // to 5 — the mint guard's jbSlotOf(B) ==Int N conjunct is DECIDABLY
  // FALSE, so over M3 the [owise] refusal is the ONLY live rule (the claim
  // PROVES: the command is consumed, the diagnostic written, nothing else
  // moves), and over M2 (mc_old_proofs.k) NO rule matches and the
  // configuration is STUCK — the claim FAILS with the stuck-configuration
  // residual (the 1L B4 class, concretely witnessed).  The rest of the
  // block's fields are inert placeholders (the guard dies on the slot
  // conjunct before any hash-class atom is reached).
  // ---------------------------------------------------------------------------

  claim // MC-GATE-REFUSE-WRONGSLOT: over M3, the concretely-refused mint
        // (slot 7 vs counter 5) takes the EXPLICIT refusal: the command is
        // consumed and ONLY the diagnostic is written.  EXPECTED: PROVED.
    <k> pGateEvalJ(jBlockJ( b"\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00"
                          , b"\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00"
                          , b"\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00"
                          , b"\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00"
                          , b"\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00"
                          , b"\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00"
                          , b"\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00"
                          , b"\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00"
                          , b"\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00"
                          , b"\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00"
                          , 1 , 7 )
                 , FC:ExecCtx, RG:LinRecG, CERT:AuthzCert,
                   ERC:Bytes, ERP:Bytes) => .K </k>
    <jstate> S:Map => S:Map </jstate>
    <jlineage> ( -1:Int |-> C:ProtoCfgR3 )
               ( -3:Int |-> PCAT:JCatalog )
               ( -2:Int |-> PS:Set )
               ( -4:Int |-> SetItem(E:JExecReceipt) ES:Set )
               L2:Map
            => ( -1:Int |-> C:ProtoCfgR3 )
               ( -3:Int |-> PCAT:JCatalog )
               ( -2:Int |-> PS:Set )
               ( -4:Int |-> SetItem(E:JExecReceipt) ES:Set )
               L2:Map </jlineage>
    <jnext> 5 => 5 </jnext>
    <jhead> H:Bytes => H:Bytes </jhead>
    <jlinhead> LH:Bytes => LH:Bytes </jlinhead>
    <janchor> A:Bytes => A:Bytes </janchor>
    <jrefuse> _:JRefuse => jrefusedGate() </jrefuse>
    <jvalid> V:Bool => V:Bool </jvalid>
    [label(MC-GATE-REFUSE-WRONGSLOT)]

endmodule
