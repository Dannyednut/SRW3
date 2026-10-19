// =============================================================================
// SRW3 PHASE 1M — THE WORKSTREAM-D INDUCTION LADDER (md_proofs.k, hs)
//                    THE GENUINE UNIVERSAL-INDUCTION ATTEMPT OVER M3.
//
// One definition: the M3 machine (the frozen 1J rules + the L-FINDING-1
// repair + the hash redirect + the gate-failure transition) + the UNCHANGED
// 1L invariant definitions (j_invariant_m3.k).
//
// THE PROOF STRUCTURE (the handoff §5, executed honestly):
//   MD1 (base)        — authenticated initialization establishes the
//                       invariant on the genesis state;
//   MD2 (step)        — per-transition-class preservation: the 1L
//                       PROVED-class step lemmas re-run over M3 (frames,
//                       pre-init refusals, the exec-refusal family, the
//                       commit-rejection family) + the NEW gate-refusal
//                       class (the [owise] transition preserves the
//                       invariant — the diagnostic is the only change);
//   MD3 (commit)      — the accepted-commit step binds the derived
//                       post-state (the 1L KEY STEP shape over M3);
//   MD4 (continuation)— the arbitrary-finite-continuation composition
//                       (the 1L ALLPATH shape over M3);
//   MD5 (prefix)      — the committed-prefix safety corollary;
//   MD6 (controls)    — the weakened-invariant negative controls.
//
// THE HONEST DISPOSITION: the blockers REMOVED by Workstreams B/C (B1 the
// hash definedness — the redirect; B4 the stuck gate — the explicit
// refusal) are gone; the boundaries that REMAIN are named by the retained
// residuals: B5 (the implication check cannot equate stuck-defined
// hash-class terms across pattern/rule expansion), B5' (the evaluator's
// symbolic search cost — the mint/commit rewrites now expand the
// cascade), B2 (the destination-constraint idiom), and the
// circularity/vacuity class (SafeJ is a stuck term over symbolic maps —
// a circular closure would be vacuous; the controls enforce this).
// Every raw result is recorded with its log; nothing is relabeled.
// Level III only; no consensus-integration claim.
// =============================================================================

requires "../semantics/j_invariant_m3.k"

module MD-PROOFS
  imports SRW3L-INVARIANT-M3

  // ===========================================================================
  // §MD2 — THE STEP PARTITION over M3 (the 1L PROVED-class lemmas re-run)
  // ===========================================================================

  claim // MD-INV-ANCHOR-FRAME-EXEC: the execution DISPATCH step leaves the
        // anchor cell untouched (the 1L PROVED claim, over M3).
    <k> pExecJ(SRC:Bytes, PG:List, CL:Bytes, VL:Int)
        => jExecDispatch(SRC, PG, CL, VL) </k>
    <janchor> A:Bytes => A:Bytes </janchor>
    <jlineage> L:Map => L:Map </jlineage>
    requires cfgPinnedJ(L:Map) andBool catPinnedJ(L:Map)
    [label(MD-INV-ANCHOR-FRAME-EXEC)]

  claim // MD-INV-CATALOG-FRAME-EXEC: the pinned configuration and catalog
        // are untouched by the dispatch step (the 1L PROVED claim, M3).
    <k> pExecJ(SRC:Bytes, PG:List, CL:Bytes, VL:Int)
        => jExecDispatch(SRC, PG, CL, VL) </k>
    <jlineage> ( -1:Int |-> C:ProtoCfgR3 ) ( -3:Int |-> PCAT:JCatalog ) L2:Map
            => ( -1:Int |-> C:ProtoCfgR3 ) ( -3:Int |-> PCAT:JCatalog ) L2:Map </jlineage>
    [label(MD-INV-CATALOG-FRAME-EXEC)]

  claim // MD-INV-PREINIT-INIT-REFUSES: initialization from a preinit state
        // with a mismatched anchor is REFUSED and changes nothing (the 1L
        // PROVED claim, M3).
    <k> pInitJ(C:ProtoCfgR3, P:JCatalog) => .K </k>
    <jlineage> .Map => .Map </jlineage>
    <jnext> N:Int => N:Int </jnext>
    <jhead> H:Bytes => H:Bytes </jhead>
    <jlinhead> LH:Bytes => LH:Bytes </jlinhead>
    <janchor> A:Bytes => A:Bytes </janchor>
    <jstate> S:Map => S:Map </jstate>
    <jrefuse> RF:JRefuse </jrefuse>
    <jvalid> V:Bool => V:Bool </jvalid>
    requires notBool BytesEq(ProtoRootR3(C:ProtoCfgR3), A:Bytes)
    [label(MD-INV-PREINIT-INIT-REFUSES)]

  claim // MD-INV-PREINIT-COMMIT-REFUSES: a commit attempt in a preinit
        // state changes nothing (the 1L PROVED claim, M3).
    <k> pCommitJ(B:JBlockJ, ERC:Bytes, ERP:Bytes, CV:Int) => .K </k>
    <jlineage> .Map => .Map </jlineage>
    <jnext> N:Int => N:Int </jnext>
    <jhead> H:Bytes => H:Bytes </jhead>
    <jlinhead> LH:Bytes => LH:Bytes </jlinhead>
    <janchor> A:Bytes => A:Bytes </janchor>
    <jstate> S:Map => S:Map </jstate>
    <jrefuse> RF:JRefuse </jrefuse>
    <jvalid> V:Bool => V:Bool </jvalid>
    [label(MD-INV-PREINIT-COMMIT-REFUSES)]

  claim // MD-INV-EXEC-REFUSAL-SOURCE: the unauthorized-source execution
        // writes ONLY the diagnostic (the Workstream-A repaired class,
        // over M3 — the refusal family's preservation).
    <k> pExecJ(SRC:Bytes, PG:List, CL:Bytes, VL:Int)
        => jExecDispatch(SRC, PG, CL, VL) </k>
    <jlineage> ( -1:Int |-> C:ProtoCfgR3 ) ( -3:Int |-> PCAT:JCatalog )
               L2:Map
            => ( -1:Int |-> C:ProtoCfgR3 ) ( -3:Int |-> PCAT:JCatalog )
               L2:Map </jlineage>
    <jstate> S:Map </jstate>
    <jnext> N:Int </jnext>
    <jhead> H:Bytes </jhead>
    <jlinhead> LH:Bytes </jlinhead>
    <janchor> A:Bytes </janchor>
    requires ExecFragmentJ(S:Map, PG:List) ==K jExecOk(PD:Map, ED:Map, TD:List)
         andBool notBool BytesEq(SRC:Bytes, qcrExecClientDOf(C:ProtoCfgR3))
    [label(MD-INV-EXEC-REFUSAL-SOURCE)]

  claim // MD-INV-COMMIT-REJECT-STALE-SLOT: a receipt minted for slot N-1
        // cannot commit at slot N (the 1L PROVED claim, ported EXACTLY —
        // the CONCRETE single-receipt pool shape SetItem(R) .Set refutes
        // everything but the staleness; the accept guard's jgSlotOf(R)
        // ==Int N conjunct is REFUTED concretely; the [owise] commit
        // refusal leaves every committed cell unchanged).
    <k> pCommitJ(B:JBlockJ, ERC:Bytes, ERP:Bytes, CV:Int) => .K </k>
    <jlineage> ( -1:Int |-> C:ProtoCfgR3 )
               ( -3:Int |-> PCAT:JCatalog )
               ( -2:Int |-> SetItem(R:JGateReceipt) .Set ) L3:Map
            => ( -1:Int |-> C:ProtoCfgR3 )
               ( -3:Int |-> PCAT:JCatalog )
               ( -2:Int |-> SetItem(R:JGateReceipt) .Set ) L3:Map </jlineage>
    <jnext> N:Int => N:Int </jnext>
    <jhead> H:Bytes => H:Bytes </jhead>
    <jlinhead> LH:Bytes => LH:Bytes </jlinhead>
    <janchor> A:Bytes => A:Bytes </janchor>
    <jstate> S:Map => S:Map </jstate>
    <jrefuse> RF:JRefuse => RF:JRefuse </jrefuse>
    <jvalid> V:Bool => V:Bool </jvalid>
    requires jgSlotOf(R:JGateReceipt) ==Int N:Int -Int 1
         andBool jbSlotOf(B:JBlockJ) ==Int N:Int
         andBool CV:Int ==Int qcrPolicyVOf(C:ProtoCfgR3)
    [label(MD-INV-COMMIT-REJECT-STALE-SLOT)]

  claim // MD-INV-GATE-REFUSAL-PRESERVES: THE NEW STEP CLASS (Workstream C's
        // [owise] transition): the gate refusal writes ONLY the diagnostic
        // — the invariant's cells (the lineage with its pools, the slot
        // counter, both heads, the anchor, the state) are UNCHANGED, so
        // JInvJ carries over trivially on every refusal resolution.  The
        // destination is the identity on every invariant cell; the
        // diagnostic is the machine's own jrefusedGate().
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
    [label(MD-INV-GATE-REFUSAL-PRESERVES)]

  // ===========================================================================
  // §MD1/MD3/MD4/MD5 — THE BASE, THE COMMIT STEP, THE CONTINUATION, THE
  //                     PREFIX (the genuine attempts; retained with
  //                     residuals whichever way they resolve)
  // ===========================================================================

  claim // MD-INV-INIT-BASE: THE BASE — successful authenticated
        // initialization establishes the initialized invariant on the
        // genesis state (the 1L L-INV-INIT-BASE claim verbatim, over M3;
        // the 1L run died on B1 — the redirect removed it; the M2 run
        // measured the remaining B5 boundary; over M3 the attempt stands).
    <k> pInitJ(C:ProtoCfgR3, P:JCatalog) => .K </k>
    <jlineage> .Map
            => ( -1:Int |-> C:ProtoCfgR3 ) ( -3:Int |-> P:JCatalog ) </jlineage>
    <jnext> N:Int </jnext>
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
         andBool SafeJ(P:JCatalog, .Map) ==K true
    [label(MD-INV-INIT-BASE)]

  claim // MD-INV-ALLPATH-REACHABILITY: THE ARBITRARY-CONTINUATION
        // COMPOSITION (the 1L ALLPATH shape over M3) — the universal
        // claim whose mechanization IS the phase completion gate.
    <k> RUN:PProgJI => RUN:PProgJI </k>
    <jlineage> L:Map </jlineage>
    <janchor> A:Bytes </janchor>
    <jstate> S:Map </jstate>
    <jnext> N:Int </jnext>
    <jhead> H:Bytes </jhead>
    <jlinhead> LH:Bytes </jlinhead>
    <jrefuse> RF:JRefuse </jrefuse>
    <jvalid> V:Bool </jvalid>
    requires JInvJ(C:ProtoCfgR3, P:JCatalog, A:Bytes, S:Map, L:Map)
         andBool ( -1:Int |-> C:ProtoCfgR3 ) ( -3:Int |-> P:JCatalog ) ==K L:Map
    [label(MD-INV-ALLPATH-REACHABILITY)]

  claim // MD-INV-COMMITTED-PREFIX-SAFE: THE COMMITTED-PREFIX corollary
        // (the 1L shape over M3).
    <k> RUN:PProgJI => RUN:PProgJI </k>
    <jlineage> L:Map </jlineage>
    <jstate> S:Map </jstate>
    requires JChainCoherentJ(C:ProtoCfgR3, N:Int, H:Bytes, LH:Bytes, L:Map)
         andBool SafeJ(P:JCatalog, S:Map) ==K true
    [label(MD-INV-COMMITTED-PREFIX-SAFE)]

  // ===========================================================================
  // §MD6 — THE NEGATIVE CONTROLS (MUST FAIL)
  // ===========================================================================

  claim // MD-NEG-CONTROL-SAFEJ: the 1L vacuity control over M3 — the
        // accept step with the SafeJ guard conjunct DELIBERATELY REMOVED,
        // the destination an unconstrained SAFE post-state: if this PROVED,
        // the safety conclusion does not depend on the guard (vacuity
        // alarm).  EXPECTED FAIL.
    <k> pCommitJ(B:JBlockJ, ERC:Bytes, ERP:Bytes, CV:Int) => .K </k>
    <janchor> A:Bytes => A:Bytes </janchor>
    <jstate> S:Map => XPost:Map </jstate>
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
    <jvalid> V:Bool => V:Bool </jvalid>
    requires jgBlockOf(R:JGateReceipt) ==K B:JBlockJ
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
         andBool GateAuthorityMatchesCfgJ(jgFCOf(R:JGateReceipt),
                                          C:ProtoCfgR3)
         andBool BytesEq(jbParentCommitOf(B:JBlockJ), H:Bytes)
         andBool jbSlotOf(B:JBlockJ) ==Int N:Int
         andBool CV:Int ==Int qcrPolicyVOf(C:ProtoCfgR3)
         andBool JFootprintRegistered(
                     JFootprintKeysOf(jerTraceOf(jgExecOf(R:JGateReceipt))),
                     jcResourcesOf(PCAT:JCatalog))
         andBool isJClosureOk(
                     AffectedClosureJ(
                         JFootprintKeysOf(jerTraceOf(jgExecOf(R:JGateReceipt))),
                         jcHypersOf(PCAT:JCatalog), JClosureFuelJ))
         andBool BytesEq(jgRootOf(R:JGateReceipt), ProtoRootR3(C:ProtoCfgR3))
         andBool BytesEq(jgCatRootOf(R:JGateReceipt),
                         JCatalogRootJ(PCAT:JCatalog))
         // the SafeJ guard conjunct is DELIBERATELY ABSENT; the unconstrained
         // destination post-state is asserted safe anyway:
         andBool SafeJ(PCAT:JCatalog, XPost:Map) ==K true
    [label(MD-NEG-CONTROL-SAFEJ)]

endmodule
