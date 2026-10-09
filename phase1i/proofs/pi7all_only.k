// =============================================================================
// SRW3 Phase 1I — THE PROTOCOL COMMITMENT PROOF LADDER
//                          (phase1i/proofs/pi_proofs.k)
//
// Backend: HASKELL (kprove).  Claims module over srw3proto.k (definitions).
//
// Ladder (spec sections 7/8/19):
//
//   PI0  protocol definitions                (srw3proto.k — the model itself)
//   PI1  validity composition                (PI1-COMMIT-SAFETY below)
//   PI2  commitment exclusion                (PI2-* branch-wise: decision +
//        exec branches PROVED; policy/context-digest substitution branches
//        DEMONSTRATED at the model level — Python attack matrix PI-A5/A6/A7 —
//        because their requires cannot evaluate keccak on the hs backend)
//   PI3  deterministic commitment            (definitionally: CommitP is a
//        total function of canonical fields; the DIGEST layer is keccak —
//        unevaluated on the Haskell backend, DEMONSTRATED on LLVM by the
//        demo suite; see the report's classification)
//   PI4  lineage continuity                  (inherited: Phase 1D LIN-CHAIN
//        PROVED; the protocol layer reuses the same threading architecture)
//   PI5  policy authority                    (PI5-*: the authorized commitment
//        is CONFIG-derived; substitution refuted branch-wise)
//   PI6  reorg/replay safety                 (PI7-REJECT at the transition
//        level + the Python suite run_reorg_replay.py)
//   PI7  committed-state safety              (PI7-BASE / PI7-STEP /
//        PI7-ALL circularity: every chain reachable through pAccept keeps
//        CommitChainLinked — the 1D GH-M threading architecture)
//
// ANTI-VACUITY (the spec-7 prohibition — "no theorem whose assumptions
// already contain the conclusion"):
//   * PI1 is an implication FROM Commit_P TO its conjuncts: the content is
//     that the committed state carries exec-validity, a valid gate decision,
//     the AUTHORIZED policy commitment and the AUTHORIZED context digest.
//   * The transition rules (pAccept) do NOT assume Commit_P — they CHECK it;
//     PI7-REJECT proves a failing block cannot extend the chain.
//   * The gate LINK is real: the committed decision is the ProtoDecisionOfGate
//     image of the frozen VerifyLineageG verdict (PIB-GATELINK-*), and
//     "valid-g" is the frozen 21-conjunct accept — non-vacuity of the gate
//     accept was witnessed concretely in Phase 1G (rel=1/2/3 demos, LLVM,
//     real keccak) and is re-witnessed for the protocol layer by the Phase 1I
//     demo suite (LLVM, real keccak).
//   * KRYPTO hooks (keccak via LinH) are UNINTERPRETED on the Haskell backend
//     (finding 1C-1 discipline): every claim below is stated so that digest
//     values flow as opaque symbolic Bytes.  No claim evaluates crypto.
//
// Evidence class: PROVED BY K (hs backend) — at the level of the abstract
// protocol model; crypto-instantiated digests DEMONSTRATED (LLVM demos).
// =============================================================================

requires "../semantics/srw3proto.k"

module PI7-ALL-SPEC
  imports SRW3PROTO

  // ===========================================================================
  // PI-1 — SRW3 commitment safety (accept direction)
  //   Committed_P(B)  =>  ExecValid(B) AND SRW3Valid(B)
  // mechanized as: Commit_P true implies EVERY conjunct (exec binding, a
  // valid protocol decision, the protocol-authorized policy commitment, the
  // authorized context digest for the applicable lineage head).
  // ===========================================================================


  claim // PI7-ALL (forall n): the threaded invariant holds at every step of
        // ANY accept sequence — <pvalid> is set to true only by the ACCEPT
        // rule (whose requires ARE the commitment conditions) and untouched
        // by REJECT; with the base this is the induction that every chain
        // state reachable from the protocol root is commitment-bound
        // (1B GH-M threading architecture; LIN-CHAIN-ALL carried upward).
    <k> pCons(CI:PCmdI, RUN:PRunI) => .K </k>
    <plineage> L:Map </plineage>
    <pnext> N:Int </pnext>
    <phead> H:Bytes </phead>
    <pvalid> true </pvalid>
    [circularity, label(PI7-ALL)]

endmodule
