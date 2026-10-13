// =============================================================================
// SRW3 Phase 1J — PROOF FIXTURES (definition module)
//                    (phase1j/proofs/j_fixtures.k)
//
// K proof modules admit only claims and simplification rules, so the extra
// MUTATION fixtures used by the canon/binding claims live here, in a plain
// definition module imported by j_proofs.k.  The base fixtures (XCatJ, XCfgJ,
// the derived executions, the evidence chain) are the DEMO module's — the
// demo module's fixture constants are all [function, total] definitions
// (inert: no transition rules beyond the certificate command, which no proof
// invokes), so importing it adds NOTHING to the transition system that the
// audit's rule-set cross-check would miss (the audit cross-checks that the
// reachable rule sets of SRW3CLOSURE-J and SRW3CLOSURE-J-FIXTURES coincide
// on the machine commands).
//
// MUTATION FIXTURES (all derived from XCatJ by single-field edits; every
// canon claim over them is a decidable byte-level preimage inequality):
//   XCatJNameB   — the "oracle" app name mutated ("oracled")
//   XCatJOwnerB  — resource K3's owner mutated (4099 -> 4098)
//   XCatJPolB    — local invariant l4's upper bound mutated (100 -> 101)
//   XCatJBadHe   — an invariant naming an UNREGISTERED hyperedge id 99
//   XCatJUnsafeGen — genesis-unsafe catalog (local l1 lower bound 1: the
//                  all-zero genesis state violates it — J-INITIAL-SAFE
//                  refuses the pin)
//   XProgG / the derived global-attack artifacts (XPostG/XEffG/XTraceG) —
//   the J-A14/J-A15 global-invariant class.
// =============================================================================

requires "../semantics/srw3closure-j-demo.k"

module SRW3CLOSURE-J-FIXTURES
  imports SRW3CLOSURE-J-DEMO

  // name mutation: "oracled" (7 bytes)
  syntax JCatalog ::= "XCatJNameB" [function, total]
  rule XCatJNameB
    => jCatalog( jcPolicyVOf(XCatJ)
               , ListItem(jApp(4097, LinHex("6f7261636c6564")))
                 ListItem(jApp(4098, LinHex("6c656e64696e67")))
                 ListItem(jApp(4099, LinHex("7661756c74")))
               , jcResourcesOf(XCatJ), jcHypersOf(XCatJ)
               , jcLocalsOf(XCatJ), jcHypersInvOf(XCatJ), jcGlobalsOf(XCatJ) )

  // owner mutation: K3's owner 4099 -> 4098
  syntax JCatalog ::= "XCatJOwnerB" [function, total]
  rule XCatJOwnerB
    => jCatalog( jcPolicyVOf(XCatJ), jcAppsOf(XCatJ)
               , ListItem(jRes(JRK1, 4097)) ListItem(jRes(JRK2, 4098))
                 ListItem(jRes(JRK3, 4098)) ListItem(jRes(JRK4, 4098))
               , jcHypersOf(XCatJ)
               , jcLocalsOf(XCatJ), jcHypersInvOf(XCatJ), jcGlobalsOf(XCatJ) )

  // policy mutation: local invariant l4's upper bound 100 -> 101
  syntax JCatalog ::= "XCatJPolB" [function, total]
  rule XCatJPolB
    => jCatalog( jcPolicyVOf(XCatJ), jcAppsOf(XCatJ), jcResourcesOf(XCatJ)
               , jcHypersOf(XCatJ)
               , ListItem(jInvLocal(1, JRK1, 0, 1000))
                 ListItem(jInvLocal(2, JRK2, 0, 500))
                 ListItem(jInvLocal(3, JRK3, 0, 500))
                 ListItem(jInvLocal(4, JRK4, 0, 101))
               , jcHypersInvOf(XCatJ), jcGlobalsOf(XCatJ) )

  // a hyperedge invariant naming an UNREGISTERED hyperedge id 99
  syntax JCatalog ::= "XCatJBadHe" [function, total]
  rule XCatJBadHe
    => jCatalog( jcPolicyVOf(XCatJ), jcAppsOf(XCatJ), jcResourcesOf(XCatJ)
               , jcHypersOf(XCatJ), jcLocalsOf(XCatJ)
               , ListItem(jInvSum(11, 99, ListItem(JRK2) ListItem(JRK3), 600))
                 ListItem(jInvSum(12, 2, ListItem(JRK2) ListItem(JRK4), 550))
               , jcGlobalsOf(XCatJ) )

  // GENESIS-UNSAFE catalog: local l1 requires k1 >= 1; the all-zero genesis
  // violates it (the J-INITIAL-SAFE base refuses this pin)
  syntax JCatalog ::= "XCatJUnsafeGen" [function, total]
  rule XCatJUnsafeGen
    => jCatalog( jcPolicyVOf(XCatJ), jcAppsOf(XCatJ), jcResourcesOf(XCatJ)
               , jcHypersOf(XCatJ)
               , ListItem(jInvLocal(1, JRK1, 1, 1000))
                 ListItem(jInvLocal(2, JRK2, 0, 500))
                 ListItem(jInvLocal(3, JRK3, 0, 500))
                 ListItem(jInvLocal(4, JRK4, 0, 100))
               , jcHypersInvOf(XCatJ), jcGlobalsOf(XCatJ) )

  // ---- the ALL-LITERAL configuration (every digest a literal byte string;
  //      the canon/substr claims are decidable on the Haskell backend — the
  //      R3FixCfg discipline) -----------------------------------------------
  syntax ProtoCfgR3 ::= "JFixCfgJ" [function, total]
  rule JFixCfgJ
    => protoCfgR3( LinHex("636861696e2d31")                       // "chain-1"
                 , 7
                 , LinHex("706f6c6963792d6469676573742d33322d627974652d706c616365686f6c646572")
                 , LinHex("6170702d7365742d6469676573742d33322d627974652d706c616365686f6c646572")
                 , LinHex("67726170682d6469676573742d33322d627974652d706c616365686f6c646572")
                 , LinHex("636c69656e742d636f6e6669672d6469676573742d33322d627974652d706c616365686f6c646572")
                 , LinHex("657865637574696f6e2d636c69656e742d6469676573742d33322d627974652d706c616365686f6c646572")
                 , LinHex("666f726b2d41")                          // "fork-A"
                 , LinHex("7363686564756c652d41")                  // "schedule-A"
                 , 3, 2
                 , LinHex("67756573742d6469676573742d33322d627974652d706c616365686f6c646572")
                 , LinHex("70726f6f662d636f6e6669672d6469676573742d33322d627974652d706c616365686f6c646572") )

  // the mid-program unsupported program (the refusal propagates)
  syntax List ::= "XProgMidUnsupported" [function, total]
  rule XProgMidUnsupported
    => ListItem(jWrite(4097, 0, 100)) ListItem(jUnsupported(96))
       ListItem(jWrite(4097, 1, 1))

  // the reordered program (same write multiset as XProg1, different order)
  syntax List ::= "XProg1Reordered" [function, total]
  rule XProg1Reordered
    => ListItem(jWrite(4098, 1, 100)) ListItem(jWrite(4098, 0, 100))
endmodule
