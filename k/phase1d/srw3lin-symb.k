// =============================================================================
// SRW3 Phase 1D — symbolic chain layer (k/phase1d/srw3lin-symb.k)
//
// The STRUCTURAL core of the lineage accept relation, isolated from crypto
// evaluation: the Haskell backend cannot evaluate KRYPTO hooks (finding 1C-1),
// and the chain-continuity property is backend-independent. The commitment
// value flows through as an opaque symbolic Bytes. This module lives on the
// DEFINITION side (compiled into the hs definition) so that the proof spec
// (proofs/phase1d/lin_chain.k) can be a pure claims module.
//
// sAccept(R) is the position-bound append shared by BOTH gate paths
// (linGate construct path and linGatePresent verify path): a record is
// admitted at position N only with parent == head, and acceptance sets
// head := child. The Phase-1D gate rules of srw3lin-gate.k are the crypto-
// evaluating instance of exactly this relation (plus digest/signature
// obligations evaluated inside VerifyLineage / LinGateIntegrityOk).
//
// The accept relation is TOTAL: a record whose parent is not the current head
// (or whose tid is not the next index) is REJECTED and the state is unchanged
// — replay/tamper cannot extend the chain. The <svalid> cell threads the
// chain-validity invariant through the transition sequence (1B GH-M ghost-
// threading architecture): every ACCEPTED record re-establishes the linkage
// conjunction; rejections leave it untouched.
// =============================================================================

requires "srw3lin-verify.k"

module SRW3LIN-SYMB
  imports SRW3LIN-VERIFY

  // ---- symbolic accept command ----------------------------------------------
  // The run is a cons-list term (1B GateRun4 architecture): the ∀n circularity
  // applies at every sCons state; runNil terminates the sequence.
  syntax SymbCmd ::= "sAccept" "(" LinRec ")"
  syntax SymbRun ::= "runNil" | sCons(SymbCmd, SymbRun)

  configuration <srw3linsymb>
                  <k> $PGM:SymbRun </k>
                  <slineage> .Map </slineage>      // Map tid -> LinRec
                  <snext> 0 </snext>
                  <shead> LinRoot </shead>
                  <svalid> true </svalid>          // threaded chain-validity
                </srw3linsymb>

  rule <k> sCons(C:SymbCmd, RUN:SymbRun) => C ~> RUN ... </k>
  rule <k> runNil => .K ... </k>

  // position-bound ACCEPT: the ONLY rule that extends the lineage
  rule <k> sAccept(R:LinRec) => .K ... </k>
       <slineage> L:Map => L[linTidOf(R) <- R] </slineage>
       <snext> N:Int => N +Int 1 </snext>
       <shead> H:Bytes => linChildOf(R) </shead>
       // linkage re-established BY this rule's own requires (position binding):
       // the successor's validity is set directly, which is what makes the
       // circularity hypothesis re-applicable at the successor state
       <svalid> _:Bool => true </svalid>
    requires BytesEq(linParentOf(R), H:Bytes)
         andBool linTidOf(R) ==Int N:Int
         andBool linVersionOf(R) ==Int 1

  // REJECT (restore, [owise]): a non-position-bound record cannot extend the
  // chain — this rule applies exactly when the accept rule's requires fail.
  rule <k> sAccept(_:LinRec) => .K ... </k>
       <slineage> L:Map </slineage>
       <snext> N:Int </snext>
       <shead> H:Bytes </shead>
       <svalid> V:Bool </svalid>
    [owise]

  // ---- chain validity, split into (a) internal linkage and (b) head link.
  // (a) records 0..N-1 are internally linked: record i carries tid i, is a
  //     version-1 record, and its parent equals its predecessor's child
  //     (head-free — this shape keeps the STEP claim free of symbolic
  //     substitution, which the hs prover cannot discharge through the
  //     uninterpreted BytesEq).
  // (b) the head link: the last record's child equals the head; threaded by
  //     the accept rule's construction (head := child) and the base root.
  syntax Bool ::= LinChainLinked ( Map , Int ) [function, total]
  rule LinChainLinked(_:Map, 0:Int) => true
  rule LinChainLinked(L:Map, N:Int)
    => linVersionOf(linRecAt(L, N -Int 1)) ==Int 1
       andBool linTidOf(linRecAt(L, N -Int 1)) ==Int N -Int 1
       andBool LinChainLinked(L, N -Int 1)
       andBool ( N ==Int 1 orBool
                 BytesEq(linParentOf(linRecAt(L, N -Int 1)),
                         linChildOf(linRecAt(L, N -Int 2))) )
    requires N >=Int 1
endmodule
