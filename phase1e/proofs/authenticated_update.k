// =============================================================================
// SRW3 Phase 1E — AUTH-UPDATE mechanized proofs
//                          (phase1e/proofs/authenticated_update.k)
//
// Backend: HASKELL (kprove). Structured (List) proof-data form; see
// authenticated_read.k for the form boundary and srw3auth.k §3b.
//
//   AU1 (correctness)      : a proof-based update of a VERIFIED leaf equals
//                            the walk from the new leaf content over the SAME
//                            siblings — no trust gap between the verifier-side
//                            update and the producer-side re-derivation.
//   AU2 (failure sentinel) : an unverified basis yields the .Bytes sentinel —
//                            no update is computed from an unverified basis.
//   AU3 (determinism)      : the new-content walk is a function of its inputs.
//
// NOT mechanized (explicit boundary): that changing the value CHANGES the
// root requires hash collision resistance (A-E1); demonstrated experimentally
// (update-eq / forged checks) instead.
// =============================================================================

requires "srw3auth.k"

module SRW3AUTH-UPDATE-PROOFS
  imports SRW3AUTH

  claim // AU1: verified-basis updates are exactly the new-content walk
    <k> BytesEq( AuthUpdateRootList(R:Bytes, K:Int, PRES:Int, V:Int, VNEW:Int, IDX:Int,
                                    AuthSib8(S1:Bytes, S2:Bytes, S3:Bytes, S4:Bytes,
                                          S5:Bytes, S6:Bytes, S7:Bytes, S8B:Bytes))
               , AuthWalkRootList(K:Int, 1, VNEW:Int, IDX:Int,
                                  AuthSib8(S1:Bytes, S2:Bytes, S3:Bytes, S4:Bytes,
                                        S5:Bytes, S6:Bytes, S7:Bytes, S8B:Bytes)) )
        ==Bool true
        => true </k>
    requires IDX:Int >=Int 0 andBool IDX:Int <Int 256
         andBool (PRES:Int ==Int 0 orBool PRES:Int ==Int 1)
         andBool (PRES:Int ==Int 1 orBool V:Int ==Int 0)
         andBool BytesEq( AuthWalkRootList(K:Int, PRES:Int, V:Int, IDX:Int,
                                           AuthSib8(S1:Bytes, S2:Bytes, S3:Bytes, S4:Bytes,
                                                 S5:Bytes, S6:Bytes, S7:Bytes, S8B:Bytes))
                        , R:Bytes )

  claim // AU2: unverified basis -> the .Bytes sentinel (no silent update)
    <k> BytesEq( AuthUpdateRootList(R:Bytes, K:Int, PRES:Int, V:Int, VNEW:Int, IDX:Int,
                                    SIBS:List)
               , .Bytes )
        ==Bool true
        => true </k>
    requires notBool AuthVerifyInclList(R:Bytes, K:Int, PRES:Int, V:Int, IDX:Int, SIBS:List)

  claim // AU3: the updated walk is deterministic in the new value
    <k> BytesEq( AuthWalkRootList(K:Int, 1, VNEW:Int, IDX:Int,
                                  AuthSib8(S1:Bytes, S2:Bytes, S3:Bytes, S4:Bytes,
                                        S5:Bytes, S6:Bytes, S7:Bytes, S8B:Bytes))
               , AuthWalkRootList(K:Int, 1, VNEW:Int, IDX:Int,
                                  AuthSib8(S1:Bytes, S2:Bytes, S3:Bytes, S4:Bytes,
                                        S5:Bytes, S6:Bytes, S7:Bytes, S8B:Bytes)) )
        ==Bool true
        => true </k>
    requires true

endmodule
