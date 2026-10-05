// =============================================================================
// SRW3 Phase 1E — GATE SOUNDNESS (AUTH-COMMIT) mechanized proof
//                          (phase1e/proofs/gate_auth_commit.k)
//
// Backend: HASKELL (kprove).
//
//   GA1 (THE GATE THEOREM, full symbolic generality):
//     If VerifyLineageA(RE, C, T, HEAD) = "valid-a" then ALL of:
//       (i)  the composition-aware legacy chain verdicts "valid"
//            (12 layers + exact-equality composition, unmodified);
//       (ii) the universe respects the model capacity (|U| <= 256);
//       (iii) the universe contains no reserved pad key;
//       (iv) stateRoot == AuthRoot(canonical universe, presented post)
//            [Mode S: self-computed root over the presented artifacts];
//       (v)  stateRoot == anchor
//            [Mode A: bound to the authoritative state commitment];
//       (vi) childE == Keccak256(CanonCoreE)
//            [the extended commitment covers sig + stateRoot].
//     An accepted record therefore presents a post-state that is
//     BOTH internally self-consistent (Level 1) AND anchored to the
//     authoritative commitment (Level 2). The certificate terms (iv)-(vi)
//     appear VERBATIM in the verifier's guards — the proof consumes no
//     hash evaluation and no cryptographic assumption.
//
//   GA2 (anchor-only rejection — the K form of CM-E7): with legacy green,
//     universe ok and the self-computed root matching, an anchor mismatch is
//     EXACTLY the "invalid-anchor" verdict. Combined with the krun demo
//     (neg3: the L7-consistent hidden write), this mechanizes that the
//     ANCHOR layer alone rejects what the Level-1 surface cannot even see.
//
//   GA3 (capacity/pad REFUSE directions): model refuses fire before any
//     root comparison (explicit, never silent).
//
// Anti-vacuity: the gate premise is SATISFIABLE — witnessed concretely by
// the demo suite (pos=valid-a, chain=valid-a) on the LLVM backend with real
// keccak + secp256k1. No theorem here is vacuously true by an unsatisfiable
// gate condition; the positive witness is a permanent demo case.
// =============================================================================

requires "srw3auth.k"

module SRW3AUTH-GATE-PROOFS
  imports SRW3AUTH

  claim // GA1: the gate soundness theorem (acceptance certificate)
    <k> ( VerifyLineageA(RE:LinRecE, C:AuthCtx, T:Int, HEAD:Bytes) ==K "valid-a" )
        impliesBool
        ( VerifyLineagePE(linRecOfE(RE:LinRecE), authCtxLin(C:AuthCtx), T:Int, HEAD:Bytes)
              ==K "valid"
          andBool AuthCapacityOk(AuthUniverseOf(C:AuthCtx))
          andBool AuthPadOk(AuthUniverseOf(C:AuthCtx))
          andBool BytesEq( linStateRootOf(RE:LinRecE)
                         , AuthRootOf( AuthUniverseOf(C:AuthCtx)
                                     , linCtxState(authCtxLin(C:AuthCtx)) ) )
          andBool BytesEq( linStateRootOf(RE:LinRecE)
                         , authCtxAnchor(C:AuthCtx) )
          andBool BytesEq( linChildEOf(RE:LinRecE)
                         , AuthChildE(linRecOfE(RE:LinRecE), linStateRootOf(RE:LinRecE)) ) )
        => true </k>
    requires true

  claim // GA2: anchor-layer rejection is exact (CM-E7 counterpart, symbolic)
    <k> VerifyLineageA(RE:LinRecE, C:AuthCtx, T:Int, HEAD:Bytes)
        ==K "invalid-anchor"
        => true </k>
    requires VerifyLineagePE(linRecOfE(RE:LinRecE), authCtxLin(C:AuthCtx), T:Int, HEAD:Bytes)
                                       ==K "valid"
     andBool AuthCapacityOk(AuthUniverseOf(C:AuthCtx))
     andBool AuthPadOk(AuthUniverseOf(C:AuthCtx))
     andBool AuthStateRootOk(RE:LinRecE, C:AuthCtx)
     andBool notBool AuthAnchorOk(RE:LinRecE, C:AuthCtx)

  claim // GA3a: capacity refuse fires before any root comparison
    <k> VerifyLineageA(RE:LinRecE, C:AuthCtx, T:Int, HEAD:Bytes)
        ==K "invalid-capacity"
        => true </k>
    requires VerifyLineagePE(linRecOfE(RE:LinRecE), authCtxLin(C:AuthCtx), T:Int, HEAD:Bytes)
                                       ==K "valid"
     andBool notBool AuthCapacityOk(AuthUniverseOf(C:AuthCtx))

  claim // GA3b: pad-key refuse fires after capacity, before any root comparison
    <k> VerifyLineageA(RE:LinRecE, C:AuthCtx, T:Int, HEAD:Bytes)
        ==K "invalid-padkey"
        => true </k>
    requires VerifyLineagePE(linRecOfE(RE:LinRecE), authCtxLin(C:AuthCtx), T:Int, HEAD:Bytes)
                                       ==K "valid"
     andBool AuthCapacityOk(AuthUniverseOf(C:AuthCtx))
     andBool notBool AuthPadOk(AuthUniverseOf(C:AuthCtx))

endmodule
