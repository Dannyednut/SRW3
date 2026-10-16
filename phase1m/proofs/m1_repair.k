// =============================================================================
// SRW3 PHASE 1M — THE M1 REPAIR LADDER (phase1m/proofs/m1_repair.k)
//
// The Workstream-A K regression ladder for the L-FINDING-1 semantic repair
// (the separately justified prerequisite commit, handoff §0): the M1
// machine (srw3closure-j-m1.k = the FROZEN 1J machine + the ONE repaired
// <jlineage> pattern) must
//   (1) produce the jrefusedSource() diagnostic in the FULLY-PINNED machine
//       (the frozen stuck witness — claim M1-EXEC-DISPATCH-SOURCE),
//   (2) keep the SINGLE-ENTRY continuity (claim M1-EXEC-DISPATCH-SOURCE-
//       SINGLE-ENTRY),
//   (3) move NO committed cell and NO receipt pool on every source-refusal
//       resolution path (claim M1-EXEC-SOURCE-NOCOMMIT),
//   (4) NOT over-apply: an authorized source and a bounds-result shape do
//       not take the source branch (the two negative controls — they MUST
//       FAIL: their failure is the required correct outcome; a proof of
//       either is an over-application ALARM and fails the gate),
//   (5) retain the documented B3 pool-Ceil boundary on the ok-mint path
//       (claim M1-EXEC-OK-MINT-POOL — EXPECTED FAIL, the 1L blocker census
//       B3 class; the Workstream-B target, NOT a repair regression).
//
// Scoring convention (the R3 discipline with EXPECTED outcomes): every
// claim is invoked EXACTLY ONCE per canonical run with its raw exit code
// and retained log; raw results are never relabeled.  Level III only.
// =============================================================================

requires "../semantics/srw3closure-j-m1.k"

module M1-REPAIR
  imports SRW3CLOSURE-J-M1

  claim // M1-EXEC-DISPATCH-SOURCE: THE REPAIR WITNESS.  In the fully-pinned
        // machine ((-1 |-> cfg)(-3 |-> cat) + tail) the unauthorized-source
        // execution CONSUMES the command and writes the jrefusedSource()
        // diagnostic (the frozen machine was STUCK here — the frozen T11
        // transcript and the retained OLD log witness it).  PROVED is the
        // repaired behavior; every other cell is framed.
    <k> jExecDispatch(SRC:Bytes, PG:List, CL:Bytes, VL:Int) => .K </k>
    <jstate> S:Map </jstate>
    <jrefuse> _:JRefuse => jrefusedSource() </jrefuse>
    <jlineage> ( -1:Int |-> C:ProtoCfgR3 ) ( -3:Int |-> PCAT:JCatalog )
               L2:Map
            => ( -1:Int |-> C:ProtoCfgR3 ) ( -3:Int |-> PCAT:JCatalog )
               L2:Map </jlineage>
    <jnext> N:Int </jnext>
    <jhead> H:Bytes </jhead>
    <jlinhead> LH:Bytes </jlinhead>
    <janchor> A:Bytes </janchor>
    requires ExecFragmentJ(S:Map, PG:List) ==K jExecOk(PD:Map, ED:Map, TD:List)
         andBool notBool BytesEq(SRC:Bytes, qcrExecClientDOf(C:ProtoCfgR3))
    [label(M1-EXEC-DISPATCH-SOURCE)]

  claim // M1-EXEC-DISPATCH-SOURCE-SINGLE-ENTRY: CONTINUITY — the single-entry
        // lineage (the only shape the frozen pattern matched) still takes
        // the refusal branch under the repaired rule (REST = .Map).
    <k> jExecDispatch(SRC:Bytes, PG:List, CL:Bytes, VL:Int) => .K </k>
    <jstate> S:Map </jstate>
    <jrefuse> _:JRefuse => jrefusedSource() </jrefuse>
    <jlineage> -1:Int |-> C:ProtoCfgR3
            => -1:Int |-> C:ProtoCfgR3 </jlineage>
    <jnext> N:Int </jnext>
    <jhead> H:Bytes </jhead>
    <jlinhead> LH:Bytes </jlinhead>
    <janchor> A:Bytes </janchor>
    requires ExecFragmentJ(S:Map, PG:List) ==K jExecOk(PD:Map, ED:Map, TD:List)
         andBool notBool BytesEq(SRC:Bytes, qcrExecClientDOf(C:ProtoCfgR3))
    [label(M1-EXEC-DISPATCH-SOURCE-SINGLE-ENTRY)]

  claim // M1-EXEC-SOURCE-NOCOMMIT: NO COMMITTED MOVEMENT on every
        // source-refusal resolution path: the committed state, the lineage
        // (INCLUDING the -4 exec-receipt pool and any committed blocks),
        // the slot counter, both heads, and the anchor are UNCHANGED (the
        // identity destination — the claim covers the diagnostic write,
        // which touches ONLY <jrefuse>).  <jrefuse> is deliberately
        // unconstrained: the diagnostic write is the repaired behavior.
    <k> jExecDispatch(SRC:Bytes, PG:List, CL:Bytes, VL:Int) </k>
    <jstate> S:Map => S:Map </jstate>
    <jlineage> ( -1:Int |-> C:ProtoCfgR3 ) ( -3:Int |-> PCAT:JCatalog )
               L2:Map
            => ( -1:Int |-> C:ProtoCfgR3 ) ( -3:Int |-> PCAT:JCatalog )
               L2:Map </jlineage>
    <jnext> N:Int => N:Int </jnext>
    <jhead> H:Bytes => H:Bytes </jhead>
    <jlinhead> LH:Bytes => LH:Bytes </jlinhead>
    <janchor> A:Bytes => A:Bytes </janchor>
    requires ExecFragmentJ(S:Map, PG:List) ==K jExecOk(PD:Map, ED:Map, TD:List)
         andBool notBool BytesEq(SRC:Bytes, qcrExecClientDOf(C:ProtoCfgR3))
    [label(M1-EXEC-SOURCE-NOCOMMIT)]

  claim // M1-NEG-SOURCE-AUTHORIZED-DIAGNOSTIC: NEGATIVE CONTROL — MUST FAIL.
        // An AUTHORIZED source (the pin equality HOLDS) must NOT take the
        // source-refusal branch: with <jrefuse> pinned to the concrete
        // jrefuseNoneJ, the claim "the diagnostic fires" is unprovable
        // (the mint branch owns the authorized case).  If this PROVES, the
        // repair over-applied — a GATE ALARM.
    <k> jExecDispatch(SRC:Bytes, PG:List, CL:Bytes, VL:Int) => .K </k>
    <jstate> S:Map </jstate>
    <jrefuse> jrefuseNoneJ => jrefusedSource() </jrefuse>
    <jlineage> ( -1:Int |-> C:ProtoCfgR3 ) ( -3:Int |-> PCAT:JCatalog )
               L2:Map
            => ( -1:Int |-> C:ProtoCfgR3 ) ( -3:Int |-> PCAT:JCatalog )
               L2:Map </jlineage>
    <jnext> N:Int </jnext>
    <jhead> H:Bytes </jhead>
    <jlinhead> LH:Bytes </jlinhead>
    <janchor> A:Bytes </janchor>
    requires ExecFragmentJ(S:Map, PG:List) ==K jExecOk(PD:Map, ED:Map, TD:List)
         andBool BytesEq(SRC:Bytes, qcrExecClientDOf(C:ProtoCfgR3))
    [label(M1-NEG-SOURCE-AUTHORIZED-DIAGNOSTIC)]

  claim // M1-NEG-SOURCE-DIAG-BOUNDS: NEGATIVE CONTROL — MUST FAIL.  A
        // bounds-result shape does NOT take the source branch (the dispatch
        // partition: the unsupported/bounds classes resolve by RESULT SHAPE
        // and remain disjoint from the source class).  If this PROVES, the
        // partition is broken — a GATE ALARM.
    <k> jExecDispatch(SRC:Bytes, PG:List, CL:Bytes, VL:Int) => .K </k>
    <jstate> S:Map </jstate>
    <jrefuse> jrefuseNoneJ => jrefusedSource() </jrefuse>
    <jlineage> ( -1:Int |-> C:ProtoCfgR3 ) ( -3:Int |-> PCAT:JCatalog )
               L2:Map
            => ( -1:Int |-> C:ProtoCfgR3 ) ( -3:Int |-> PCAT:JCatalog )
               L2:Map </jlineage>
    <jnext> N:Int </jnext>
    <jhead> H:Bytes </jhead>
    <jlinhead> LH:Bytes </jlinhead>
    <janchor> A:Bytes </janchor>
    requires isExecBoundsJ(ExecFragmentJ(S:Map, PG:List))
         andBool notBool BytesEq(SRC:Bytes, qcrExecClientDOf(C:ProtoCfgR3))
    [label(M1-NEG-SOURCE-DIAG-BOUNDS)]

  claim // M1-EXEC-OK-MINT-POOL: the ok-mint path RETAINS the documented B3
        // pool-Ceil boundary (the 1L blocker census B3 class: building
        // JExecReceiptOf(...) with LinH-computed roots into a SET over
        // symbolic arguments leaves an undischargeable #Ceil(Keccak256raw)
        // on the Haskell backend).  EXPECTED FAIL — this is the
        // Workstream-B target (the M2 total-evaluator redirect), NOT a
        // repair regression.  Retained verbatim from the 1L ladder
        // (L-INV-EXEC-OK-STEP-POOL).
    <k> pExecJ(SRC:Bytes, PG:List, CL:Bytes, VL:Int) => .K </k>
    <jstate> S:Map </jstate>
    <jlineage> ( -1:Int |-> C:ProtoCfgR3 )
               ( -3:Int |-> PCAT:JCatalog )
               ( -4:Int |-> ES:Set ) L4:Map
            => ( -1:Int |-> C:ProtoCfgR3 )
               ( -3:Int |-> PCAT:JCatalog )
               ( -4:Int |-> SetItem(JExecReceiptOf(
                     SRC, PG, CL, VL, S, C, PCAT, A, H, N, LH,
                     jExecOkPostOf(ExecFragmentJ(S, PG)),
                     jExecOkEffOf(ExecFragmentJ(S, PG)),
                     jExecOkTraceOf(ExecFragmentJ(S, PG)))) ES )
               L4:Map </jlineage>
    <jnext> N:Int </jnext>
    <jhead> H:Bytes </jhead>
    <jlinhead> LH:Bytes </jlinhead>
    <janchor> A:Bytes </janchor>
    requires isExecOkJ(ExecFragmentJ(S:Map, PG:List))
         andBool BytesEq(SRC:Bytes, qcrExecClientDOf(C:ProtoCfgR3))
    [label(M1-EXEC-OK-MINT-POOL)]

endmodule
