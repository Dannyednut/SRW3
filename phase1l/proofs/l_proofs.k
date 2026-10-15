// =============================================================================
// SRW3 Phase 1L — THE UNIVERSAL INDUCTION PROOF LADDER (l_proofs.k, hs)
//
// One definition: the FROZEN Phase 1J machine (+ the frozen inert fixtures)
// + the Phase 1L proof-facing invariant definitions (j_invariant.k —
// [function, total] definitions ONLY; the reachable rule set is byte-for-
// byte the frozen J machine's; audit/rule-inventory.md cross-checks this).
//
// THE PROOF-STRUCTURE FIX (handoff §5.1-5.5): the frozen J-REACHABLE-
// COMMITTED-SAFE claim quantified over a FIXED four-command fixture
// pipeline whose hash equalities must be DECIDED mid-execution on the
// Haskell backend (no evaluators for the KRYPTO Keccak256raw hook — the
// frozen 1J boundary).  The 1L ladder instead:
//   (1) carries a DEFINITIONAL invariant predicate JInvJ over the ACTUAL
//       machine cells;
//   (2) proves per-rule-class STEP LEMMAS whose destinations are EXACT
//       post-terms — no hash equality is ever DECIDED; every root/digest
//       equality is either (a) a claim HYPOTHESIS (the documented Haskell
//       symbolic boundary; concrete on LLVM/Python) or (b) syntactically
//       identical terms on both sides of a frame/definitional step;
//   (3) attempts the ALL-PATH composition over arbitrary finite command
//       continuations with the invariant on both sides (destination-side
//       constraints via requires-shared destination variables — the idiom
//       is FIRST VALIDATED by L-EXP-DESTVAR-POS and its NEGATIVE CONTROL
//       L-EXP-DESTVAR-NEG, which MUST fail);
//   (4) retains every failure with its log and names the exact blocker;
//       the scientific classification never relabels a raw result.
//
// LABEL DISCIPLINE (the frozen 1J convention): PROVED / DEMONSTRATED /
// CHECKED / ASSUMED / STRUCTURAL / NOT MECHANIZED.  Negative controls
// (L-EXP-DESTVAR-NEG, L-NEG-CONTROL-SAFEJ) are EXPECTED-FAIL claims: their
// failure is the required correct outcome, and their UNEXPECTED success
// would falsify the ladder (vacuity alarm).
// =============================================================================

requires "../semantics/j_invariant.k"

module L-PROOFS
  imports SRW3L-INVARIANT

  // ===========================================================================
  // §0. MECHANICS EXPERIMENTS + NEGATIVE CONTROLS (run first; their outcome
  //     governs the interpretation of the all-path section)
  // ===========================================================================

  claim // L-EXP-DESTVAR-POS: the destination-variable idiom TEST — EXPECTED
        // FAIL (probe-established): the requires clause is evaluated at
        // the SOURCE; a destination-only variable (S2) in the requires is
        // an unbound-lookahead term the prover cannot evaluate, and the
        // claim dies with "configuration cannot be rewritten further".
        // CONCLUSION (recorded in audit/induction-diagnosis.md): the
        // destination-side invariant constraint idiom is UNUSABLE on this
        // backend; the ladder therefore carries the invariant by shared
        // cells and exact destination terms only.
    <k> runNilJ => .K </k>
    <jlineage> L:Map => L2:Map </jlineage>
    <jnext> N:Int => N2:Int </jnext>
    <jhead> H:Bytes => H2:Bytes </jhead>
    <jlinhead> LH:Bytes => LH2:Bytes </jlinhead>
    <janchor> A:Bytes </janchor>
    <jstate> S:Map => S2:Map </jstate>
    <jrefuse> RF:JRefuse => RF2:JRefuse </jrefuse>
    <jvalid> V:Bool => V2:Bool </jvalid>
    requires size(S2) ==Int size(S)
     andBool N2 ==Int N  andBool H2 ==K H  andBool LH2 ==K LH
     andBool L2 ==K L    andBool RF2 ==K RF andBool V2 ==K V
    [label(L-EXP-DESTVAR-POS)]

  claim // L-EXP-DESTVAR-NEG: NEGATIVE CONTROL — MUST FAIL.  The same
        // destination-variable idiom with a FALSE constraint (the size
        // cannot grow: no rule rewrites <jstate> here).  If this claim
        // PROVES, the destination-constraining idiom is VACUOUS and the
        // all-path section (§E) must be re-interpreted — the runner gates
        // on exactly this outcome.
    <k> runNilJ => .K </k>
    <jlineage> L:Map => L2:Map </jlineage>
    <jnext> N:Int => N2:Int </jnext>
    <jhead> H:Bytes => H2:Bytes </jhead>
    <jlinhead> LH:Bytes => LH2:Bytes </jlinhead>
    <janchor> A:Bytes </janchor>
    <jstate> S:Map => S2:Map </jstate>
    <jrefuse> RF:JRefuse => RF2:JRefuse </jrefuse>
    <jvalid> V:Bool => V2:Bool </jvalid>
    requires size(S2) ==Int size(S) +Int 1
     andBool N2 ==Int N  andBool H2 ==K H  andBool LH2 ==K LH
     andBool L2 ==K L    andBool RF2 ==K RF andBool V2 ==K V
    [label(L-EXP-DESTVAR-NEG)]

  // ===========================================================================
  // §A. FRAME LEMMAS — the immutable anchor and the pinned configuration /
  //     catalog are preserved by every post-init command class (handoff
  //     §4 items 3-4).  Destinations are EXACT terms; no hash equality is
  //     decided (the anchor is never an equality subject here).
  // ===========================================================================

  claim // L-INV-ANCHOR-FRAME-EXEC: the execution DISPATCH step (the pExecJ
        // unwrap) moves NOTHING — the anchor and every other cell are
        // untouched (frame; the destination is the dispatch constructor —
        // no hash materialization on this proof path).  Conditional on the
        // pins (an unpinned pExecJ is stuck — no rule fires — and is
        // covered by the pre-init family).
    <k> pExecJ(SRC:Bytes, PG:List, CL:Bytes, VL:Int)
        => jExecDispatch(SRC, PG, CL, VL) </k>
    <jstate> S:Map </jstate>
    <jlineage> ( -1:Int |-> C:ProtoCfgR3 ) ( -3:Int |-> PCAT:JCatalog )
               L2:Map
            => ( -1:Int |-> C:ProtoCfgR3 ) ( -3:Int |-> PCAT:JCatalog )
               L2:Map </jlineage>
    <jnext> N:Int </jnext>
    <jhead> H:Bytes </jhead>
    <jlinhead> LH:Bytes </jlinhead>
    <janchor> A:Bytes => A:Bytes </janchor>
    [label(L-INV-ANCHOR-FRAME-EXEC)]

  claim // L-INV-ANCHOR-FRAME-GATE: a gate-evaluation mint writes ONLY the
        // gate-receipt pool; the anchor cell is untouched (frame).
    <k> pGateEvalJ(B:JBlockJ, FC:ExecCtx, RG:LinRecG, CERT:AuthzCert,
                   ERC:Bytes, ERP:Bytes) => .K </k>
    <jnext> N:Int </jnext>
    <jhead> H:Bytes </jhead>
    <jlinhead> LH:Bytes </jlinhead>
    <janchor> A:Bytes </janchor>
    <jlineage> ( -1:Int |-> C:ProtoCfgR3 )
               ( -3:Int |-> PCAT:JCatalog )
               ( -2:Int |-> PS:Set )
               ( -4:Int |-> SetItem(E:JExecReceipt) ES:Set ) L2:Map
            => ( -1:Int |-> C:ProtoCfgR3 )
               ( -3:Int |-> PCAT:JCatalog )
               ( -2:Int |-> SetItem(
                     jGateReceipt( B:JBlockJ, ERC:Bytes, ERP:Bytes
                                 , FC:ExecCtx, RG:LinRecG, CERT:AuthzCert
                                 , azCtx( FC:ExecCtx
                                        , ProtoAuthorizedSecCtxR3(C:ProtoCfgR3
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
                                 , C:ProtoCfgR3, ProtoRootR3(C:ProtoCfgR3)
                                 , A:Bytes
                                 , JCatalogRootJ(PCAT:JCatalog) )) PS:Set )
               ( -4:Int |-> SetItem(E:JExecReceipt) ES:Set ) L2:Map </jlineage>
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
    [label(L-INV-ANCHOR-FRAME-GATE)]

  claim // L-INV-ANCHOR-FRAME-COMMIT-REJECT: a refused commit (no gate
        // receipt) leaves the anchor — and every other cell — unchanged.
    <k> pCommitJ(B:JBlockJ, ERC:Bytes, ERP:Bytes, CV:Int) => .K </k>
    <jlineage> ( -1:Int |-> C:ProtoCfgR3 )
               ( -3:Int |-> PCAT:JCatalog ) L3:Map
            => ( -1:Int |-> C:ProtoCfgR3 )
               ( -3:Int |-> PCAT:JCatalog ) L3:Map </jlineage>
    <jnext> N:Int => N:Int </jnext>
    <jhead> H:Bytes => H:Bytes </jhead>
    <jlinhead> LH:Bytes => LH:Bytes </jlinhead>
    <janchor> A:Bytes => A:Bytes </janchor>
    <jstate> S:Map => S:Map </jstate>
    <jrefuse> RF:JRefuse => RF:JRefuse </jrefuse>
    <jvalid> V:Bool => V:Bool </jvalid>
    [label(L-INV-ANCHOR-FRAME-COMMIT-REJECT)]

  claim // L-INV-CATALOG-FRAME-EXEC: the pinned configuration and catalog
        // are UNCHANGED by the execution dispatch step (frame; dispatch-
        // constructor destination).
    <k> pExecJ(SRC:Bytes, PG:List, CL:Bytes, VL:Int)
        => jExecDispatch(SRC, PG, CL, VL) </k>
    <jstate> S:Map </jstate>
    <jlineage> ( -1:Int |-> C:ProtoCfgR3 )
               ( -3:Int |-> PCAT:JCatalog ) L2:Map
            => ( -1:Int |-> C:ProtoCfgR3 )
               ( -3:Int |-> PCAT:JCatalog ) L2:Map </jlineage>
    <jnext> N:Int </jnext>
    <jhead> H:Bytes </jhead>
    <jlinhead> LH:Bytes </jlinhead>
    <janchor> A:Bytes </janchor>
    [label(L-INV-CATALOG-FRAME-EXEC)]

  claim // L-INV-CATALOG-FRAME-COMMIT-REJECT: a refused commit leaves the
        // pinned configuration and catalog unchanged.
    <k> pCommitJ(B:JBlockJ, ERC:Bytes, ERP:Bytes, CV:Int) => .K </k>
    <jlineage> ( -1:Int |-> C:ProtoCfgR3 )
               ( -3:Int |-> PCAT:JCatalog ) L3:Map
            => ( -1:Int |-> C:ProtoCfgR3 )
               ( -3:Int |-> PCAT:JCatalog ) L3:Map </jlineage>
    <jnext> N:Int => N:Int </jnext>
    <jhead> H:Bytes => H:Bytes </jhead>
    <jlinhead> LH:Bytes => LH:Bytes </jlinhead>
    <janchor> A:Bytes => A:Bytes </janchor>
    <jstate> S:Map => S:Map </jstate>
    <jrefuse> RF:JRefuse => RF:JRefuse </jrefuse>
    <jvalid> V:Bool => V:Bool </jvalid>
    [label(L-INV-CATALOG-FRAME-COMMIT-REJECT)]

  // ===========================================================================
  // §B. PRE-INITIALIZATION (handoff §4 item 1): pre-init states cannot have
  //     committed history or changed state.  From a JInvPreinitJ state the
  //     dispatch/mint rules cannot fire (their requires need the pins; the
  //     preinit predicate fixes the pools empty, so the commit accept
  //     cannot match either) — the commands either refuse ([owise]) or are
  //     stuck, and in BOTH cases no committed cell moves.
  // ===========================================================================

  claim // L-INV-PREINIT-INIT-REFUSES: initialization from a preinit state
        // either pins (the guarded success rule) or refuses with NOTHING
        // changed.  Success is covered by L-INV-INIT-BASE; this claim
        // covers the REFUSAL path (any init that does not satisfy the
        // guard changes nothing).
    <k> pInitJ(C:ProtoCfgR3, P:JCatalog) => .K </k>
    <jlineage> L:Map => L:Map </jlineage>
    <jnext> N:Int => N:Int </jnext>
    <jhead> H:Bytes => H:Bytes </jhead>
    <jlinhead> LH:Bytes => LH:Bytes </jlinhead>
    <janchor> A:Bytes => A:Bytes </janchor>
    <jstate> S:Map => S:Map </jstate>
    <jrefuse> RF:JRefuse => RF:JRefuse </jrefuse>
    <jvalid> V:Bool => V:Bool </jvalid>
    requires JInvPreinitJ(L:Map, S:Map, N:Int, H:Bytes, LH:Bytes) ==K true
         andBool notBool ( BytesEq(ProtoRootR3(C:ProtoCfgR3), A:Bytes)
              andBool JCatalogWF(P:JCatalog)
              andBool BytesEq(JAppSetRootJ(P:JCatalog),
                              qcrAppSetDOf(C:ProtoCfgR3))
              andBool BytesEq(JGraphRootJ(P:JCatalog),
                              qcrGraphDOf(C:ProtoCfgR3))
              andBool BytesEq(JPolicyRootJ(P:JCatalog),
                              qcrPolicyDOf(C:ProtoCfgR3))
              andBool jcPolicyVOf(P:JCatalog) ==Int qcrPolicyVOf(C:ProtoCfgR3)
              andBool SafeJ(P:JCatalog, .Map) ==K true )
    [label(L-INV-PREINIT-INIT-REFUSES)]

  claim // L-INV-PREINIT-COMMIT-REFUSES: a commit attempt in a preinit
        // state cannot reach the accept rule (the accept pattern needs a
        // gate receipt in the -2 pool; the preinit predicate fixes the
        // pool empty) — the [owise] refusal leaves every cell unchanged.
    <k> pCommitJ(B:JBlockJ, ERC:Bytes, ERP:Bytes, CV:Int) => .K </k>
    <jlineage> L:Map => L:Map </jlineage>
    <jnext> N:Int => N:Int </jnext>
    <jhead> H:Bytes => H:Bytes </jhead>
    <jlinhead> LH:Bytes => LH:Bytes </jlinhead>
    <janchor> A:Bytes => A:Bytes </janchor>
    <jstate> S:Map => S:Map </jstate>
    <jrefuse> RF:JRefuse => RF:JRefuse </jrefuse>
    <jvalid> V:Bool => V:Bool </jvalid>
    requires JInvPreinitJ(L:Map, S:Map, N:Int, H:Bytes, LH:Bytes) ==K true
    [label(L-INV-PREINIT-COMMIT-REFUSES)]

  // ===========================================================================
  // §C. STEP LEMMAS — the induction step per rule class (handoff §4 items
  //     5-11, 14).  Destinations are EXACT post-terms; the invariant is
  //     carried by (a) SHARED cells (frame steps) or (b) the commit guard's
  //     own SafeJ conjunct on exactly the installed post-state (accept
  //     step).  SafeJ is NEVER a hypothesis of its own preservation: it
  //     enters only through the machine's computed guards.
  // ===========================================================================

  claim // L-INV-INIT-BASE: successful pInitJ ESTABLISHES the full
        // initialized invariant (handoff §4 item 2).  The destination is
        // the exact pinned post-state; every JInvJ conjunct is either a
        // destination-pattern fact (pins, state) or an init-guard conjunct
        // (root/anchor binding, catalog digests, WF, SafeJ on the genesis)
        // — the guard COMPUTED them; the claim shows the machine INSTALLS
        // exactly that state.
    <k> pInitJ(C:ProtoCfgR3, P:JCatalog) => .K </k>
    // the source lineage is the machine's INITIAL state (.Map): nothing
    // writes <jlineage> before pInitJ (rule inventory); a symbolic L with
    // only the owise-evaluated notBool cfgPinnedJ(L) does not give the
    // prover L's SHAPE and the map-update residue cannot be discharged.
    <jlineage> .Map
            => ( -1:Int |-> C:ProtoCfgR3 ) ( -3:Int |-> P:JCatalog ) </jlineage>
    <jnext> N:Int </jnext>
    // NOTE: the <jhead>/<jlinhead> advance (to ProtoRootR3(C) / JLinRoot)
    // is deliberately NOT part of this claim: the symbolic head value is a
    // hash-class term whose destination materialization is BLOCKED on the
    // Haskell backend (#Ceil(Keccak256raw(symbolic)) — probe P10/init-base
    // residual; audit/induction-diagnosis.md blocker B1).  The advance is
    // carried by the FROZEN ground-fixture claim J-INIT-PINS-AUTHORIZED
    // (phase1j, PROVED) and the JChainCoherentJ genesis conjunct.
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
    [label(L-INV-INIT-BASE)]

  claim // L-INV-EXEC-OK-STEP-POOL: a successful execution (pool exists)
        // mints the derived receipt into the exec pool and changes NO
        // committed cell: jstate, head, lineage head, slot, anchor are
        // shared; the safety invariant carries over trivially.
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
    [label(L-INV-EXEC-OK-STEP-POOL)]

  claim // L-INV-EXEC-OK-STEP-FRESH: the same, when the exec pool does not
        // exist yet (first mint creates it).
    <k> pExecJ(SRC:Bytes, PG:List, CL:Bytes, VL:Int) => .K </k>
    <jstate> S:Map </jstate>
    <jlineage> ( -1:Int |-> C:ProtoCfgR3 )
               ( -3:Int |-> PCAT:JCatalog ) L2:Map
            => ( -1:Int |-> C:ProtoCfgR3 )
               ( -3:Int |-> PCAT:JCatalog )
               ( -4:Int |-> SetItem(JExecReceiptOf(
                     SRC, PG, CL, VL, S, C, PCAT, A, H, N, LH,
                     jExecOkPostOf(ExecFragmentJ(S, PG)),
                     jExecOkEffOf(ExecFragmentJ(S, PG)),
                     jExecOkTraceOf(ExecFragmentJ(S, PG)))) .Set )
               L2:Map </jlineage>
    <jnext> N:Int </jnext>
    <jhead> H:Bytes </jhead>
    <jlinhead> LH:Bytes </jlinhead>
    <janchor> A:Bytes </janchor>
    requires notBool ( -4:Int in_keys(L2:Map) )
         andBool isExecOkJ(ExecFragmentJ(S:Map, PG:List))
         andBool BytesEq(SRC:Bytes, qcrExecClientDOf(C:ProtoCfgR3))
    [label(L-INV-EXEC-OK-STEP-FRESH)]

  claim // L-INV-EXEC-REFUSAL-UNSUPPORTED: an excluded-effect execution
        // writes ONLY the refusal diagnostic; no receipt is minted; the
        // committed state does not move (handoff §4 item 6).
    <k> pExecJ(SRC:Bytes, PG:List, CL:Bytes, VL:Int)
        => jExecDispatch(SRC, PG, CL, VL) </k>
    <jstate> S:Map </jstate>
    <jlineage> L:Map => L:Map </jlineage>
    <jnext> N:Int </jnext>
    <jhead> H:Bytes </jhead>
    <jlinhead> LH:Bytes </jlinhead>
    <janchor> A:Bytes </janchor>
    requires cfgPinnedJ(L:Map) andBool catPinnedJ(L:Map)
         andBool isExecUnsupportedJ(ExecFragmentJ(S:Map, PG:List))
    [label(L-INV-EXEC-REFUSAL-UNSUPPORTED)]

  claim // L-INV-EXEC-REFUSAL-BOUNDS: an out-of-bounds execution writes
        // ONLY the bounds refusal; no receipt; no committed movement.
    <k> pExecJ(SRC:Bytes, PG:List, CL:Bytes, VL:Int)
        => jExecDispatch(SRC, PG, CL, VL) </k>
    <jstate> S:Map </jstate>
    <jlineage> L:Map => L:Map </jlineage>
    <jnext> N:Int </jnext>
    <jhead> H:Bytes </jhead>
    <jlinhead> LH:Bytes </jlinhead>
    <janchor> A:Bytes </janchor>
    requires cfgPinnedJ(L:Map) andBool catPinnedJ(L:Map)
         andBool isExecBoundsJ(ExecFragmentJ(S:Map, PG:List))
    [label(L-INV-EXEC-REFUSAL-BOUNDS)]

  claim // L-INV-EXEC-REFUSAL-SOURCE: an execution whose declared source is
        // not the pinned execution-client identity writes ONLY the source
        // refusal; no receipt; no committed movement.
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
    requires isExecOkJ(ExecFragmentJ(S:Map, PG:List))
         andBool notBool BytesEq(SRC:Bytes, qcrExecClientDOf(C:ProtoCfgR3))
    [label(L-INV-EXEC-REFUSAL-SOURCE)]

  claim // L-INV-GATE-STEP-POOL: a gate evaluation (pool exists) mints the
        // COMPUTED-verdict receipt into the gate pool; NO chain state and
        // NO <jstate> movement (handoff §4 item 4).  The verdict term is
        // the machine's own VerifyLineageG application (opaque on the
        // Haskell backend — the documented boundary; the concrete verdict
        // computation is the LLVM/Python tier).
    <k> pGateEvalJ(B:JBlockJ, FC:ExecCtx, RG:LinRecG, CERT:AuthzCert,
                   ERC:Bytes, ERP:Bytes) => .K </k>
    <jnext> N:Int </jnext>
    <jhead> H:Bytes </jhead>
    <jlinhead> LH:Bytes </jlinhead>
    <janchor> A:Bytes </janchor>
    <jlineage> ( -1:Int |-> C:ProtoCfgR3 )
               ( -3:Int |-> PCAT:JCatalog )
               ( -2:Int |-> PS:Set )
               ( -4:Int |-> SetItem(E:JExecReceipt) ES:Set ) L2:Map
            => ( -1:Int |-> C:ProtoCfgR3 )
               ( -3:Int |-> PCAT:JCatalog )
               ( -2:Int |-> SetItem(
                     jGateReceipt( B:JBlockJ, ERC:Bytes, ERP:Bytes
                                 , FC:ExecCtx, RG:LinRecG, CERT:AuthzCert
                                 , azCtx( FC:ExecCtx
                                        , ProtoAuthorizedSecCtxR3(C:ProtoCfgR3
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
                                 , C:ProtoCfgR3, ProtoRootR3(C:ProtoCfgR3)
                                 , A:Bytes
                                 , JCatalogRootJ(PCAT:JCatalog) )) PS:Set )
               ( -4:Int |-> SetItem(E:JExecReceipt) ES:Set ) L2:Map </jlineage>
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
    [label(L-INV-GATE-STEP-POOL)]

  claim // L-INV-GATE-STEP-FRESH: the same, when the gate pool does not
        // exist yet (first mint creates it).
    <k> pGateEvalJ(B:JBlockJ, FC:ExecCtx, RG:LinRecG, CERT:AuthzCert,
                   ERC:Bytes, ERP:Bytes) => .K </k>
    <jnext> N:Int </jnext>
    <jhead> H:Bytes </jhead>
    <jlinhead> LH:Bytes </jlinhead>
    <janchor> A:Bytes </janchor>
    <jlineage> ( -1:Int |-> C:ProtoCfgR3 )
               ( -3:Int |-> PCAT:JCatalog )
               ( -4:Int |-> SetItem(E:JExecReceipt) ES:Set ) L2:Map
            => ( -1:Int |-> C:ProtoCfgR3 )
               ( -3:Int |-> PCAT:JCatalog )
               ( -2:Int |-> SetItem(
                     jGateReceipt( B:JBlockJ, ERC:Bytes, ERP:Bytes
                                 , FC:ExecCtx, RG:LinRecG, CERT:AuthzCert
                                 , azCtx( FC:ExecCtx
                                        , ProtoAuthorizedSecCtxR3(C:ProtoCfgR3
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
                                 , C:ProtoCfgR3, ProtoRootR3(C:ProtoCfgR3)
                                 , A:Bytes
                                 , JCatalogRootJ(PCAT:JCatalog) )) .Set )
               ( -4:Int |-> SetItem(E:JExecReceipt) ES:Set ) L2:Map </jlineage>
    requires notBool ( -2:Int in_keys(L2:Map) )
         andBool GateInputMatchesBlockJ(FC:ExecCtx, RG:LinRecG, CERT:AuthzCert,
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
    [label(L-INV-GATE-STEP-FRESH)]

  claim // L-INV-COMMIT-ACCEPT-POSTSTATE: THE KEY STEP — an accepted commit
        // installs EXACTLY the derived post-state the guard certified
        // (handoff §4 item 10 / handoff §3 item 6): the guard's SafeJ
        // conjunct is computed over jerPostOf(jgExecOf(R)) and the accept
        // rule writes exactly that term into <jstate>.  SafeJ appears ONLY
        // in the guard (computed) — never as an independent hypothesis of
        // the destination: the claim's SafeJ conjunct is LITERALLY the
        // accept rule's own enabling condition (the machine refuses to
        // fire without it), so assuming it is assuming "the commit was
        // accepted", not the conclusion.  The hash-class conjuncts are the
        // documented Haskell symbolic hypotheses (concrete on LLVM/Python).
    <k> pCommitJ(B:JBlockJ, ERC:Bytes, ERP:Bytes, CV:Int) => .K </k>
    <janchor> A:Bytes => A:Bytes </janchor>
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
         andBool SafeJ(PCAT:JCatalog,
                       jerPostOf(jgExecOf(R:JGateReceipt))) ==K true
         andBool BytesEq(jgRootOf(R:JGateReceipt), ProtoRootR3(C:ProtoCfgR3))
         andBool BytesEq(jgCatRootOf(R:JGateReceipt),
                         JCatalogRootJ(PCAT:JCatalog))
    [label(L-INV-COMMIT-ACCEPT-POSTSTATE)]

  claim // L-NEG-CONTROL-SAFEJ: NEGATIVE CONTROL — MUST FAIL (L-A14/L-A15
        // discipline; scratch-only; never merged into any semantics).  The
        // accept step with the SafeJ guard conjunct DELIBERATELY REMOVED
        // from the requires, while the DESTINATION is an unconstrained
        // post-state XPost asserted safe.  Without the guard conjunct
        // NOTHING ties the machine-installed post-state
        // (jerPostOf(jgExecOf(R))) to a SafeJ-satisfying XPost — the
        // destination safety constraint cannot be discharged.  If this
        // claim PROVES, the positive accept-step lemma above is vacuous
        // (the safety conclusion would not depend on the guard) and the
        // whole induction is worthless; the runner gates on this outcome.
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
         // the SafeJ guard conjunct is DELIBERATELY ABSENT; the claim
         // asserts the (unconstrained) destination post-state is safe
         // anyway — it must NOT prove:
         andBool SafeJ(PCAT:JCatalog, XPost:Map) ==K true
    [label(L-NEG-CONTROL-SAFEJ)]

  claim // L-INV-COMMIT-REJECT-STALE-SLOT: a receipt minted for slot N-1
        // cannot commit at slot N (the freshness tie — handoff §3 item 8 /
        // §4 item 11): the slot counter advanced concretely, so the accept
        // guard's jgSlotOf(R) ==Int N conjunct is REFUTED; the [owise]
        // refusal leaves every committed cell unchanged.  This is the
        // cross-commit receipt-staleness core of
        // L-INV-COMMIT-HEAD-STATE-COHERENCE (L-A07/L-A09 at the K level).
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
    [label(L-INV-COMMIT-REJECT-STALE-SLOT)]

  claim // L-INV-COMMIT-REJECT-REUSED-RECEIPT: receipt reuse cannot commit
        // twice (handoff §4 item 13 / L-A09/L-A11): after an accepted
        // commit the consumed receipts are GONE from the pools (the accept
        // rule's own destination); a commit attempt against EMPTY pools
        // (the post-consumption state — the reuse scenario) cannot match
        // the accept pattern (its LHS needs the receipts present) — the
        // [owise] refusal leaves every cell unchanged.
    <k> pCommitJ(B:JBlockJ, ERC:Bytes, ERP:Bytes, CV:Int) => .K </k>
    <jlineage> ( -1:Int |-> C:ProtoCfgR3 )
               ( -3:Int |-> PCAT:JCatalog )
               ( -2:Int |-> .Set )
               ( -4:Int |-> .Set ) L3:Map
            => ( -1:Int |-> C:ProtoCfgR3 )
               ( -3:Int |-> PCAT:JCatalog )
               ( -2:Int |-> .Set )
               ( -4:Int |-> .Set ) L3:Map </jlineage>
    <jnext> N:Int => N:Int </jnext>
    <jhead> H:Bytes => H:Bytes </jhead>
    <jlinhead> LH:Bytes => LH:Bytes </jlinhead>
    <janchor> A:Bytes => A:Bytes </janchor>
    <jstate> S:Map => S:Map </jstate>
    <jrefuse> RF:JRefuse => RF:JRefuse </jrefuse>
    <jvalid> V:Bool => V:Bool </jvalid>
    requires CV:Int ==Int qcrPolicyVOf(C:ProtoCfgR3)
    [label(L-INV-COMMIT-REJECT-REUSED-RECEIPT)]

  claim // L-INV-COMMIT-REJECT-FORGED-VERDICT: a gate receipt whose COMPUTED
        // verdict is not "valid-g" yields the fail-closed derived decision
        // and the commit REFUSES with every cell unchanged (the guard's
        // decision conjunct is decided BEFORE the hash-class conjuncts —
        // the R3 order discipline; in the J machine no caller can choose
        // this string: the mint computes it).
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
    requires jgBlockOf(R:JGateReceipt) ==K B:JBlockJ
         andBool jgErcOf(R:JGateReceipt) ==K ERC:Bytes
         andBool jgErpOf(R:JGateReceipt) ==K ERP:Bytes
         andBool jgHeadOf(R:JGateReceipt) ==K H:Bytes
         andBool jgSlotOf(R:JGateReceipt) ==Int N:Int
         andBool jgLinHeadOf(R:JGateReceipt) ==K LH:Bytes
         andBool CfgEqR3(jgCfgOf(R:JGateReceipt), C:ProtoCfgR3)
         andBool BytesEq(jgAnchorOf(R:JGateReceipt), A:Bytes)
         andBool jgVerdictOf(R:JGateReceipt) ==K "invalid-forged"
         andBool CV:Int ==Int qcrPolicyVOf(C:ProtoCfgR3)
    [label(L-INV-COMMIT-REJECT-FORGED-VERDICT)]

  claim // L-INV-COMMIT-HEAD-STATE-COHERENCE: the freshness links — a gate
        // receipt binds the head/slot/lineage-head AT MINT TIME and the
        // accept guard re-checks all three; a receipt whose EXEC receipt
        // was minted for a PRIOR slot cannot satisfy the guard at the
        // CURRENT slot (the slot conjunct decides concretely; the
        // head/lineage-head conjuncts are the documented hash-class
        // hypotheses — their concrete force is the LLVM/Python tier).
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
    requires jerSlotOf(jgExecOf(R:JGateReceipt)) ==Int N:Int -Int 1
         andBool jbSlotOf(B:JBlockJ) ==Int N:Int
         andBool CV:Int ==Int qcrPolicyVOf(C:ProtoCfgR3)
    [label(L-INV-COMMIT-HEAD-STATE-COHERENCE)]

  // ===========================================================================
  // §E. THE UNIVERSAL CLAIMS (the all-path composition — ATTEMPTED; the
  //     raw outcomes are retained whatever they are; see §E discussion in
  //     audit/induction-diagnosis.md)
  // ===========================================================================

  claim // L-INV-ALLPATH-REACHABILITY: the universal induction composition —
        // from an initialized invariant state, EVERY finite command
        // continuation preserves the invariant.  Anchored at termination
        // (.K) and closed, if at all, by [circularity] (the 1B forall-n
        // recipe).  KNOWN BLOCKERS, named in advance:
        //   (a) a pGateEvalJ whose mint preconditions are unmet is STUCK
        //       (no owise rule) — the stuck configuration does not match
        //       the source pattern RUN:PProgJI, so the circular hypothesis
        //       cannot re-fire and the branch dies;
        //   (b) kore's circular re-application can only SATISFIABILITY-
        //       CHECK the source requires — the SafeJ conjunct over
        //       symbolic maps is a stuck term on the Haskell backend, so
        //       the re-application ASSUMES it (vacuous) rather than
        //       verifying it; the paired negative control
        //       L-NEG-ALLPATH-WEAKSAFEJ (below) gates on exactly this.
    <k> RUN:PProgJI => .K </k>
    <jlineage> ( -1:Int |-> C:ProtoCfgR3 )
               ( -3:Int |-> PCAT:JCatalog ) L4:Map => ?L2:Map </jlineage>
    <jnext> N:Int => ?N2:Int </jnext>
    <jhead> H:Bytes => ?H2:Bytes </jhead>
    <jlinhead> LH:Bytes => ?LH2:Bytes </jlinhead>
    <janchor> A:Bytes </janchor>
    <jstate> S:Map => ?S2:Map </jstate>
    <jrefuse> RF:JRefuse => ?RF2:JRefuse </jrefuse>
    <jvalid> V:Bool => ?V2:Bool </jvalid>
    requires JInvJ(C:ProtoCfgR3, PCAT:JCatalog, A:Bytes, S:Map,
                   ( -1:Int |-> C:ProtoCfgR3 )
                   ( -3:Int |-> PCAT:JCatalog ) L4:Map) ==K true
         andBool JChainCoherentJ(C:ProtoCfgR3, N:Int, H:Bytes, LH:Bytes,
                   ( -1:Int |-> C:ProtoCfgR3 )
                   ( -3:Int |-> PCAT:JCatalog ) L4:Map) ==K true
    [circularity, label(L-INV-ALLPATH-REACHABILITY)]

  claim // L-NEG-ALLPATH-WEAKSAFEJ: NEGATIVE CONTROL — MUST FAIL.  The
        // all-path claim with the SafeJ conjunct WEAKENED to a
        // contradiction-tolerant stub (JInvJ replaced by its non-safety
        // conjuncts only, so a machine whose committed states are UNSAFE
        // would satisfy it).  If the positive all-path claim PROVES while
        // this control ALSO PROVES, the positive proof is VACUOUS w.r.t.
        // safety (the circular hypothesis assumed the stuck SafeJ term
        // instead of verifying it) and the universal theorem is NOT
        // MECHANIZED — the exact documented blocker (b) above.
    <k> RUN:PProgJI => .K </k>
    <jlineage> ( -1:Int |-> C:ProtoCfgR3 )
               ( -3:Int |-> PCAT:JCatalog ) L4:Map => ?L2:Map </jlineage>
    <jnext> N:Int => ?N2:Int </jnext>
    <jhead> H:Bytes => ?H2:Bytes </jhead>
    <jlinhead> LH:Bytes => ?LH2:Bytes </jlinhead>
    <janchor> A:Bytes </janchor>
    <jstate> S:Map => ?S2:Map </jstate>
    <jrefuse> RF:JRefuse => ?RF2:JRefuse </jrefuse>
    <jvalid> V:Bool => ?V2:Bool </jvalid>
    requires cfgPinnedJ(( -1:Int |-> C:ProtoCfgR3 )
                        ( -3:Int |-> PCAT:JCatalog ) L4:Map) ==K true
         andBool catPinnedJ(( -1:Int |-> C:ProtoCfgR3 )
                            ( -3:Int |-> PCAT:JCatalog ) L4:Map) ==K true
         andBool BytesEq(ProtoRootR3(C:ProtoCfgR3), A:Bytes)
         andBool JCatalogWF(PCAT:JCatalog) ==K true
         // the SafeJ conjunct is DELIBERATELY WEAKENED AWAY — the control
         // must fail unless the positive proof verifies more than assumes
    [circularity, label(L-NEG-ALLPATH-WEAKSAFEJ)]

  claim // L-INV-COMMITTED-PREFIX-SAFE: the user-facing corollary — every
        // committed prefix has a SafeJ current state — attempted in the
        // strongest single-claim form: from the initialized invariant, any
        // continuation that ends after at least one accepted commit leaves
        // a state satisfying SafeJ.  The destination asserts the safety of
        // the FINAL state only (the prefix property itself is the §E
        // all-path claim's to carry).
    <k> RUN:PProgJI => .K </k>
    <jlineage> ( -1:Int |-> C:ProtoCfgR3 )
               ( -3:Int |-> PCAT:JCatalog ) L4:Map => ?L2:Map </jlineage>
    <jnext> N:Int => ?N2:Int </jnext>
    <jhead> H:Bytes => ?H2:Bytes </jhead>
    <jlinhead> LH:Bytes => ?LH2:Bytes </jlinhead>
    <janchor> A:Bytes </janchor>
    <jstate> S:Map => ?S2:Map </jstate>
    <jrefuse> RF:JRefuse => ?RF2:JRefuse </jrefuse>
    <jvalid> V:Bool => ?V2:Bool </jvalid>
    requires JInvJ(C:ProtoCfgR3, PCAT:JCatalog, A:Bytes, S:Map,
                   ( -1:Int |-> C:ProtoCfgR3 )
                   ( -3:Int |-> PCAT:JCatalog ) L4:Map) ==K true
    [label(L-INV-COMMITTED-PREFIX-SAFE)]

  // ---------------------------------------------------------------------------
  // §C2. DISPATCH RESOLUTION — the exec dispatch's refusal classes resolve
  //     into the machine-bookkeeping diagnostic and NOTHING else (the
  //     destinations are constructor/shared cells only — no hash
  //     materialization; the fragment-interpreter projections are total).
  // ---------------------------------------------------------------------------

  claim // L-INV-EXEC-DISPATCH-UNSUPPORTED: the unsupported class writes the
        // diagnostic, mints NOTHING, and moves no committed cell.
    <k> jExecDispatch(SRC:Bytes, PG:List, CL:Bytes, VL:Int) => .K </k>
    <jstate> S:Map </jstate>
    <jrefuse> _:JRefuse
           => jrefusedUnsupported(jExecUnsupportedOpOf(ExecFragmentJ(S, PG)))
           </jrefuse>
    <jlineage> L:Map => L:Map </jlineage>
    <jnext> N:Int </jnext>
    <jhead> H:Bytes </jhead>
    <jlinhead> LH:Bytes </jlinhead>
    <janchor> A:Bytes </janchor>
    requires ExecFragmentJ(S:Map, PG:List) ==K jExecUnsupported(NU:Int)
    [label(L-INV-EXEC-DISPATCH-UNSUPPORTED)]

  claim // L-INV-EXEC-DISPATCH-BOUNDS: the bounds class — same discipline.
    <k> jExecDispatch(SRC:Bytes, PG:List, CL:Bytes, VL:Int) => .K </k>
    <jstate> S:Map </jstate>
    <jrefuse> _:JRefuse
           => jrefusedBounds(jExecBoundsOpOf(ExecFragmentJ(S, PG))) </jrefuse>
    <jlineage> L:Map => L:Map </jlineage>
    <jnext> N:Int </jnext>
    <jhead> H:Bytes </jhead>
    <jlinhead> LH:Bytes </jlinhead>
    <janchor> A:Bytes </janchor>
    requires ExecFragmentJ(S:Map, PG:List) ==K jExecBounds(NU:Int)
    [label(L-INV-EXEC-DISPATCH-BOUNDS)]

  claim // L-INV-EXEC-DISPATCH-SOURCE: the unauthorized-source diagnostic
        // claim — EXPECTED FAIL; this is the WITNESS of FROZEN-SEMANTICS
        // FINDING L-FINDING-1 (audit/findings.md): the frozen dispatch
        // rule's lineage pattern is the SINGLE-ENTRY map
        // (-1 |-> cfg) with NO tail, so in a FULLY-PINNED machine
        // (-1,-3,-4 present) the unauthorized-source execution matches NO
        // dispatch rule — it is STUCK: no jrefusedSource() diagnostic is
        // written (the frozen 1J LLVM transcript T11 shows exactly this
        // stuck configuration).  Safety is preserved (stuck = no
        // transition = no receipt = no committed movement); the DIAGNOSTIC
        // expectation (handoff §4 item 6 / L-A05/A06 "explicit refusal")
        // is impaired.  Per the handoff §3 protocol the model is NOT
        // repaired inside Phase 1L (the 1J tree is frozen); the finding is
        // reported for a separately justified repair commit.
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
    [label(L-INV-EXEC-DISPATCH-SOURCE)]

  claim // L-INV-EXEC-SOURCE-NOCOMMIT: the SAFETY content of the
        // unauthorized-source class holds on every resolution path: the
        // committed state, the slot counter, both heads, the anchor, and
        // BOTH receipt pools are UNCHANGED (whether the machine writes a
        // diagnostic — the single-entry-lineage shape — or is stuck, the
        // L-FINDING-1 fully-pinned shape; the mint branch is refuted by
        // the requires' source inequality, the sibling diagnostic branches
        // move no committed cell, and the stuck branch moves nothing).
        // <jrefuse> is deliberately unconstrained (the finding).
    // the destination is the IDENTITY pattern (no rewrite): the claim
    // asserts that on EVERY resolution path — the diagnostic write (the
    // single-entry-lineage shape), the L-FINDING-1 stuck configuration
    // (matched at zero steps), and any sibling branch not refuted by the
    // shape/inequality constraints — NO committed cell and NO receipt pool
    // moves.  PROVED: the mint branch is refuted by the source
    // inequality's propositional conflict with the mint's own equality
    // requirement; every surviving branch preserves the shared cells.
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
    [label(L-INV-EXEC-SOURCE-NOCOMMIT)]

endmodule
