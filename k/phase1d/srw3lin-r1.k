// =============================================================================
// SRW3 Phase 1D-R1 Part VII — K-side composition-aware verification
// (k/phase1d/srw3lin-r1.k — ADDITIVE; the frozen 1D modules are untouched)
//
// The independent Python verifier's L7 fix (Part II) is mirrored here: the
// K lineage verifier gains the SAME exact-equality composition check
//
//     PresentedPost == Apply(PreState, TrueEffects)
//
// established by CANONICAL finite-map equality (byte equality of the
// canonical encodings — the K equivalent of post_map == composed_map),
// NEVER by an asymmetric membership loop.
//
// Schema note (additive, version-compatible): a NEW context constructor
// linCtxP carries the claimed PRE-STATE explicitly. The legacy linCtx
// constructor and VerifyLineage (12-layer chain) are unchanged; the legacy
// context does not carry a pre-state and therefore cannot state the
// composition relation — documented, not silently reinterpreted.
//
// The demonstration records are built by LinBuildRec — every cryptographic
// field is GENUINE (real keccak, real secp256k1 via the pinned shim path).
// The ONLY false thing in the negative cases is the post-state
// correspondence — exactly the authorized-dishonest-producer threat (R1
// Parts VIII/IX).
// =============================================================================

requires "srw3lin-verify.k"

module SRW3LIN-R1
  imports SRW3LIN-VERIFY

  // ---- Apply(PreState, Effects): per-slot overwrite preserving others ------
  syntax Map ::= LinApplyEff ( Map , Map ) [function, total]
  rule LinApplyEff(P:Map, .Map) => P
  rule LinApplyEff(P:Map, E:Map)
    => LinApplyEff( LinSetKV(P, MinKeyOfMap(E),
                             MinKeyOfMap(LinMapAt(E, MinKeyOfMap(E))),
                             LinIntAt(LinMapAt(E, MinKeyOfMap(E)),
                                      MinKeyOfMap(LinMapAt(E, MinKeyOfMap(E))))),
                    E[MinKeyOfMap(E) <- undef])
    requires sizeMap(E) >=Int 1

  // ---- composition-aware context (claimed pre-state travels with it) -------
  syntax LinCtx ::= linCtxP ( Map , Map , Map , Map , Set )

  syntax Map ::= linCtxPre    ( LinCtx ) [function]
  syntax Map ::= linCtxEffP   ( LinCtx ) [function]
  syntax Map ::= linCtxPostP  ( LinCtx ) [function]
  syntax Map ::= linCtxRegP   ( LinCtx ) [function]
  syntax Set ::= linCtxAuthP  ( LinCtx ) [function]

  rule linCtxPre  (linCtxP(Q:Map, _:Map, _:Map, _:Map, _:Set)) => Q
  rule linCtxEffP (linCtxP(_:Map, E:Map, _:Map, _:Map, _:Set)) => E
  rule linCtxPostP(linCtxP(_:Map, _:Map, S:Map, _:Map, _:Set)) => S
  rule linCtxRegP (linCtxP(_:Map, _:Map, _:Map, R:Map, _:Set)) => R
  rule linCtxAuthP(linCtxP(_:Map, _:Map, _:Map, _:Map, A:Set)) => A

  // ---- projection rules: the legacy 12-layer chain must work over linCtxP
  //      (VerifyLineage's projectors only matched the legacy constructor) ----
  rule linCtxInputs  (linCtxP(I:Map, _:Map, _:Map, _:Map, _:Set)) => I
  rule linCtxEffects (linCtxP(_:Map, E:Map, _:Map, _:Map, _:Set)) => E
  rule linCtxState   (linCtxP(_:Map, _:Map, S:Map, _:Map, _:Set)) => S
  rule linCtxRegistry(linCtxP(_:Map, _:Map, _:Map, R:Map, _:Set)) => R
  rule linCtxAuthSet (linCtxP(_:Map, _:Map, _:Map, _:Map, A:Set)) => A

  // ---- composition predicate: canonical byte equality (order-deterministic,
  //      symmetric, value-exact — the K form of post_map == composed_map) ----
  syntax Bool ::= LinCompositionOk ( LinCtx ) [function, total]
  rule LinCompositionOk(CTX:LinCtx)
    => BytesEq( LinCanonKV(linCtxPostP(CTX)),
                LinCanonKV(LinApplyEff(linCtxPre(CTX), linCtxEffP(CTX))) )

  // ---- VerifyLineageP: the 12-layer chain, then the composition check ------
  // Verdict order: any of the 12 legacy verdicts fires first (unchanged
  // semantics); a record passing all twelve but violating the composition
  // yields the NEW verdict "invalid-state-composition".
  syntax String ::= VerifyLineageP ( LinRec , LinCtx , Int , Bytes ) [function, total]

  rule VerifyLineageP(R:LinRec, CTX:LinCtx, T:Int, HEAD:Bytes)
    => VerifyLineage(R, CTX, T, HEAD)
    requires notBool VerifyLineage(R, CTX, T, HEAD) ==String "valid"

  rule VerifyLineageP(R:LinRec, CTX:LinCtx, T:Int, HEAD:Bytes)
    => "invalid-state-composition"
    requires VerifyLineage(R, CTX, T, HEAD) ==String "valid"
     andBool notBool LinCompositionOk(CTX)

  rule VerifyLineageP(R:LinRec, CTX:LinCtx, T:Int, HEAD:Bytes)
    => "valid"
    requires VerifyLineage(R, CTX, T, HEAD) ==String "valid"
     andBool LinCompositionOk(CTX)

endmodule
