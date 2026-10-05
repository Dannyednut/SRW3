// =============================================================================
// SRW3 Phase 1E — AUTH-READ mechanized proofs
//                          (phase1e/proofs/authenticated_read.k)
//
// Backend: HASKELL (kprove). Claims are stated over the STRUCTURED (List)
// form of the proof data — the same index + 8 sibling digests, bottom-up, as
// the 260-byte wire format; see srw3auth.k §3b for the precise relationship
// (the wire-format byte extraction is exercised concretely on the LLVM demo
// and pinned cross-layer; substrBytes does not reduce on symbolic Bytes).
// The walk reduces structurally; hash applications stay as uninterpreted
// terms — NO cryptographic assumption is consumed.
//
//   AR1 (sound direction)  : verification ACCEPTS the root it walks to from
//                            the claimed leaf content + sibling path.
//   AR2 (exactness / iff)  : under well-formedness, acceptance holds iff the
//                            recomputed walk equals R — NO acceptance slack.
//   AR3 (ill-formed input) : a non-well-formed proof NEVER verifies.
//   AR4 (determinism)      : the walk is a function of its inputs.
//
// Epistemic status: checked by evaluation with UNIVERSAL quantification over
// K, PRES, V, IDX, S1..S8, R (the SF/G precedent).
// =============================================================================

requires "srw3auth.k"

module SRW3AUTH-READ-PROOFS
  imports SRW3AUTH

  claim // AR1: honest-direction acceptance (the walked root verifies)
    <k> AuthVerifyInclList( AuthWalkRootList(K:Int, PRES:Int, V:Int, IDX:Int,
                                             AuthSib8(S1:Bytes, S2:Bytes, S3:Bytes, S4:Bytes,
                                                  S5:Bytes, S6:Bytes, S7:Bytes, S8B:Bytes))
                          , K:Int, PRES:Int, V:Int, IDX:Int
                          , AuthSib8(S1:Bytes, S2:Bytes, S3:Bytes, S4:Bytes,
                                 S5:Bytes, S6:Bytes, S7:Bytes, S8B:Bytes) )
        ==Bool true
        => true </k>
    requires IDX:Int >=Int 0 andBool IDX:Int <Int 256
         andBool (PRES:Int ==Int 0 orBool PRES:Int ==Int 1)
         andBool (PRES:Int ==Int 1 orBool V:Int ==Int 0)

  claim // AR2a: exactness, if-direction — the walk matching R implies acceptance
    <k> AuthVerifyInclList(R:Bytes, K:Int, PRES:Int, V:Int, IDX:Int,
                           AuthSib8(S1:Bytes, S2:Bytes, S3:Bytes, S4:Bytes,
                                S5:Bytes, S6:Bytes, S7:Bytes, S8B:Bytes))
        ==Bool true
        => true </k>
    requires IDX:Int >=Int 0 andBool IDX:Int <Int 256
         andBool (PRES:Int ==Int 0 orBool PRES:Int ==Int 1)
         andBool (PRES:Int ==Int 1 orBool V:Int ==Int 0)
         andBool BytesEq( AuthWalkRootList(K:Int, PRES:Int, V:Int, IDX:Int,
                                           AuthSib8(S1:Bytes, S2:Bytes, S3:Bytes, S4:Bytes,
                                                S5:Bytes, S6:Bytes, S7:Bytes, S8B:Bytes))
                        , R:Bytes )

  claim // AR2b: exactness, only-if direction — acceptance implies the walk
        // matched R (no acceptance slack; joint with AR2a: the iff)
    <k> AuthVerifyInclList(R:Bytes, K:Int, PRES:Int, V:Int, IDX:Int,
                           AuthSib8(S1:Bytes, S2:Bytes, S3:Bytes, S4:Bytes,
                                S5:Bytes, S6:Bytes, S7:Bytes, S8B:Bytes))
        ==Bool false
        => true </k>
    requires IDX:Int >=Int 0 andBool IDX:Int <Int 256
         andBool (PRES:Int ==Int 0 orBool PRES:Int ==Int 1)
         andBool (PRES:Int ==Int 1 orBool V:Int ==Int 0)
         andBool notBool BytesEq( AuthWalkRootList(K:Int, PRES:Int, V:Int, IDX:Int,
                                                   AuthSib8(S1:Bytes, S2:Bytes, S3:Bytes, S4:Bytes,
                                                        S5:Bytes, S6:Bytes, S7:Bytes, S8B:Bytes))
                                , R:Bytes )

  claim // AR3: ill-formed proofs never verify (generic list form)
    <k> AuthVerifyInclList(R:Bytes, K:Int, PRES:Int, V:Int, IDX:Int, SIBS:List)
        ==Bool false
        => true </k>
    requires notBool AuthProofWFList(IDX:Int, PRES:Int, V:Int, SIBS:List)

  claim // AR4: the walk is a FUNCTION of (K, PRES, V, IDX, siblings)
    <k> BytesEq( AuthWalkRootList(K:Int, PRES:Int, V:Int, IDX:Int,
                                  AuthSib8(S1:Bytes, S2:Bytes, S3:Bytes, S4:Bytes,
                                       S5:Bytes, S6:Bytes, S7:Bytes, S8B:Bytes))
               , AuthWalkRootList(K:Int, PRES:Int, V:Int, IDX:Int,
                                  AuthSib8(S1:Bytes, S2:Bytes, S3:Bytes, S4:Bytes,
                                       S5:Bytes, S6:Bytes, S7:Bytes, S8B:Bytes)) )
        ==Bool true
        => true </k>
    requires true

endmodule
