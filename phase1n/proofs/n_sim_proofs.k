// =============================================================================
// SRW3 PHASE 1N — THE SIM LADDER (n_sim_proofs.k, hs backend)
//                    Concrete M3 -> abstract AM3 simulation, per class.
//
// STRUCTURE (the two-leg construction; the join is audited by the shared
// shape sha256 in phase1n/audit/):
//   Leg B — SIM-<class>: claims over the CONCRETE M4 configuration.  Each
//           claim takes the concrete machine's OWN rule guard as the
//           hypothesis (the bit-witness: the guard's outcome IS the
//           abstract command's bit) and pins the machine's OWN post-state
//           shape in the destination.  Receipt/digest terms are pinned
//           SYNTACTICALLY (matched, never evaluated) — the B5/B5'
//           boundaries are structurally avoided.
//   Leg A — SIM-ALG-<class>: the simulation algebra, as evaluation claims
//           over the SAME shapes: simJ(post-shape) ==K
//           absStructOf(absStepJ(simJ(pre-shape), cmd-class)).  The safe
//           bookkeeping component is deliberately excluded from the
//           algebra (the declared boundary — absStructOf); its agreement
//           is carried by the bit witnesses of Leg B.
// Level III only; no consensus-integration claim.
// =============================================================================

requires "../semantics/abs-machine.k"

module N-SIM-PROOFS
  imports SRW3N-ABS

  // ===========================================================================
  // Leg B — the concrete step shapes (one claim per concrete class)
  // ===========================================================================

  claim // SIM-INIT-ACCEPT: the authenticated initialization produces
        // EXACTLY the pinned post-shape (the pins written, the heads
        // advanced, the genesis state unchanged, the diagnostic
        // unchanged).  The guard is the machine's own (the aOkT witness).
    <k> pInitJ(C:ProtoCfgR3, P:JCatalog) => .K </k>
    <jlineage> .Map
            => ( -1:Int |-> C:ProtoCfgR3 ) ( -3:Int |-> P:JCatalog ) </jlineage>
    <jnext> N:Int => N:Int </jnext>
    <jhead> H:Bytes => ProtoRootR3(C:ProtoCfgR3) </jhead>
    <jlinhead> LH:Bytes => JLinRoot </jlinhead>
    <janchor> A:Bytes </janchor>
    <jstate> .Map </jstate>
    <jrefuse> RF:JRefuse </jrefuse>
    <jvalid> V:Bool </jvalid>
    requires BytesEq(ProtoRootR3(C:ProtoCfgR3), A:Bytes)
         andBool JCatalogWF(P:JCatalog)
         andBool BytesEq(JAppSetRootJ(P:JCatalog), qcrAppSetDOf(C:ProtoCfgR3))
         andBool BytesEq(JGraphRootJ(P:JCatalog), qcrGraphDOf(C:ProtoCfgR3))
         andBool BytesEq(JPolicyRootJ(P:JCatalog), qcrPolicyDOf(C:ProtoCfgR3))
         andBool jcPolicyVOf(P:JCatalog) ==Int qcrPolicyVOf(C:ProtoCfgR3)
         andBool SafeJ(P:JCatalog, .Map)
    [label(SIM-INIT-ACCEPT)]

  claim // SIM-INIT-REFUSE: a refused initialization (root mismatch) is a
        // COMPLETE machine stutter — every structural cell unchanged.
    <k> pInitJ(C:ProtoCfgR3, P:JCatalog) => .K </k>
    <jlineage> L:Map => L:Map </jlineage>
    <jnext> N:Int => N:Int </jnext>
    <jhead> H:Bytes => H:Bytes </jhead>
    <jlinhead> LH:Bytes => LH:Bytes </jlinhead>
    <janchor> A:Bytes </janchor>
    <jstate> S:Map => S:Map </jstate>
    <jrefuse> RF:JRefuse </jrefuse>
    <jvalid> V:Bool </jvalid>
    requires notBool BytesEq(ProtoRootR3(C:ProtoCfgR3), A:Bytes)
    [label(SIM-INIT-REFUSE)]

  claim // SIM-EXEC-MINT: the honest exec class mints EXACTLY one exec
        // receipt into the fresh -4 pool of the just-initialized machine
        // (the CONCRETE fresh-lineage shape — the MD/MC discipline).  The
        // receipt is the machine's own derivation, pinned syntactically.
    <k> jExecDispatch(SRC:Bytes, PG:List, CL:Bytes, VL:Int) => .K </k>
    <jstate> S:Map </jstate>
    <jlineage> ( -1:Int |-> C:ProtoCfgR3 ) ( -3:Int |-> PCAT:JCatalog )
            => ( -1:Int |-> C:ProtoCfgR3 ) ( -3:Int |-> PCAT:JCatalog )
               ( -4:Int |-> SetItem(JExecReceiptOf(
                     SRC:Bytes, PG:List, CL:Bytes, VL:Int, S:Map,
                     C:ProtoCfgR3, PCAT:JCatalog, A:Bytes, H:Bytes, N:Int,
                     LH:Bytes,
                     jExecOkPostOf(ExecFragmentJ(S:Map, PG:List)),
                     jExecOkEffOf(ExecFragmentJ(S:Map, PG:List)),
                     jExecOkTraceOf(ExecFragmentJ(S:Map, PG:List)))) .Set ) </jlineage>
    <jnext> N:Int </jnext>
    <jhead> H:Bytes </jhead>
    <jlinhead> LH:Bytes </jlinhead>
    <janchor> A:Bytes </janchor>
    <jrefuse> RF:JRefuse </jrefuse>
    <jvalid> V:Bool </jvalid>
    requires isExecOkJ(ExecFragmentJ(S:Map, PG:List))
         andBool BytesEq(SRC:Bytes, qcrExecClientDOf(C:ProtoCfgR3))
    [label(SIM-EXEC-MINT)]

  claim // SIM-EXEC-SOURCE: the unauthorized-source class writes ONLY the
        // diagnostic (J-A08; the Workstream-A repaired class).
    <k> pExecJ(SRC:Bytes, PG:List, CL:Bytes, VL:Int) => .K </k>
    <jstate> S:Map </jstate>
    <jlineage> ( -1:Int |-> C:ProtoCfgR3 ) ( -3:Int |-> PCAT:JCatalog )
               ( -4:Int |-> .Set )
            => ( -1:Int |-> C:ProtoCfgR3 ) ( -3:Int |-> PCAT:JCatalog )
               ( -4:Int |-> .Set ) </jlineage>
    <jnext> N:Int </jnext>
    <jhead> H:Bytes </jhead>
    <jlinhead> LH:Bytes </jlinhead>
    <janchor> A:Bytes </janchor>
    <jrefuse> _:JRefuse => jrefusedSource() </jrefuse>
    <jvalid> V:Bool </jvalid>
    requires isExecOkJ(ExecFragmentJ(S:Map, PG:List))
         andBool notBool BytesEq(SRC:Bytes, qcrExecClientDOf(C:ProtoCfgR3))
    [label(SIM-EXEC-SOURCE)]

  claim // SIM-EXEC-REFUSE-UNSUPPORTED: the unsupported-effect class writes
        // ONLY the machine-derived diagnostic.
    <k> pExecJ(SRC:Bytes, PG:List, CL:Bytes, VL:Int) => .K </k>
    <jstate> S:Map </jstate>
    <jlineage> ( -1:Int |-> C:ProtoCfgR3 ) ( -3:Int |-> PCAT:JCatalog )
               ( -4:Int |-> .Set )
            => ( -1:Int |-> C:ProtoCfgR3 ) ( -3:Int |-> PCAT:JCatalog )
               ( -4:Int |-> .Set ) </jlineage>
    <jnext> N:Int </jnext>
    <jhead> H:Bytes </jhead>
    <jlinhead> LH:Bytes </jlinhead>
    <janchor> A:Bytes </janchor>
    <jrefuse> _:JRefuse
           => jrefusedUnsupported(jExecUnsupportedOpOf(ExecFragmentJ(S:Map, PG:List))) </jrefuse>
    <jvalid> V:Bool </jvalid>
    requires isExecUnsupportedJ(ExecFragmentJ(S:Map, PG:List))
    [label(SIM-EXEC-REFUSE-UNSUPPORTED)]

  claim // SIM-EXEC-REFUSE-BOUNDS: the field-bounds class likewise.
    <k> pExecJ(SRC:Bytes, PG:List, CL:Bytes, VL:Int) => .K </k>
    <jstate> S:Map </jstate>
    <jlineage> ( -1:Int |-> C:ProtoCfgR3 ) ( -3:Int |-> PCAT:JCatalog )
               ( -4:Int |-> .Set )
            => ( -1:Int |-> C:ProtoCfgR3 ) ( -3:Int |-> PCAT:JCatalog )
               ( -4:Int |-> .Set ) </jlineage>
    <jnext> N:Int </jnext>
    <jhead> H:Bytes </jhead>
    <jlinhead> LH:Bytes </jlinhead>
    <janchor> A:Bytes </janchor>
    <jrefuse> _:JRefuse
           => jrefusedBounds(jExecBoundsOpOf(ExecFragmentJ(S:Map, PG:List))) </jrefuse>
    <jvalid> V:Bool </jvalid>
    requires isExecBoundsJ(ExecFragmentJ(S:Map, PG:List))
    [label(SIM-EXEC-REFUSE-BOUNDS)]

  claim // SIM-GATE-MINT: the honest gate class mints EXACTLY one gate
        // receipt into the fresh -2 pool (the CONCRETE fresh-lineage
        // shape; the exec pool is the machine's singleton).  The receipt
        // fields are the machine's own (the computed verdict included,
        // pinned syntactically); the guard is the machine's OWN mint
        // guard verbatim (the aOkT witness).
    <k> pGateEvalJ(B:JBlockJ, FC:ExecCtx, RG:LinRecG, CERT:AuthzCert,
                   ERC:Bytes, ERP:Bytes) => .K </k>
    <jnext> N:Int </jnext>
    <jhead> H:Bytes </jhead>
    <jlinhead> LH:Bytes </jlinhead>
    <janchor> A:Bytes </janchor>
    <jlineage> ( -1:Int |-> C:ProtoCfgR3 )
               ( -3:Int |-> PCAT:JCatalog )
               ( -4:Int |-> SetItem(E:JExecReceipt) ES:Set )
            => ( -1:Int |-> C:ProtoCfgR3 )
               ( -3:Int |-> PCAT:JCatalog )
               ( -2:Int |-> SetItem(
                     jGateReceipt( B:JBlockJ, ERC:Bytes, ERP:Bytes
                                 , FC:ExecCtx, RG:LinRecG
                                 , CERT:AuthzCert
                                 , azCtx( FC:ExecCtx
                                        , ProtoAuthorizedSecCtxR3(
                                              C:ProtoCfgR3
                                            , jbParentRootOf(B:JBlockJ) )
                                        , CERT:AuthzCert
                                        , qcrAuthPTOf(C:ProtoCfgR3)
                                        , qcrAuthGuestDOf(C:ProtoCfgR3)
                                        , qcrAuthCfgDOf(C:ProtoCfgR3) )
                                 , E:JExecReceipt
                                 , VerifyLineageG(
                                       RG:LinRecG
                                     , azCtx( FC:ExecCtx
                                            , ProtoAuthorizedSecCtxR3(
                                                  C:ProtoCfgR3
                                                , jbParentRootOf(B:JBlockJ) )
                                            , CERT:AuthzCert
                                            , qcrAuthPTOf(C:ProtoCfgR3)
                                            , qcrAuthGuestDOf(C:ProtoCfgR3)
                                            , qcrAuthCfgDOf(C:ProtoCfgR3) )
                                       , N:Int, LH:Bytes )
                                 , H:Bytes, N:Int, LH:Bytes
                                 , C:ProtoCfgR3
                                 , ProtoRootR3(C:ProtoCfgR3)
                                 , A:Bytes
                                 , JCatalogRootJ(PCAT:JCatalog) ))
                     .Set )
               ( -4:Int |-> SetItem(E:JExecReceipt) ES:Set ) </jlineage>
    <jstate> S:Map </jstate>
    <jrefuse> RF:JRefuse </jrefuse>
    <jvalid> V:Bool </jvalid>
    requires GateInputMatchesBlockJ(FC:ExecCtx, RG:LinRecG, CERT:AuthzCert,
                                    B:JBlockJ)
         andBool GateAuthorityMatchesCfgJ(FC:ExecCtx, C:ProtoCfgR3)
         andBool BytesEq(jbParentCommitOf(B:JBlockJ), H:Bytes)
         andBool jbSlotOf(B:JBlockJ) ==Int N:Int
         andBool ExecReceiptMatchesBlockJ(E:JExecReceipt, B:JBlockJ)
         andBool ExecReceiptMatchesRecordJ(E:JExecReceipt, RG:LinRecG)
         andBool BytesEq(jerHeadOf(E:JExecReceipt), H:Bytes)
         andBool jerSlotOf(E:JExecReceipt) ==Int N:Int
         andBool BytesEq(jerLinHeadOf(E:JExecReceipt), LH:Bytes)
         andBool BytesEq(jerAnchorOf(E:JExecReceipt), A:Bytes)
    [label(SIM-GATE-MINT)]

  claim // SIM-GATE-REFUSE: the [owise] gate refusal writes ONLY the
        // diagnostic (the M3 Workstream-C transition; the command is
        // consumed, every other cell framed).
    <k> pGateEvalJ(B:JBlockJ, FC:ExecCtx, RG:LinRecG, CERT:AuthzCert,
                   ERC:Bytes, ERP:Bytes) => .K </k>
    <jnext> N:Int </jnext>
    <jhead> H:Bytes </jhead>
    <jlinhead> LH:Bytes </jlinhead>
    <janchor> A:Bytes </janchor>
    <jlineage> ( -1:Int |-> C:ProtoCfgR3 ) ( -3:Int |-> PCAT:JCatalog )
               ( -2:Int |-> .Set ) ( -4:Int |-> .Set )
            => ( -1:Int |-> C:ProtoCfgR3 ) ( -3:Int |-> PCAT:JCatalog )
               ( -2:Int |-> .Set ) ( -4:Int |-> .Set ) </jlineage>
    <jstate> S:Map </jstate>
    <jrefuse> _:JRefuse => jrefusedGate() </jrefuse>
    <jvalid> V:Bool </jvalid>
    [label(SIM-GATE-REFUSE)]

  claim // SIM-COMMIT-ACCEPT: the accepted commit consumes exactly one
        // receipt from EACH pool (the CONCRETE single-receipt shapes —
        // the 1M load-bearing discipline), writes the block at the fresh
        // slot, advances the slot counter by exactly one, and moves BOTH
        // heads and the safety state to the machine-derived successors.
        // The guard is the machine's OWN accept guard verbatim (the
        // aOkT/aOkT witness — the computed SafeJ-on-derived-post conjunct
        // included; the hash-class conjuncts as hypotheses).
    <k> pCommitJ(B:JBlockJ, ERC:Bytes, ERP:Bytes, CV:Int) => .K </k>
    <janchor> A:Bytes </janchor>
    <jstate> S:Map => jerPostOf(jgExecOf(R:JGateReceipt)) </jstate>
    <jlineage> ( -1:Int |-> C:ProtoCfgR3 )
               ( -3:Int |-> PCAT:JCatalog )
               ( -2:Int |-> SetItem(R:JGateReceipt) .Set )
               ( -4:Int |-> SetItem(jgExecOf(R:JGateReceipt)) .Set )
            => ( -1:Int |-> C:ProtoCfgR3 )
               ( -3:Int |-> PCAT:JCatalog )
               ( -2:Int |-> .Set )
               ( -4:Int |-> .Set )
               ( .Map[jbSlotOf(B:JBlockJ) <- B:JBlockJ] ) </jlineage>
    <jnext> N:Int => N +Int 1 </jnext>
    <jhead> H:Bytes => JBlockCommitJ(B:JBlockJ, C:ProtoCfgR3) </jhead>
    <jlinhead> LH:Bytes => JRecChildF(jgRGOf(R:JGateReceipt)) </jlinhead>
    <jrefuse> RF:JRefuse </jrefuse>
    <jvalid> V:Bool </jvalid>
    requires N >=Int 0
         andBool jgBlockOf(R:JGateReceipt) ==K B:JBlockJ
         andBool jgErcOf(R:JGateReceipt) ==K ERC:Bytes
         andBool jgErpOf(R:JGateReceipt) ==K ERP:Bytes
         andBool jgHeadOf(R:JGateReceipt) ==K H:Bytes
         andBool jgSlotOf(R:JGateReceipt) ==Int N:Int
         andBool jgLinHeadOf(R:JGateReceipt) ==K LH:Bytes
         andBool CfgEqR3(jgCfgOf(R:JGateReceipt), C:ProtoCfgR3)
         andBool BytesEq(jgAnchorOf(R:JGateReceipt), A:Bytes)
         andBool jgDecisionOf(R:JGateReceipt) ==Int pdecValidJ
         andBool jbDecisionOf(B:JBlockJ) ==Int pdecValidJ
         andBool ExecValidPJ(B:JBlockJ, ERC:Bytes, ERP:Bytes)
         andBool BytesEq(linAzCertDOf(jgRGOf(R:JGateReceipt)),
                         jbEvidenceIdOf(B:JBlockJ))
         andBool GateInputMatchesBlockJ(jgFCOf(R:JGateReceipt),
                                        jgRGOf(R:JGateReceipt),
                                        jgCERTOf(R:JGateReceipt), B:JBlockJ)
         andBool ExecReceiptMatchesBlockJ(jgExecOf(R:JGateReceipt), B:JBlockJ)
         andBool ExecReceiptMatchesRecordJ(jgExecOf(R:JGateReceipt),
                                           jgRGOf(R:JGateReceipt))
         andBool BytesEq(jerHeadOf(jgExecOf(R:JGateReceipt)), H:Bytes)
         andBool jerSlotOf(jgExecOf(R:JGateReceipt)) ==Int N:Int
         andBool BytesEq(jerLinHeadOf(jgExecOf(R:JGateReceipt)), LH:Bytes)
         andBool BytesEq(jerAnchorOf(jgExecOf(R:JGateReceipt)), A:Bytes)
         andBool GateCtxAuthorizedJ(jgACOf(R:JGateReceipt), C:ProtoCfgR3,
                                    jbParentRootOf(B:JBlockJ))
         andBool GateAuthorityMatchesCfgJ(jgFCOf(R:JGateReceipt), C:ProtoCfgR3)
         andBool BytesEq(jbParentCommitOf(B:JBlockJ), H:Bytes)
         andBool jbSlotOf(B:JBlockJ) ==Int N:Int
         andBool CV ==Int qcrPolicyVOf(C:ProtoCfgR3)
         andBool JFootprintRegistered(
                     JFootprintKeysOf(jerTraceOf(jgExecOf(R:JGateReceipt))),
                     jcResourcesOf(PCAT:JCatalog))
         andBool isJClosureOk(
                     AffectedClosureJ(
                         JFootprintKeysOf(jerTraceOf(jgExecOf(R:JGateReceipt))),
                         jcHypersOf(PCAT:JCatalog), JClosureFuelJ))
         andBool SafeJ(PCAT:JCatalog, jerPostOf(jgExecOf(R:JGateReceipt)))
         andBool BytesEq(jgRootOf(R:JGateReceipt), ProtoRootR3(C:ProtoCfgR3))
         andBool BytesEq(jgCatRootOf(R:JGateReceipt),
                         JCatalogRootJ(PCAT:JCatalog))
    [label(SIM-COMMIT-ACCEPT)]

  claim // SIM-COMMIT-REJECT: the [owise] reject is a COMPLETE machine
        // stutter — every structural cell (including the diagnostic and
        // both pools) unchanged; nothing is consumed.
    <k> pCommitJ(B:JBlockJ, ERC:Bytes, ERP:Bytes, CV:Int) => .K </k>
    <janchor> A:Bytes </janchor>
    <jstate> S:Map => S:Map </jstate>
    <jlineage> ( -1:Int |-> C:ProtoCfgR3 ) ( -3:Int |-> PCAT:JCatalog )
               ( -2:Int |-> .Set ) ( -4:Int |-> .Set )
            => ( -1:Int |-> C:ProtoCfgR3 ) ( -3:Int |-> PCAT:JCatalog )
               ( -2:Int |-> .Set ) ( -4:Int |-> .Set ) </jlineage>
    <jnext> N:Int => N:Int </jnext>
    <jhead> H:Bytes => H:Bytes </jhead>
    <jlinhead> LH:Bytes => LH:Bytes </jlinhead>
    <jrefuse> RF:JRefuse </jrefuse>
    <jvalid> V:Bool </jvalid>
    requires notBool jbSlotOf(B:JBlockJ) ==Int N:Int
    [label(SIM-COMMIT-REJECT)]

  claim // SIM-EXEC-SOURCE-DISPATCH: the unauthorized-source dispatch step
        // (the 1M PROVED one-step form): the command reaches the refusal
        // continuation with the lineage framed.  Composed with the
        // machine's refusal step (the diagnostic write), this is the
        // source-class simulation witness at the budget-safe granularity.
    <k> pExecJ(SRC:Bytes, PG:List, CL:Bytes, VL:Int)
     => jExecDispatch(SRC:Bytes, PG:List, CL:Bytes, VL:Int) </k>
    <jlineage> ( -1:Int |-> C:ProtoCfgR3 ) ( -3:Int |-> PCAT:JCatalog ) L2:Map
            => ( -1:Int |-> C:ProtoCfgR3 ) ( -3:Int |-> PCAT:JCatalog ) L2:Map </jlineage>
    requires ExecFragmentJ(S0:Map, PG:List) ==K jExecOk(PD:Map, ED:Map, TD:List)
         andBool notBool BytesEq(SRC:Bytes, qcrExecClientDOf(C:ProtoCfgR3))
    [label(SIM-EXEC-SOURCE-DISPATCH)]

  // ===========================================================================
  // Leg A — the simulation algebra over the SAME shapes (evaluation)
  // ===========================================================================

  claim // SIM-ALG-INIT-ACCEPT
    <k> simJ(true, true, 0, 0, 0, jrefuseNoneJ)
     ==K absStructOf(absStepJ(simJ(false, false, 0, 0, 0, jrefuseNoneJ),
                              aInitJ(aOkT:AOk))) </k>
    <absjshadow> absGenesis:AState </absjshadow>
    [label(SIM-ALG-INIT-ACCEPT)]

  claim // SIM-ALG-INIT-REFUSE
    <k> simJ(false, false, 0, 0, 0, jrefusedGate())
     ==K absStructOf(absStepJ(simJ(false, false, 0, 0, 0, jrefusedGate()),
                              aInitJ(aOkF:AOk))) </k>
    <absjshadow> absGenesis:AState </absjshadow>
    [label(SIM-ALG-INIT-REFUSE)]

  claim // SIM-ALG-EXEC-MINT: the post-projection of the mint shape (the
        // fresh singleton pool) equals the abstract mint step's structural
        // successor — the count arithmetic over the symbolic rest-pool.
    <k> simJ(true, true,
             size(gateReceiptsJOf((-1:Int |-> C0:ProtoCfgR3)
                                  (-3:Int |-> P0:JCatalog)
                                  (-4:Int |-> (SetItem(X0:JExecReceipt) ES0:Set)))),
             size(execReceiptsJOf((-1:Int |-> C0:ProtoCfgR3)
                                  (-3:Int |-> P0:JCatalog)
                                  (-4:Int |-> (SetItem(X0:JExecReceipt) ES0:Set)))),
             N0:Int, jrefuseNoneJ)
     ==K absStructOf(absStepJ(
             simJ(true, true,
                  size(gateReceiptsJOf((-1:Int |-> C0:ProtoCfgR3)
                                       (-3:Int |-> P0:JCatalog))),
                  size(execReceiptsJOf((-1:Int |-> C0:ProtoCfgR3)
                                       (-3:Int |-> P0:JCatalog))),
                  N0:Int, jrefuseNoneJ),
             aExecJ(aOkT:AOk, aSrcAuth:ASrc))) </k>
    <absjshadow> absGenesis:AState </absjshadow>
    [label(SIM-ALG-EXEC-MINT)]

  claim // SIM-ALG-EXEC-SOURCE
    <k> simJ(true, true, 0, 0, N0:Int, jrefusedSource())
     ==K absStructOf(absStepJ(simJ(true, true, 0, 0, N0:Int, jrefuseNoneJ),
                              aExecJ(aOkT:AOk, aSrcOther:ASrc))) </k>
    <absjshadow> absGenesis:AState </absjshadow>
    [label(SIM-ALG-EXEC-SOURCE)]

  claim // SIM-ALG-EXEC-REFUSE
    <k> simJ(true, true, 0, 0, N0:Int, jrefusedBounds(3))
     ==K absStructOf(absStepJ(simJ(true, true, 0, 0, N0:Int, jrefuseNoneJ),
                              aExecJ(aOkF:AOk, aSrcAuth:ASrc))) </k>
    <absjshadow> absGenesis:AState </absjshadow>
    [label(SIM-ALG-EXEC-REFUSE)]

  claim // SIM-ALG-GATE-MINT: the gate mint grows the gate-pool count by
        // exactly one over the symbolic pools.
    <k> simJ(true, true,
             size(gateReceiptsJOf((-1:Int |-> C0:ProtoCfgR3)
                                  (-3:Int |-> P0:JCatalog)
                                  (-2:Int |-> (SetItem(Y0:JGateReceipt) GS0:Set))
                                  (-4:Int |-> (SetItem(X0:JExecReceipt) ES0:Set)))),
             size(execReceiptsJOf((-1:Int |-> C0:ProtoCfgR3)
                                  (-3:Int |-> P0:JCatalog)
                                  (-2:Int |-> (SetItem(Y0:JGateReceipt) GS0:Set))
                                  (-4:Int |-> (SetItem(X0:JExecReceipt) ES0:Set)))),
             N0:Int, jrefuseNoneJ)
     ==K absStructOf(absStepJ(
             simJ(true, true,
                  size(gateReceiptsJOf((-1:Int |-> C0:ProtoCfgR3)
                                       (-3:Int |-> P0:JCatalog)
                                       (-4:Int |-> (SetItem(X0:JExecReceipt) ES0:Set)))),
                  size(execReceiptsJOf((-1:Int |-> C0:ProtoCfgR3)
                                       (-3:Int |-> P0:JCatalog)
                                       (-4:Int |-> (SetItem(X0:JExecReceipt) ES0:Set)))),
                  N0:Int, jrefuseNoneJ),
             aGateJ(aOkT:AOk))) </k>
    <absjshadow> absGenesis:AState </absjshadow>
    [label(SIM-ALG-GATE-MINT)]

  claim // SIM-ALG-GATE-REFUSE
    <k> simJ(true, true, 0, 0, N0:Int, jrefusedGate())
     ==K absStructOf(absStepJ(simJ(true, true, 0, 0, N0:Int, jrefuseNoneJ),
                              aGateJ(aOkF:AOk))) </k>
    <absjshadow> absGenesis:AState </absjshadow>
    [label(SIM-ALG-GATE-REFUSE)]

  claim // SIM-ALG-COMMIT-ACCEPT: the accept consumes exactly one receipt
        // from each pool and advances the slot by exactly one — the count
        // arithmetic over the symbolic rest-pools.
    <k> simJ(true, true,
             size(gateReceiptsJOf((-1:Int |-> C0:ProtoCfgR3)
                                  (-3:Int |-> P0:JCatalog)
                                  (-4:Int |-> (SetItem(X0:JExecReceipt) ES0:Set)))),
             size(execReceiptsJOf((-1:Int |-> C0:ProtoCfgR3)
                                  (-3:Int |-> P0:JCatalog)
                                  (-4:Int |-> (SetItem(X0:JExecReceipt) ES0:Set)))),
             N0:Int +Int 1, jrefuseNoneJ)
     ==K absStructOf(absStepJ(
             simJ(true, true,
                  size(gateReceiptsJOf((-1:Int |-> C0:ProtoCfgR3)
                                       (-3:Int |-> P0:JCatalog)
                                       (-2:Int |-> (SetItem(Y0:JGateReceipt) GS0:Set))
                                       (-4:Int |-> (SetItem(X0:JExecReceipt) ES0:Set)))),
                  size(execReceiptsJOf((-1:Int |-> C0:ProtoCfgR3)
                                       (-3:Int |-> P0:JCatalog)
                                       (-2:Int |-> (SetItem(Y0:JGateReceipt) GS0:Set))
                                       (-4:Int |-> (SetItem(X0:JExecReceipt) ES0:Set)))),
                  N0:Int, jrefuseNoneJ),
             aCommitJ(aOkT:AOk, aOkT:AOk))) </k>
    <absjshadow> absGenesis:AState </absjshadow>
    [label(SIM-ALG-COMMIT-ACCEPT)]

  claim // SIM-ALG-COMMIT-REJECT
    <k> simJ(true, true, 2, 1, N0:Int, jrefuseNoneJ)
     ==K absStructOf(absStepJ(simJ(true, true, 2, 1, N0:Int, jrefuseNoneJ),
                              aCommitJ(aOkT:AOk, aOkF:AOk))) </k>
    <absjshadow> absGenesis:AState </absjshadow>
    [label(SIM-ALG-COMMIT-REJECT)]

  // ===========================================================================
  // The SIM negative controls (MUST FAIL)
  // ===========================================================================

  claim // SIM-NEG-MINT-ON-FORBIDDEN-SOURCE: the mint shape claim presented
        // with the UNAUTHORIZED source — the machine refuses; the mint
        // destination is unreachable.  EXPECTED FAIL.
    <k> pExecJ(SRC:Bytes, PG:List, CL:Bytes, VL:Int) => .K </k>
    <jstate> S:Map </jstate>
    <jlineage> ( -1:Int |-> C:ProtoCfgR3 )
               ( -3:Int |-> PCAT:JCatalog )
               L2:Map
            => ( -1:Int |-> C:ProtoCfgR3 )
               ( -3:Int |-> PCAT:JCatalog )
               ( -4:Int |-> SetItem(JExecReceiptOf(
                     SRC:Bytes, PG:List, CL:Bytes, VL:Int, S:Map,
                     C:ProtoCfgR3, PCAT:JCatalog, A:Bytes, H:Bytes, N:Int,
                     LH:Bytes,
                     jExecOkPostOf(ExecFragmentJ(S:Map, PG:List)),
                     jExecOkEffOf(ExecFragmentJ(S:Map, PG:List)),
                     jExecOkTraceOf(ExecFragmentJ(S:Map, PG:List)))) .Set )
               L2:Map </jlineage>
    <jnext> N:Int </jnext>
    <jhead> H:Bytes </jhead>
    <jlinhead> LH:Bytes </jlinhead>
    <janchor> A:Bytes </janchor>
    <jrefuse> RF:JRefuse </jrefuse>
    <jvalid> V:Bool </jvalid>
    requires notBool ( -4:Int in_keys(L2:Map) )
         andBool isExecOkJ(ExecFragmentJ(S:Map, PG:List))
         andBool notBool BytesEq(SRC:Bytes, qcrExecClientDOf(C:ProtoCfgR3))
    [label(SIM-NEG-MINT-ON-FORBIDDEN-SOURCE)]

  claim // SIM-NEG-COMMIT-ON-STALE-SLOT: the accept shape presented with the
        // STALE slot (the receipt minted for N-1) — the machine rejects;
        // the accept destination is unreachable.  EXPECTED FAIL.
    <k> pCommitJ(B:JBlockJ, ERC:Bytes, ERP:Bytes, CV:Int) => .K </k>
    <janchor> A:Bytes </janchor>
    <jstate> S:Map => jerPostOf(jgExecOf(R:JGateReceipt)) </jstate>
    <jlineage> ( -1:Int |-> C:ProtoCfgR3 )
               ( -3:Int |-> PCAT:JCatalog )
               ( -2:Int |-> SetItem(R:JGateReceipt) RS:Set )
               ( -4:Int |-> SetItem(jgExecOf(R:JGateReceipt)) ES:Set )
               L3:Map
            => ( -1:Int |-> C:ProtoCfgR3 )
               ( -3:Int |-> PCAT:JCatalog )
               ( -2:Int |-> RS:Set )
               ( -4:Int |-> ES:Set )
               ( L3[jbSlotOf(B:JBlockJ) <- B:JBlockJ] ) </jlineage>
    <jnext> N:Int => N +Int 1 </jnext>
    <jhead> H:Bytes => JBlockCommitJ(B:JBlockJ, C:ProtoCfgR3) </jhead>
    <jlinhead> LH:Bytes => JRecChildF(jgRGOf(R:JGateReceipt)) </jlinhead>
    <jrefuse> RF:JRefuse </jrefuse>
    <jvalid> V:Bool </jvalid>
    requires jgSlotOf(R:JGateReceipt) ==Int N:Int -Int 1
         andBool jbSlotOf(B:JBlockJ) ==Int N:Int
    [label(SIM-NEG-COMMIT-ON-STALE-SLOT)]

endmodule
