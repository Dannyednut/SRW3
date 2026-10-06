// =============================================================================
// SRW3 Phase 1F — NOT MECHANIZED ATTEMPTS (disclosed, not part of the run)
//                          (phase1f/proofs/not_mechanized/README + claims)
//
// These claims were STATED and ATTEMPTED on the Haskell backend and did NOT
// go through. They are kept verbatim as the honest record of the proof
// boundary. None of them weakens a soundness claim: each is either an
// explanatory lemma or an identity whose content is pinned concretely by
// the LLVM demo suite and the cross-layer byte checks (the 1E RL1/RL3a/RL3b
// precedent for this classification).
//
//   EX3a (exec_id_canon_full.k): symbolic order-preservation
//        ExecEventsBytes(ListItem(E) REST) ==K ExecEvtBytes(E) +Bytes ExecEventsBytes(REST)
//        — requires induction over the symbolic tail REST; the concrete
//        order pins EX3c/EX3d are PROVED.
//
//   EX4d (exec_replay_full.k): cross-slot write order does not change the
//        replay-final map — the prover cannot close the nested-Map update
//        equality (LinMapAt over updated inner maps). Property pinned
//        concretely (Python suite + llvm demo); same-slot order sensitivity
//        IS mechanized (EX4c).
//
//   EX5w (exec_replay_full.k): THE REPLAY-WRITES LEMMA
//        ExecReplayMap(T, PRE) ==K LinApplyEff2(PRE, ExecTraceWrites(T))
//        — full-symbolic map induction exceeds the prover budget. The
//        gate's binding does NOT depend on it: ExecReplayOk compares the
//        replay-final map directly.
//
//   EX5d/EX5f/EX5g/EX5h (exec_record_binding_full.k): honest-construction
//        coherence pins over fully symbolic record arguments — the
//        AuthRootOf/AuthUnion3/AuthKeysOfMap path over symbolic Maps is
//        not closable on this backend (same class as 1E RL1); the id/trace/
//        config/witness field forms are pinned by EX5a/EX5b/EX5c/EX5e and
//        concretely by the llvm demo + cross-layer bytes.
// =============================================================================
