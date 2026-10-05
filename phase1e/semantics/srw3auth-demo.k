// =============================================================================
// SRW3 Phase 1E — K demonstration suite (phase1e/semantics/srw3auth-demo.k)
//
// Scenario mirrors phase1e/python/test_auth_verify.py exactly (the Phase 1D-R1
// canonical artifacts): Q/E/P as in the r1 suite; the ANCHOR is the root over
// the canonical universe of the honest transition, computed by the SAME
// AuthRootOf function the verifier uses.
//
//   pos   honest record + honest anchor ......................... "valid-a"
//         (the K non-vacuity witness: the gate premise is SATISFIABLE)
//   neg1  extra key (2,9):=999 in presented post (the L7 attack)  legacy first:
//                                                        "invalid-state-composition"
//   neg2  foreign stateRoot (root over PRE-content), all else
//         honest, childE consistent ....................... "invalid-state-root"
//   neg3  HIDDEN WRITE, L7-consistent: eff' declares (2,9):=999,
//         post' = Apply(Q,eff'), every digest/signature genuine,
//         stateRoot = root over the FORGED universe — the ANCHOR
//         (published for the honest transition) is what rejects
//                                                        "invalid-anchor"
//   neg4  stale anchor (previous commitment as current) ... "invalid-anchor"
//   neg5  childE byte-flipped ............................. "invalid-childe"
//   proofs: AUTH-READ honest / forged-value / AUTH-UPDATE equality /
//         non-membership checks (concrete)
//
// Expected verdict string:
//   pos=valid-a;neg1=invalid-state-composition;neg2=invalid-state-root;
//   neg3=invalid-anchor;neg4=invalid-anchor;neg5=invalid-childe
//   |proofs:incl=true,forged=false,update-eq=true,nonmemb=true
// =============================================================================

requires "srw3auth.k"

module SRW3AUTH-DEMO
  imports SRW3AUTH

  configuration <srw3auth>
                  <k> $PGM </k>
                  <aresult> "" </aresult>
                </srw3auth>

  syntax AuthPgm ::= "asuite"

  // ---- scenario artifacts (identical to the r1 suite) -----------------------
  syntax Map ::= "AQ" [function, total]
  rule AQ => LinSetKV(LinSetKV(LinSetKV(LinKV1(1, 0, 100), 1, 1, 0),
                               2, 0, 50), 2, 1, 1)
  syntax Map ::= "AE" [function, total]
  rule AE => LinSetKV(LinSetKV(LinKV1(1, 0, 25), 2, 1, 7), 1, 1, 0)
  // NOTE: the honest post is constructed INDEPENDENTLY (slot-by-slot), NOT
  // via LinApplyEff/LinApplyEff2 — the Phase 1D-R1 demo defined it as
  // LinApplyEff(Q,E), which made its positive composition check tautological
  // (see FINDING 1E-LINAPPLY-MULTISLOT, srw3auth.k §0).
  syntax Map ::= "AP" [function, total]
  rule AP => LinSetKV(LinSetKV(LinSetKV(LinKV1(1, 0, 25), 1, 1, 0), 2, 0, 50), 2, 1, 7)

  syntax Map ::= "AReg" [function, total]
  rule AReg => 5 |-> true  6 |-> true
  syntax Set ::= "AAuth" [function, total]
  rule AAuth => SetItem(LinAddrOf(LinDemoKey1)) SetItem(LinAddrOf(LinDemoKey2))

  // canonical universe of the honest transition
  syntax List ::= "AUni" [function, total]
  rule AUni => AuthUnion3(AuthKeysOfMap(AQ), AuthKeysOfMap(AE), AuthKeysOfMap(AP))

  // authoritative anchor over the honest transition (the publisher side)
  syntax Bytes ::= "AAnchor" [function, total]
  rule AAnchor => AuthRootOf(AUni, AP)

  syntax LinCtx ::= "ACtxOf" "(" Map ")" [function, total]
  rule ACtxOf(P:Map) => linCtxP(AQ, AE, P, AReg, AAuth)

  syntax AuthCtx ::= "AAuthCtxOf" "(" Map ")" [function, total]
  rule AAuthCtxOf(P:Map) => authCtx(ACtxOf(P), AAnchor)

  // ---- negatives --------------------------------------------------------------
  syntax Map ::= "AP1" [function, total]     // neg1: extra key (2,9):=999
  rule AP1 => LinSetKV(AP, 2, 9, 999)

  syntax Map ::= "AE7" [function, total]     // neg3: hidden write, L7-consistent
  rule AE7 => LinSetKV(AE, 2, 9, 999)
  syntax Map ::= "AP7" [function, total]     // post WITH the hidden write,
  rule AP7 => LinSetKV(AP, 2, 9, 999)        // built independently of any apply

  syntax Bytes ::= "AForgeSR" [function, total]  // neg2: root over PRE-content
  rule AForgeSR => AuthRootOf(AUni, AQ)

  syntax Bytes ::= "AStaleAnchor" [function, total]  // neg4: stale anchor
  rule AStaleAnchor => AuthRootOf(AUni, AQ)

  syntax LinRecE ::= "AHonestRecE" [function, total]
  rule AHonestRecE => AuthBuildRecE(1, LinRoot, AQ, AE, AP, LinDemoKey1, 5)

  syntax LinRecE ::= "ANeg5RecE" [function, total]   // childE byte flip
  rule ANeg5RecE
    => linRecE( linRecOfE(AHonestRecE), linStateRootOf(AHonestRecE)
              , LinXorByte(linChildEOf(AHonestRecE), 0) )

  syntax String ::= AGateCase ( LinRecE , Map ) [function, total]
  rule AGateCase(RE:LinRecE, P:Map)
    => VerifyLineageA(RE, AAuthCtxOf(P), 1, LinRoot)

  syntax String ::= "ANeg4Case" "(" ")" [function, total]
  rule ANeg4Case()
    => VerifyLineageA( AHonestRecE, authCtx(ACtxOf(AP), AStaleAnchor)
                     , 1, LinRoot )

  // applyfix scenario: the effect writes a NEW slot (1,1):=7 absent from QX
  syntax Map ::= "QX" [function, total]
  rule QX => LinKV1(1, 0, 100)
  syntax Map ::= "EX" [function, total]
  rule EX => LinSetKV(LinKV1(1, 0, 50), 1, 1, 7)
  syntax Map ::= "AX" [function, total]      // independent honest post
  rule AX => LinSetKV(LinKV1(1, 0, 50), 1, 1, 7)

  syntax String ::= "AGATE" [function, total]
  rule AGATE
    => "pos="     +String AGateCase( AHonestRecE, AP )
       +String ";neg1="    +String AGateCase( AuthBuildRecE(1, LinRoot, AQ, AE, AP1, LinDemoKey1, 5), AP1 )
       +String ";neg2="    +String AGateCase( linRecE( linRecOfE(AHonestRecE), AForgeSR
                                                     , AuthChildE(linRecOfE(AHonestRecE), AForgeSR) )
                                             , AP )
       +String ";neg3="    +String ANeg3Case()
       +String ";neg4="    +String ANeg4Case()
       +String ";neg5="    +String AGateCase( ANeg5RecE, AP )
       +String ";chain="   +String AChainCase()
       +String "|applyfix:old=" +String Bool2StringA( BytesEq( LinCanonKV(AX)
                                                              , LinCanonKV(LinApplyEff(QX, EX)) ) )
       +String ",new="     +String Bool2StringA( BytesEq( LinCanonKV(AX)
                                                        , LinCanonKV(LinApplyEff2(QX, EX)) ) )
       +String ",oldmain=" +String Bool2StringA( BytesEq( LinCanonKV(AP)
                                                        , LinCanonKV(LinApplyEff(AQ, AE)) ) )
       +String ",newmain=" +String Bool2StringA( BytesEq( LinCanonKV(AP)
                                                        , LinCanonKV(LinApplyEff2(AQ, AE)) ) )
       +String "|proofs:"  +String AProofs()

  // ---- E5: two-transition chain with root threading ---------------------------
  // transition 2 anchored at the authoritative root of transition 2; its
  // parent commitment is the extended child commitment of transition 1.
  syntax Map ::= "AE2" [function, total]
  rule AE2 => LinSetKV(LinKV1(1, 0, 5), 3, 4, 11)
  syntax Map ::= "AP2" [function, total]
  rule AP2 => LinApplyEff(AP, AE2)
  syntax List ::= "AUni2" [function, total]
  rule AUni2 => AuthUnion3(AuthKeysOfMap(AP), AuthKeysOfMap(AE2),
                           AuthKeysOfMap(AP2))
  syntax Bytes ::= "AAnchor2" [function, total]
  rule AAnchor2 => AuthRootOf(AUni2, AP2)
  syntax LinRecE ::= "ARec2E" [function, total]
  rule ARec2E
    => linRecE( LinBuildRec(2, linChildEOf(AHonestRecE), AP, AE2, AP2, LinDemoKey1, 5)
              , AAnchor2
              , AuthChildE( LinBuildRec(2, linChildEOf(AHonestRecE), AP, AE2, AP2, LinDemoKey1, 5)
                          , AAnchor2 ) )
  syntax String ::= "AChainCase" "(" ")" [function, total]
  rule AChainCase()
    => VerifyLineageA( ARec2E
                     , authCtx( linCtxP(AP, AE2, AP2, AReg, AAuth), AAnchor2 )
                     , 2, linChildEOf(AHonestRecE) )
       +String ";stale-replay="
       +String VerifyLineageA( ARec2E
                             , authCtx( linCtxP(AP, AE2, AP2, AReg, AAuth), AAnchor )
                             , 2, linChildEOf(AHonestRecE) )

  // neg3 (CM-E7): the producer PRESENTS the forged-but-consistent artifacts
  // (pre=Q, eff'=E∪{(2,9):999}, post'=Apply(Q,eff')) — the verifier consumes
  // exactly what travels with the record; the anchor is the HONEST one.
  syntax String ::= "ANeg3Case" "(" ")" [function, total]
  rule ANeg3Case()
    => VerifyLineageA( AuthBuildRecE(1, LinRoot, AQ, AE7, AP7, LinDemoKey1, 5)
                     , authCtx( linCtxP(AQ, AE7, AP7, AReg, AAuth), AAnchor )
                     , 1, LinRoot )

  // ---- AUTH-READ / AUTH-UPDATE concrete checks -------------------------------
  syntax Int ::= "AK21" [function, total]    // flat key (2,1)
  rule AK21 => 2 *Int AuthTwo32() +Int 1

  syntax Int ::= "AK35" [function, total]    // flat key (3,5) — ABSENT in APabs
  rule AK35 => 3 *Int AuthTwo32() +Int 5

  // absent-key non-membership scenario: (3,5) in universe, absent in post
  syntax Map ::= "AQabs" [function, total]
  rule AQabs => LinSetKV(LinKV1(1, 0, 100), 3, 5, 10)
  syntax Map ::= "APabs" [function, total]
  rule APabs => LinKV1(1, 0, 25)
  syntax List ::= "AUniAbs" [function, total]
  rule AUniAbs => AuthUnion3(AuthKeysOfMap(AQabs), AuthKeysOfMap(.Map),
                             AuthKeysOfMap(APabs))
  syntax Bytes ::= "AAnchorAbs" [function, total]
  rule AAnchorAbs => AuthRootOf(AUniAbs, APabs)

  syntax String ::= "AProofs" "(" ")" [function, total]
  rule AProofs()
    => "incl="     +String Bool2StringA( AuthVerifyIncl( AAnchor, AK21, 1, 7
                                                       , AuthIndexOf(AK21, AUni)
                                                       , AuthProofOf(AUni, AP, AK21) ) )
       +String ",forged="  +String Bool2StringA( AuthVerifyIncl( AAnchor, AK21, 1, 8
                                                       , AuthIndexOf(AK21, AUni)
                                                       , AuthProofOf(AUni, AP, AK21) ) )
       +String ",update-eq=" +String Bool2StringA(
             BytesEq( AuthUpdateRoot( AAnchor, AK21, 1, 7, 42
                                    , AuthIndexOf(AK21, AUni)
                                    , AuthProofOf(AUni, AP, AK21) )
                    , AuthTreeUpdateRoot(AUni, AP, AK21, 42) ) )
       +String ",nonmemb=" +String Bool2StringA( AuthVerifyIncl( AAnchorAbs, AK35, 0, 0
                                                       , AuthIndexOf(AK35, AUniAbs)
                                                       , AuthProofOf(AUniAbs, APabs, AK35) ) )
       +String ",forged-pres=" +String Bool2StringA( AuthVerifyIncl( AAnchorAbs, AK35, 1, 10
                                                       , AuthIndexOf(AK35, AUniAbs)
                                                       , AuthProofOf(AUniAbs, APabs, AK35) ) )
       +String "|bytes:root=" +String Int2String(Bytes2Int(AAnchor, BE, Unsigned))
       +String ",stateroot=" +String Int2String(Bytes2Int(linStateRootOf(AHonestRecE), BE, Unsigned))
       +String ",childe=" +String Int2String(Bytes2Int(linChildEOf(AHonestRecE), BE, Unsigned))
       +String ",child=" +String Int2String(Bytes2Int(linChildOf(linRecOfE(AHonestRecE)), BE, Unsigned))
       +String ",proof=" +String Int2String(Bytes2Int(AuthProofOf(AUni, AP, AK21), BE, Unsigned))

  syntax String ::= Bool2StringA ( Bool ) [function, total]
  rule Bool2StringA(true)  => "true"
  rule Bool2StringA(false) => "false"

  syntax Map ::= LinKV1 ( Int , Int , Int ) [function, total]
  rule LinKV1(A:Int, S:Int, V:Int) => A |-> (S |-> V)

  rule <k> asuite => .K ... </k>
       <aresult> "" => AGATE </aresult>

endmodule
