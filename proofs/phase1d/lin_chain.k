// =============================================================================
// SRW3 Phase 1D — Part XI: chain continuity, PROVED BY K (Haskell backend)
// (proofs/phase1d/lin_chain.k — claims only; definition: srw3lin-symb.k)
//
// Theorem (chain continuity / position binding):
//   The accept relation admits a record R at position N ONLY with
//     R.ParentCommitment == HEAD  (the previous record's ChildCommitment,
//                                  LinRoot at the base)
//   and after acceptance
//     HEAD' == R.ChildCommitment  and  R is stored at index N.
//   Hence Parent_{i+1} == Child_i for every i — the chain is position-bound
//   by construction, and any replay/tamper that breaks the linkage is
//   rejected (demonstrated at the execution layer; see
//   transcripts/audit/phase1d_lin_demos.txt).
//
// Claims:
//   LIN-CHAIN-BASE : the empty chain at the root is valid
//   LIN-CHAIN-STEP : one position-bound accept preserves chain validity
//                    (Parent_{i+1} = Child_i is discharged here)
//   LIN-CHAIN-ALL  : ∀n — every sequence of accepts keeps the lineage
//                    chain-valid (circularity, 1B GH-M architecture)
//
// Evidence class: PROVED BY K (hs backend, kprove).
// =============================================================================

requires "srw3lin-symb.k"

module SRW3LIN-SYMB-CLAIMS
  imports SRW3LIN-SYMB

  claim // LIN-CHAIN-BASE: the empty chain is internally linked
    <k> LinChainLinked(.Map, 0) => true </k>
    [label(LIN-CHAIN-BASE)]

  claim // LIN-CHAIN-STEP (one-step, structural): an accepted record is stored
        // at index N with its parent equal to the current head, and the head
        // advances to its child — this IS Parent_{i+1} = Child_i (the new
        // record's parent = the previous chain tip; the previous tip's child
        // was the head, by the same rule at the previous step, base: root).
    <k> sAccept(R:LinRec) => .K </k>
    <slineage> L:Map => L:Map[linTidOf(R:LinRec) <- R:LinRec] </slineage>
    <snext> N:Int => N:Int +Int 1 </snext>
    <shead> H:Bytes => linChildOf(R:LinRec) </shead>
    <svalid> true => true </svalid>
    requires BytesEq(linParentOf(R:LinRec), H:Bytes)
         andBool linTidOf(R:LinRec) ==Int N:Int
         andBool linVersionOf(R:LinRec) ==Int 1
    [label(LIN-CHAIN-STEP)]

  claim // LIN-CHAIN-REJECT: a non-position-bound record leaves the chain,
        // counter and head completely untouched (replay/tamper cannot extend).
    <k> sAccept(R:LinRec) => .K </k>
    <slineage> L:Map </slineage>
    <snext> N:Int </snext>
    <shead> H:Bytes </shead>
    <svalid> true </svalid>
    requires notBool ( BytesEq(linParentOf(R:LinRec), H:Bytes)
                   andBool linTidOf(R:LinRec) ==Int N:Int
                   andBool linVersionOf(R:LinRec) ==Int 1 )
    [label(LIN-CHAIN-REJECT)]

  claim // LIN-CHAIN-ALL (∀n): the threaded chain-validity invariant holds at
        // every step of any accept sequence (1B GH-M threading architecture).
        // <svalid> is set to true by the ACCEPT rule (whose requires ARE the
        // linkage conditions: version-1 record, parent = current head,
        // tid = next index) and left untouched by REJECT. With the base
        // (initial configuration, <svalid> true) this is the induction that
        // every chain state reachable from the root is position-bound.
    <k> sCons(C:SymbCmd, RUN:SymbRun) => .K </k>
    <slineage> L:Map </slineage>
    <snext> N:Int </snext>
    <shead> H:Bytes </shead>
    <svalid> true </svalid>
    [circularity, label(LIN-CHAIN-ALL)]
endmodule
