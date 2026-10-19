// =============================================================================
// SRW3 PHASE 1M — THE 1L SAFETY INVARIANT, M2 PORT (PROOF-FACING)
//                    (phase1m/semantics/j_invariant_m3.k)
//
// This module is phase1l/semantics/j_invariant.k (sha256
// 89412f010d2e4030c303a74bca5da6eb43ec468b6c47d930bdc54dfa92286370) with EXACTLY THREE disclosed edits and NOTHING else:
//   1. this header;
//   2. the machine import is the M3 gate-refusal machine (M2 + the ONE [owise] gate-failure transition)
//      (../semantics/srw3closure-j-m3.k — make_m2.py) replacing the frozen
//      Phase 1J machine; the JInv/JInvPreinitJ/JChainCoherentJ definitions
//      and every hash-using builder body are UNCHANGED — with the M2
//      redirect every hash application they materialize flows through the
//      TOTAL evaluator Keccak256T (the B1 definedness boundary removed);
//   3. the module rename SRW3L-INVARIANT -> SRW3L-INVARIANT-M3.
// The reachable rule set is the M2 machine's = the frozen 1J machine's
// rules + the ONE L-FINDING-1 repair (the map tail; make_m1.py) + the ONE
// hash-redirect equation (make_m2.py; no transition rule — the redirect is
// a function EQUATION on the hash primitive).
// =============================================================================

// =============================================================================
// SRW3 Phase 1L — THE J SAFETY INVARIANT, PROOF-FACING DEFINITIONS
//                    (phase1l/semantics/j_invariant.k)
//
// ADDITIVE ONLY: this module imports the FROZEN Phase 1J machine
// (srw3closure-j.k) UNCHANGED and adds PROOF-FACING [function, total]
// DEFINITIONS ONLY — no new command, no new transition rule, no rewrite of
// any frozen rule.  The invariant predicate is defined over the ACTUAL J
// machine cells (the handoff §3 requirement: an invariant predicate over
// actual J machine configurations, not a parallel transition system).
//
// THE INVARIANT (handoff §3, branches composed into one predicate):
//   JInvJ(C, P, A, S, L) — the INITIALIZED safety invariant:
//     - the configuration and catalog are pinned (reserved keys -1/-3);
//     - the pinned root matches the immutable anchor (relative to the
//       explicit hash/anchor premise — on the Haskell backend the root
//       equalities are SYMBOLIC HYPOTHESES; on LLVM/Python they are
//       concrete Keccak-256 checks — L-INV-HASH-BOUNDARY);
//     - the catalog well-formedness and its app/resource/hyperedge/policy
//       digest bindings hold (the R3-rooted config fields 2/3/4/5);
//     - SafeJ(P, S) holds — every registered local, hyperedge, and global
//       invariant evaluates true on the current abstract state.
//   JInvPreinitJ(L, S, N, H, LH) — the PRE-INITIALIZATION invariant:
//     nothing pinned, no committed history, the defined genesis state,
//     no receipts (the pools are only minted when pinned — rule inventory,
//     audit/rule-inventory.md).
//   JChainCoherentJ(C, N, H, LH, L) — the COMMITTED-PREFIX branch:
//     the append/link relation established by the unique accepted-commit
//     rule: the next slot is free, and for an empty chain the heads are the
//     defined genesis values.  (The slot-key/value enumeration is stated
//     over the machine's own map discipline; the freshness ties that rule
//     out cross-commit receipts are mechanized as the stale-receipt reject
//     claims L-INV-COMMIT-HEAD-STATE-COHERENCE-*.)
//
// SafeJ APPEARS IN THE INVARIANT but is NOT assumed in its own induction
// step: it is ESTABLISHED by the base case (the pInitJ guard computes
// SafeJ on the genesis) and PRESERVED by the proved step lemmas (the
// commit guard computes SafeJ on exactly the derived post-state that is
// written into <jstate>; every other rule leaves <jstate> unchanged).
// =============================================================================

requires "../semantics/srw3closure-j-m3.k"

module SRW3L-INVARIANT-M3
  imports SRW3CLOSURE-J-M3

  // ---------------------------------------------------------------------------
  // §1. The initialized safety invariant (handoff §3 initialized branch +
  //     receipt/control frame).  C = pinned configuration, P = pinned
  //     catalog, A = anchor cell value, S = <jstate>, L = <jlineage>.
  // ---------------------------------------------------------------------------
  syntax Bool ::= JInvJ ( ProtoCfgR3 , JCatalog , Bytes , Map , Map )
                 [function, total]
  rule JInvJ(C:ProtoCfgR3, P:JCatalog, A:Bytes, S:Map, L:Map)
    => cfgPinnedJ(L)                                       // config pinned
       andBool catPinnedJ(L)                               // catalog pinned
       andBool BytesEq(ProtoRootR3(C), A)                  // anchor binding
                                                          // [hash hyp, hs]
       andBool BytesEq(JAppSetRootJ(P), qcrAppSetDOf(C))   // field 4 binding
                                                          // [hash hyp, hs]
       andBool BytesEq(JGraphRootJ(P), qcrGraphDOf(C))     // field 5 binding
                                                          // [hash hyp, hs]
       andBool BytesEq(JPolicyRootJ(P), qcrPolicyDOf(C))   // field 3 binding
                                                          // [hash hyp, hs]
       andBool jcPolicyVOf(P) ==Int qcrPolicyVOf(C)        // field 2 binding
       andBool JCatalogWF(P)                               // well-formedness
       andBool SafeJ(P, S)                                 // THE SAFETY CORE

  // ---------------------------------------------------------------------------
  // §2. The pre-initialization invariant (handoff §3 pre-init branch): no
  //     committed blocks, nothing pinned, the defined genesis state, no
  //     receipts.  The receipts-empty conjuncts are justified by the rule
  //     inventory: the ONLY rules that mint into the -2/-4 pools require
  //     cfgPinnedJ(L) andBool catPinnedJ(L) (audit/rule-inventory.md).
  // ---------------------------------------------------------------------------
  syntax Bool ::= JInvPreinitJ ( Map , Map , Int , Bytes , Bytes )
                 [function, total]
  rule JInvPreinitJ(L:Map, S:Map, N:Int, H:Bytes, LH:Bytes)
    => notBool cfgPinnedJ(L)
       andBool notBool catPinnedJ(L)
       andBool gateReceiptsJOf(L) ==K .Set
       andBool execReceiptsJOf(L) ==K .Set
       andBool S ==K .Map                      // the defined genesis state
       andBool N ==Int 0                       // no committed blocks
       andBool H ==K JGenesisHead              // the defined genesis heads
       andBool LH ==K JLinRoot

  // ---------------------------------------------------------------------------
  // §3. The committed-prefix branch: the append/link relation established by
  //     the unique accepted-commit rule (JChainCoherentJ), stated over the
  //     machine's map discipline.  The slot/free-next conjunct is the
  //     freshness precondition the accept guard itself re-checks; the
  //     empty-chain conjunct is the defined genesis.  The cross-commit
  //     receipt-staleness consequence is mechanized separately as
  //     L-INV-COMMIT-HEAD-STATE-COHERENCE-* (the slot counter advances
  //     concretely, so a receipt minted for slot N cannot satisfy the
  //     freshness guard at slot N+1 — decidable on the Haskell backend).
  // ---------------------------------------------------------------------------
  syntax Bool ::= JChainCoherentJ ( ProtoCfgR3 , Int , Bytes , Bytes , Map )
                 [function, total]
  rule JChainCoherentJ(C:ProtoCfgR3, N:Int, H:Bytes, LH:Bytes, L:Map)
    => notBool ( N in_keys (L:Map) )               // the next slot is free
       andBool ( notBool ( N ==Int 0 )         // empty-chain genesis heads
                 orBool ( H ==K ProtoRootR3(C) // the init-pinned genesis head
                          andBool LH ==K JLinRoot ) )

  // ---------------------------------------------------------------------------
  // §4. The composite invariant used by the ladder: the initialized safety
  //     invariant + the committed-prefix coherence.  (The receipt/control
  //     branch is NOT a conjunct: receipts are machine bookkeeping whose
  //     pools do not alter the safety state — handoff §3; their lifecycle
  //     is mechanized by L-INV-RECEIPT-EXHAUSTIVE and the frame lemmas.)
  // ---------------------------------------------------------------------------
  syntax Bool ::= JInvPlusJ ( ProtoCfgR3 , JCatalog , Bytes , Map , Int ,
                              Bytes , Bytes , Map ) [function, total]
  rule JInvPlusJ(C:ProtoCfgR3, P:JCatalog, A:Bytes, S:Map, N:Int, H:Bytes,
                 LH:Bytes, L:Map)
    => JInvJ(C, P, A, S, L)
       andBool JChainCoherentJ(C, N, H, LH, L)

  // ---------------------------------------------------------------------------
  // §5. PROOF-FACING TOTAL WRAPPERS (the definedness assumption, explicit).
  //     The frozen builders LinH/JBlockCommitJ/JRecChildF/JExecReceiptOf/
  //     JCatalogRootJ/StateRootJ-chain are declared [function] (non-total)
  //     over the KRYPTO Keccak256raw hook, which has NO evaluator on the
  //     Haskell backend; every claim whose proof path materializes them
  //     over symbolic arguments is killed by an undischargeable
  //     #Ceil(Keccak256raw(...)) (probe-verified: see audit/induction-
  //     diagnosis.md).  Mathematically keccak-256 IS a total function — the
  //     backend merely lacks the evaluator — so the 1L ladder states that
  //     definedness EXPLICITLY through total wrappers (each equal to the
  //     frozen builder by a single defining rule) and uses them in claim
  //     destinations.  THE ASSUMPTION IS DEFINEDNESS ONLY — it does not
  //     assume collision resistance, preimage resistance, or any hash
  //     EQUALITY; every hash equality remains a claim hypothesis where it
  //     is one, and is concrete on the LLVM/Python tier.  L-INV-HASH-
  //     BOUNDARY documents this in the assumption register.
  // ---------------------------------------------------------------------------
  syntax Bytes ::= LinHT ( Bytes ) [function, total]
  rule LinHT(B:Bytes) => LinH(B)

  syntax Bytes ::= JBlockCommitWJ ( JBlockJ , ProtoCfgR3 ) [function, total]
  rule JBlockCommitWJ(B:JBlockJ, C:ProtoCfgR3) => JBlockCommitJ(B, C)

  syntax Bytes ::= JRecChildWT ( LinRecG ) [function, total]
  rule JRecChildWT(RG:LinRecG) => JRecChildF(RG)

  syntax Bytes ::= ProtoRootR3T ( ProtoCfgR3 ) [function, total]
  rule ProtoRootR3T(C:ProtoCfgR3) => ProtoRootR3(C)

  syntax Bytes ::= JCatalogRootWT ( JCatalog ) [function, total]
  rule JCatalogRootWT(P:JCatalog) => JCatalogRootJ(P)

  syntax JExecReceipt ::= JExecReceiptWT ( Bytes , List , Bytes , Int , Map ,
        ProtoCfgR3 , JCatalog , Bytes , Bytes , Int , Bytes , Map , Map ,
        List ) [function, total]
  rule JExecReceiptWT(SRC:Bytes, PG:List, CL:Bytes, VL:Int, S:Map,
                      C:ProtoCfgR3, PCAT:JCatalog, A:Bytes, H:Bytes, N:Int,
                      LH:Bytes, P:Map, E:Map, T:List)
    => JExecReceiptOf(SRC, PG, CL, VL, S, C, PCAT, A, H, N, LH, P, E, T)

endmodule

