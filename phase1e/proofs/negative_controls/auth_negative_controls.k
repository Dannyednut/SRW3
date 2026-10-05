// =============================================================================
// SRW3 Phase 1E — NEGATIVE CONTROLS (designed-to-fail probes)
//            (phase1e/proofs/negative_controls/auth_negative_controls.k)
//
// Following the GH-*-NEG precedent: these claims are EXPECTED to fail or get
// stuck. They pin the boundary of what the mechanization establishes, so no
// result can silently drift stronger.
//
//   NC1 (hash-injectivity boundary, designed STUCK): "different leaf contents
//        always have different leaf digests" — NOT mechanizable: Keccak256raw
//        is uninterpreted on the Haskell backend. The distinction of digests
//        under differing content is exactly assumption A-E1 (collision
//        resistance) — demonstrated experimentally (concrete digests differ,
//        Python + LLVM), never proved here.
//   NC2 (forged-root acceptance, designed FAIL): "verification accepts a root
//        that equals the walk of a DIFFERENT content" — contradicts AR2.
//   NC3 (vacuity probe, designed FAIL): "verification NEVER accepts" —
//        contradicted by the concrete positive witness (demo pos=valid-a);
//        its failure evidences non-vacuity of the acceptance direction.
// =============================================================================

requires "../../semantics/srw3auth.k"

module SRW3AUTH-NEG-CONTROLS
  imports SRW3AUTH

  // NC1 (DESIGNED STUCK — A-E1 boundary): do not strengthen.
  claim // NC1
    <k> BytesEq( Keccak256raw(AuthLeafBytes(K:Int, 1, V:Int))
               , Keccak256raw(AuthLeafBytes(K:Int, 1, V2:Int)) )
        ==Bool false
        => true </k>
    requires V:Int =/=Int V2:Int

  // NC2 (DESIGNED FAIL — contradicts AR2): must NOT verify.
  claim // NC2
    <k> AuthVerifyIncl(R:Bytes, K:Int, 1, V:Int, IDX:Int, PR:Bytes)
        ==Bool true
        => true </k>
    requires BytesEq( AuthWalkRoot(K:Int, 1, V:Int +Int 1, IDX:Int, PR:Bytes)
                    , R:Bytes )

  // NC3 (DESIGNED FAIL — vacuity probe): must NOT verify.
  claim // NC3
    <k> AuthVerifyIncl(R:Bytes, K:Int, PRES:Int, V:Int, IDX:Int, PR:Bytes)
        ==Bool false
        => true </k>
    requires AuthProofWF(IDX:Int, PRES:Int, V:Int, PR:Bytes)
     andBool BytesEq( AuthWalkRoot(K:Int, PRES:Int, V:Int, IDX:Int, PR:Bytes)
                    , R:Bytes )

endmodule
