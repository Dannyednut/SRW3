// =============================================================================
// SRW3 Phase 1E — Authenticated state and state-commitment binding
//                          (phase1e/semantics/srw3auth.k — ADDITIVE)
//
// Normative model spec: phase1e/semantics/MODEL.md (FROZEN).
//
// The frozen Phase 1D-R1 modules (srw3lin{,-verify,-r1}.k) are NOT modified.
// This module is purely additive (linCtxP precedent):
//
//   * minimal authenticated-state model: a FIXED-DEPTH (D=8, 256-leaf)
//     binary Merkle tree over the canonical key universe of a record
//       U = sort( keys(pre) ∪ keys(effects) ∪ keys(post) )   (flattened keys)
//     with explicit content-binding inclusion/non-membership proofs and
//     explicit proof-based updates. This is NOT an Ethereum MPT and no
//     trie/MPT property is claimed.
//
//   * extended record (strictly additive): LinRecE = (LinRec, stateRoot, childE)
//       CanonCoreE = LinCanonFull(legacy 11 fields incl. Sig) || stateRoot
//       childE     = Keccak256(CanonCoreE)
//     the legacy canonical bytes are a strict PREFIX of the extended ones;
//     the legacy 12-layer chain runs UNCHANGED on the legacy projection.
//
//   * extended verifier chain VerifyLineageA — first-fail:
//       [legacy 12 verdicts, unchanged]           (fire first)
//       "invalid-capacity"   |U| > 256            (model REFUSE, explicit)
//       "invalid-padkey"     a real key == PAD    (model REFUSE, explicit)
//       "invalid-state-root" stateRoot != AuthRoot(U, presentedPost)   [Mode S]
//       "invalid-anchor"     stateRoot != anchor                        [Mode A]
//       "invalid-childe"     childE != Keccak256(CanonCoreE)
//       "valid-a"
//     The ANCHOR is an explicit context input standing for an independently
//     published authoritative state commitment. Its PROVENANCE is not
//     mechanized here (ASSUMED / REQUIRES CLIENT/PROTOCOL SUPPORT).
//
// Backend note: Keccak256raw evaluates on the LLVM backend via the Phase-1C
// krypto shim (pinned libsecp256k1 path). Structural claims (proofs/*.k) are
// proved on the Haskell backend over the walk functions, which do not
// require hash evaluation (hash applications are kept as uninterpreted
// terms; the claimed equalities are structural).
// =============================================================================

requires "srw3lin-r1.k"

module SRW3AUTH
  imports SRW3LIN-R1

  // ===========================================================================
  // §0. FINDING 1E-LINAPPLY-MULTISLOT and the ADDITIVE composition fix
  // ===========================================================================
  // The frozen Phase 1D-R1 LinApplyEff (srw3lin-r1.k) applies exactly ONE
  // SLOT PER ACCOUNT of the effects map: its account-level recursion removes
  // the whole account after its MINIMUM-KEY slot is written, silently
  // dropping that account's remaining slots. The Phase 1D-R1 K composition
  // suite did not expose this because its positive case DEFINED the honest
  // post-state as LinApplyEff(Q, E) itself (the compared terms coincided);
  // the Python verifier's apply_effects was always correct (per-slot).
  // Exposure: the Phase 1E KEVM binding, where true effects have multi-slot
  // accounts. Classification: completeness defect (honest multi-slot records
  // are falsely rejected by the frozen K composition check); it does NOT
  // weaken the 1D-R1 soundness claims (extra/missing/changed entries remain
  // rejected; the Python layer governed the permanent L7 suite). Fix is
  // ADDITIVE, in this Phase 1E module: LinApplyEff2 + VerifyLineagePE
  // (composition-aware chain with the corrected apply). Frozen modules are
  // untouched; the Phase 1E chain uses the corrected base.

  syntax Map ::= LinApplySlots2 ( Map , Map ) [function, total]
  rule LinApplySlots2(S:Map, .Map) => S
  rule LinApplySlots2(S:Map, M:Map)
    => LinApplySlots2( S[MinKeyOfMap(M) <- LinIntAt(M, MinKeyOfMap(M))]
                     , M[MinKeyOfMap(M) <- undef] )
    requires sizeMap(M) >=Int 1

  syntax Map ::= LinApplyEff2 ( Map , Map ) [function, total]
  rule LinApplyEff2(P:Map, .Map) => P
  rule LinApplyEff2(P:Map, E:Map)
    => LinApplyEff2( P[MinKeyOfMap(E) <- LinApplySlots2(LinMapAt(P, MinKeyOfMap(E)),
                                                        LinMapAt(E, MinKeyOfMap(E)))]
                   , E[MinKeyOfMap(E) <- undef] )
    requires sizeMap(E) >=Int 1

  // corrected composition predicate (same canonical byte-equality discipline)
  syntax Bool ::= LinCompositionOk2 ( Map , Map , Map ) [function, total]
  rule LinCompositionOk2(Pre:Map, Eff:Map, Post:Map)
    => BytesEq( LinCanonKV(Post)
              , LinCanonKV(LinApplyEff2(Pre, Eff)) )

  // composition-aware chain with the corrected apply (the Phase 1E base)
  syntax String ::= VerifyLineagePE ( LinRec , LinCtx , Int , Bytes ) [function, total]

  rule VerifyLineagePE(R:LinRec, CTX:LinCtx, T:Int, HEAD:Bytes)
    => VerifyLineage(R, CTX, T, HEAD)
    requires notBool VerifyLineage(R, CTX, T, HEAD) ==String "valid"

  rule VerifyLineagePE(R:LinRec, CTX:LinCtx, T:Int, HEAD:Bytes)
    => "invalid-state-composition"
    requires VerifyLineage(R, CTX, T, HEAD) ==String "valid"
     andBool notBool LinCompositionOk2( linCtxInputs(CTX)
                                      , linCtxEffects(CTX)
                                      , linCtxState(CTX) )

  rule VerifyLineagePE(R:LinRec, CTX:LinCtx, T:Int, HEAD:Bytes)
    => "valid"
    requires VerifyLineage(R, CTX, T, HEAD) ==String "valid"
     andBool LinCompositionOk2( linCtxInputs(CTX)
                              , linCtxEffects(CTX)
                              , linCtxState(CTX) )

  // ===========================================================================
  // §1. Flattened keys and the canonical key universe
  // ===========================================================================

  syntax Int ::= AuthTwo32 () [function, total]
  rule AuthTwo32() => 4294967296

  syntax Int ::= AuthAppOf ( Int ) [function, total]
  rule AuthAppOf(K:Int) => K /Int AuthTwo32()

  syntax Int ::= AuthSlotOf ( Int ) [function, total]
  rule AuthSlotOf(K:Int) => K modInt AuthTwo32()

  // reserved pad key = (2^32-1)*2^32 + (2^32-1) = 2^64-1
  syntax Int ::= AuthPadKey () [function, total]
  rule AuthPadKey() => 18446744073709551615

  // sorted, deduplicated insert (LinAppIns pattern, flat-key domain)
  syntax List ::= AuthKIns ( List , Int ) [function, total]
  rule AuthKIns(.List, K:Int) => ListItem(K)
  rule AuthKIns(ListItem(X:Int) REST:List, K:Int) => ListItem(X) REST
    requires K ==Int X
  rule AuthKIns(ListItem(X:Int) REST:List, K:Int) => ListItem(K) ListItem(X) REST
    requires K <Int X
  rule AuthKIns(ListItem(X:Int) REST:List, K:Int) => ListItem(X) AuthKIns(REST, K)
    requires K >Int X

  // all flattened keys of a nested state map, sorted + deduplicated
  syntax List ::= AuthKeysOfMap ( Map ) [function, total]
  rule AuthKeysOfMap(.Map) => .List
  rule AuthKeysOfMap(M:Map)
    => AuthInsSlots(MinKeyOfMap(M), LinMapAt(M, MinKeyOfMap(M)),
                    AuthKeysOfMap(M[MinKeyOfMap(M) <- undef]))
    requires sizeMap(M) >=Int 1

  syntax List ::= AuthInsSlots ( Int , Map , List ) [function, total]
  rule AuthInsSlots(_A:Int, .Map, L:List) => L
  rule AuthInsSlots(A:Int, S:Map, L:List)
    => AuthInsSlots(A, S[MinKeyOfMap(S) <- undef],
                    AuthKIns(L, A *Int AuthTwo32() +Int MinKeyOfMap(S)))
    requires sizeMap(S) >=Int 1

  // union of three key lists (insertion keeps sorted+deduplicated invariant)
  syntax List ::= AuthInsList ( List , List ) [function, total]
  rule AuthInsList(L:List, .List) => L
  rule AuthInsList(L:List, ListItem(K:Int) REST:List)
    => AuthInsList(AuthKIns(L, K), REST)

  syntax List ::= AuthUnion3 ( List , List , List ) [function, total]
  rule AuthUnion3(A:List, B:List, C:List)
    => AuthInsList(AuthInsList(A, B), C)

  // universe of a verification context (determined by the artifacts the
  // record already digests — no new producer freedom)
  syntax List ::= AuthUniverseOf ( AuthCtx ) [function, total]
  rule AuthUniverseOf(C:AuthCtx)
    => AuthUnion3(AuthKeysOfMap(linCtxInputs(authCtxLin(C))),
                  AuthKeysOfMap(linCtxEffects(authCtxLin(C))),
                  AuthKeysOfMap(linCtxState(authCtxLin(C))))

  syntax Int ::= AuthListAt ( List , Int ) [function, total]
  rule AuthListAt(ListItem(X:Int) _:List, I:Int) => X requires I ==Int 0
  rule AuthListAt(ListItem(_:Int) REST:List, I:Int) => AuthListAt(REST, I -Int 1)
    requires I >Int 0
  rule AuthListAt(.List, _:Int) => 0 -Int 1

  syntax Bytes ::= AuthBListAt ( List , Int ) [function, total]
  rule AuthBListAt(ListItem(X:Bytes) _:List, I:Int) => X requires I ==Int 0
  rule AuthBListAt(ListItem(_:Bytes) REST:List, I:Int) => AuthBListAt(REST, I -Int 1)
    requires I >Int 0
  rule AuthBListAt(.List, _:Int) => Int2Bytes(32, 0, BE)

  syntax Bool ::= AuthKeyInList ( Int , List ) [function, total]
  rule AuthKeyInList(_K:Int, .List) => false
  rule AuthKeyInList(K:Int, ListItem(X:Int) _:List) => true requires K ==Int X
  rule AuthKeyInList(K:Int, ListItem(X:Int) REST:List) => AuthKeyInList(K, REST)
    requires K =/=Int X

  // ===========================================================================
  // §2. Leaf / node encodings and the tree
  // ===========================================================================

  // leafBytes(k, pres, v) = 0x00 || app4 || slot4 || pres || v4
  syntax Bytes ::= AuthLeafBytes ( Int , Int , Int ) [function, total]
  rule AuthLeafBytes(K:Int, PRES:Int, V:Int)
    => Int2Bytes(1, 0, BE) +Bytes I2B4(AuthAppOf(K)) +Bytes I2B4(AuthSlotOf(K))
       +Bytes Int2Bytes(1, PRES, BE) +Bytes I2B4(V)

  // nodeBytes(l, r) = 0x01 || l || r   (l, r are 32-byte digests)
  syntax Bytes ::= AuthNodeBytes ( Bytes , Bytes ) [function, total]
  rule AuthNodeBytes(L:Bytes, R:Bytes) => Int2Bytes(1, 1, BE) +Bytes L +Bytes R

  syntax Bytes ::= AuthNodeHash ( Bytes , Bytes ) [function]
  rule AuthNodeHash(L:Bytes, R:Bytes) => LinH(AuthNodeBytes(L, R))

  syntax Bool ::= AuthSlotIn ( Map , Int , Int ) [function, total]
  rule AuthSlotIn(POST:Map, A:Int, S:Int) => S in_keys(LinMapAt(POST, A))

  syntax Int ::= AuthValAt ( Map , Int ) [function, total]
  rule AuthValAt(POST:Map, K:Int)
    => LinIntAt(LinMapAt(POST, AuthAppOf(K)), AuthSlotOf(K))

  // leaf bytes at universe position I (I >= |U| => PAD leaf, presence 0)
  syntax Bytes ::= AuthLeafBytesAt ( List , Map , Int ) [function, total]
  rule AuthLeafBytesAt(U:List, POST:Map, I:Int)
    => AuthLeafBytes(AuthUAt(U, I), 1, AuthValAt(POST, AuthUAt(U, I)))
    requires AuthSlotIn(POST, AuthAppOf(AuthUAt(U, I)), AuthSlotOf(AuthUAt(U, I)))
  rule AuthLeafBytesAt(U:List, POST:Map, I:Int)
    => AuthLeafBytes(AuthUAt(U, I), 0, 0)
    requires notBool AuthSlotIn(POST, AuthAppOf(AuthUAt(U, I)),
                                     AuthSlotOf(AuthUAt(U, I)))

  syntax Int ::= AuthUAt ( List , Int ) [function, total]
  rule AuthUAt(U:List, I:Int) => AuthListAt(U, I)
    requires I >=Int 0 andBool I <Int size(U)
  rule AuthUAt(U:List, I:Int) => AuthPadKey() requires I >=Int size(U)

  // the 256 leaf hashes, ascending index
  syntax List ::= AuthLeafList ( List , Map , Int ) [function, total]
  rule AuthLeafList(U:List, POST:Map, I:Int)
    => ListItem(Keccak256raw(AuthLeafBytesAt(U, POST, I))) AuthLeafList(U, POST, I +Int 1)
    requires I <Int 256
  rule AuthLeafList(_U:List, _POST:Map, I:Int) => .List requires I >=Int 256

  syntax List ::= AuthLevelUp ( List ) [function, total]
  rule AuthLevelUp(.List) => .List
  rule AuthLevelUp(ListItem(A:Bytes)) => ListItem(A)
  rule AuthLevelUp(ListItem(A:Bytes) ListItem(B:Bytes) REST:List)
    => ListItem(AuthNodeHash(A, B)) AuthLevelUp(REST)

  syntax Bytes ::= AuthRootFrom ( List ) [function, total]
  rule AuthRootFrom(L:List) => AuthRootFrom(AuthLevelUp(L)) requires size(L) >=Int 2
  rule AuthRootFrom(ListItem(A:Bytes)) => A
  rule AuthRootFrom(.List) => Int2Bytes(32, 0, BE)

  syntax Bytes ::= AuthRootOf ( List , Map ) [function, total]
  rule AuthRootOf(U:List, POST:Map) => AuthRootFrom(AuthLeafList(U, POST, 0))

  // full canonical tree byte string (injective representation of (U, POST)):
  //   0x02 || depth4 || |U|4 || leafBytes*256
  syntax Bytes ::= AuthTreeBytes ( List , Map ) [function, total]
  rule AuthTreeBytes(U:List, POST:Map)
    => AuthTB(U, POST, 0, Int2Bytes(1, 2, BE) +Bytes I2B4(8) +Bytes I2B4(size(U)))
  syntax Bytes ::= AuthTB ( List , Map , Int , Bytes ) [function, total]
  rule AuthTB(U:List, POST:Map, I:Int, ACC:Bytes)
    => AuthTB(U, POST, I +Int 1, ACC +Bytes AuthLeafBytesAt(U, POST, I))
    requires I <Int 256
  rule AuthTB(_U:List, _POST:Map, I:Int, ACC:Bytes) => ACC requires I >=Int 256

  // ===========================================================================
  // §3. Content-binding proofs and the verification walk
  // ===========================================================================

  syntax Int ::= AuthIndexOf ( Int , List ) [function, total]
  rule AuthIndexOf(K:Int, U:List) => AuthIOAux(U, K, 0)
  syntax Int ::= AuthIOAux ( List , Int , Int ) [function, total]
  rule AuthIOAux(.List, _K:Int, _I:Int) => 0 -Int 1
  rule AuthIOAux(ListItem(K:Int) _:List, K2:Int, I:Int) => I requires K ==Int K2
  rule AuthIOAux(ListItem(K:Int) REST:List, K2:Int, I:Int) => AuthIOAux(REST, K2, I +Int 1)
    requires K =/=Int K2

  syntax Int ::= AuthSibIdx ( Int ) [function, total]
  rule AuthSibIdx(I:Int) => I +Int 1 requires I modInt 2 ==Int 0
  rule AuthSibIdx(I:Int) => I -Int 1 requires I modInt 2 ==Int 1

  syntax Bytes ::= AuthSibAt ( List , Int ) [function, total]
  rule AuthSibAt(L:List, I:Int) => AuthBListAt(L, AuthSibIdx(I))

  // proof construction from the producer-side tree (siblings bottom-up)
  syntax Bytes ::= AuthProofOf ( List , Map , Int ) [function, total]
  rule AuthProofOf(U:List, POST:Map, K:Int)
    => AuthPFAux(U, POST, AuthLeafList(U, POST, 0), AuthIndexOf(K, U),
                 AuthIndexOf(K, U), 0, .Bytes)
    requires AuthIndexOf(K, U) >=Int 0
  rule AuthProofOf(U:List, _POST:Map, K:Int) => .Bytes
    requires AuthIndexOf(K, U) <Int 0

  syntax Bytes ::= AuthPFAux ( List , Map , List , Int , Int , Int , Bytes ) [function, total]
  rule AuthPFAux(U:List, POST:Map, CUR:List, IDX0:Int, I:Int, D:Int, ACC:Bytes)
    => AuthPFAux(U, POST, AuthLevelUp(CUR), IDX0, I /Int 2, D +Int 1,
                 ACC +Bytes AuthSibAt(CUR, I))
    requires D <Int 8
  rule AuthPFAux(_U:List, _POST:Map, _CUR:List, IDX0:Int, _I:Int, D:Int, ACC:Bytes)
    => I2B4(IDX0) +Bytes ACC
    requires D >=Int 8

  // the verification walk (LSB-first bit consumption; siblings bottom-up)
  syntax Bytes ::= AuthWalkAux ( Bytes , Int , Int , Bytes ) [function, total]
  rule AuthWalkAux(H:Bytes, _IDX:Int, D:Int, _PR:Bytes) => H requires D >=Int 8
  rule AuthWalkAux(H:Bytes, IDX:Int, D:Int, PR:Bytes)
    => AuthWalkAux( AuthWalkStep(H, substrBytes(PR, 4 +Int 32 *Int D, 36 +Int 32 *Int D),
                                 IDX modInt 2)
                  , IDX /Int 2, D +Int 1, PR)
    requires D <Int 8

  syntax Bytes ::= AuthWalkStep ( Bytes , Bytes , Int ) [function, total]
  rule AuthWalkStep(H:Bytes, S:Bytes, B:Int) => AuthNodeHash(H, S) requires B ==Int 0
  rule AuthWalkStep(H:Bytes, S:Bytes, B:Int) => AuthNodeHash(S, H) requires B ==Int 1

  syntax Bytes ::= AuthWalkRoot ( Int , Int , Int , Int , Bytes ) [function, total]
  rule AuthWalkRoot(K:Int, PRES:Int, V:Int, IDX:Int, PR:Bytes)
    => AuthWalkAux(Keccak256raw(AuthLeafBytes(K, PRES, V)), IDX, 0, PR)

  syntax Bool ::= AuthProofWF ( Int , Int , Int , Bytes ) [function, total]
  rule AuthProofWF(IDX:Int, PRES:Int, V:Int, PR:Bytes)
    => lengthBytes(PR) ==Int 260
       andBool IDX >=Int 0 andBool IDX <Int 256
       andBool (PRES ==Int 0 orBool PRES ==Int 1)
       andBool (PRES ==Int 1 orBool V ==Int 0)

  // AUTH-READ verification: accepts iff the walked root equals R
  syntax Bool ::= AuthVerifyIncl ( Bytes , Int , Int , Int , Int , Bytes ) [function, total]
  rule AuthVerifyIncl(R:Bytes, K:Int, PRES:Int, V:Int, IDX:Int, PR:Bytes)
    => BytesEq(AuthWalkRoot(K, PRES, V, IDX, PR), R)
    requires AuthProofWF(IDX, PRES, V, PR)
  rule AuthVerifyIncl(R:Bytes, K:Int, PRES:Int, V:Int, IDX:Int, PR:Bytes)
    => false
    requires notBool AuthProofWF(IDX, PRES, V, PR)

  // AUTH-UPDATE: proof-based update (requires the old-content proof to verify)
  syntax Bytes ::= AuthUpdateRoot ( Bytes , Int , Int , Int , Int , Int , Bytes ) [function, total]
  rule AuthUpdateRoot(R:Bytes, K:Int, PRES:Int, V:Int, VNEW:Int, IDX:Int, PR:Bytes)
    => AuthWalkRoot(K, 1, VNEW, IDX, PR)
    requires AuthVerifyIncl(R, K, PRES, V, IDX, PR)
  rule AuthUpdateRoot(R:Bytes, K:Int, PRES:Int, V:Int, VNEW:Int, IDX:Int, PR:Bytes)
    => .Bytes
    requires notBool AuthVerifyIncl(R, K, PRES, V, IDX, PR)

  // producer-side update: full tree rebuild under the updated post
  syntax Bytes ::= AuthTreeUpdateRoot ( List , Map , Int , Int ) [function, total]
  rule AuthTreeUpdateRoot(U:List, POST:Map, K:Int, VNEW:Int)
    => AuthRootOf(U, LinSetKV(POST, AuthAppOf(K), AuthSlotOf(K), VNEW))
    requires AuthIndexOf(K, U) >=Int 0
  rule AuthTreeUpdateRoot(U:List, _POST:Map, K:Int, _VNEW:Int) => .Bytes
    requires AuthIndexOf(K, U) <Int 0

  // ===========================================================================
  // §4. Model REFUSE predicates (explicit, never silent)
  // ===========================================================================

  syntax Bool ::= AuthCapacityOk ( List ) [function, total]
  rule AuthCapacityOk(U:List) => size(U) <=Int 256

  syntax Bool ::= AuthPadOk ( List ) [function, total]
  rule AuthPadOk(U:List) => notBool AuthKeyInList(AuthPadKey(), U)

  // ===========================================================================
  // §5. The extended record LinRecE = (LinRec, stateRoot, childE)  [ADDITIVE]
  // ===========================================================================

  syntax LinRecE ::= linRecE ( base:LinRec , stateRoot:Bytes , childE:Bytes )

  syntax LinRec ::= linRecOfE ( LinRecE ) [function]
  rule linRecOfE(linRecE(R:LinRec, _:Bytes, _:Bytes)) => R

  syntax Bytes ::= linStateRootOf ( LinRecE ) [function]
  rule linStateRootOf(linRecE(_:LinRec, SR:Bytes, _:Bytes)) => SR

  syntax Bytes ::= linChildEOf ( LinRecE ) [function]
  rule linChildEOf(linRecE(_:LinRec, _:Bytes, CE:Bytes)) => CE

  // CanonCoreE = LinCanonFull(legacy 11 incl. Sig) || stateRoot  (prefix rule)
  syntax Bytes ::= AuthCanonCoreE ( LinRec , Bytes ) [function]
  rule AuthCanonCoreE(R:LinRec, SR:Bytes)
    => LinCanonFull(linVersionOf(R), linParentOf(R), linTidOf(R), linAppsOf(R),
                    linInputDOf(R), linEffectDOf(R), linStateDOf(R),
                    linPolicyVOf(R), linAuthOf(R), linEvOf(R), linSigOf(R))
       +Bytes SR

  syntax Bytes ::= AuthChildE ( LinRec , Bytes ) [function]
  rule AuthChildE(R:LinRec, SR:Bytes) => LinH(AuthCanonCoreE(R, SR))

  // honest extended-record construction
  syntax LinRecE ::= AuthBuildRecE ( Int , Bytes , Map , Map , Map , Bytes , Int ) [function]
  rule AuthBuildRecE(N:Int, HEAD:Bytes, Q:Map, E:Map, P:Map, KEY:Bytes, PV:Int)
    => linRecE( LinBuildRec(N, HEAD, Q, E, P, KEY, PV)
              , AuthRootOf(AuthUnion3(AuthKeysOfMap(Q), AuthKeysOfMap(E),
                                      AuthKeysOfMap(P)), P)
              , AuthChildE( LinBuildRec(N, HEAD, Q, E, P, KEY, PV)
                          , AuthRootOf(AuthUnion3(AuthKeysOfMap(Q), AuthKeysOfMap(E),
                                                  AuthKeysOfMap(P)), P) ) )

  // ===========================================================================
  // §6. The extended verification context (LinCtx + anchor)  [ADDITIVE]
  // ===========================================================================

  syntax AuthCtx ::= authCtx ( ctx:LinCtx , authAnchor:Bytes )

  syntax LinCtx ::= authCtxLin ( AuthCtx ) [function]
  rule authCtxLin(authCtx(C:LinCtx, _:Bytes)) => C

  syntax Bytes ::= authCtxAnchor ( AuthCtx ) [function]
  rule authCtxAnchor(authCtx(_C:LinCtx, A:Bytes)) => A

  // ===========================================================================
  // §7. Extension layers and VerifyLineageA (first-fail, total)
  // ===========================================================================

  syntax Bool ::= AuthStateRootOk ( LinRecE , AuthCtx ) [function, total]
  rule AuthStateRootOk(RE:LinRecE, C:AuthCtx)
    => BytesEq(linStateRootOf(RE),
               AuthRootOf(AuthUniverseOf(C), linCtxState(authCtxLin(C))))

  syntax Bool ::= AuthAnchorOk ( LinRecE , AuthCtx ) [function, total]
  rule AuthAnchorOk(RE:LinRecE, C:AuthCtx)
    => BytesEq(linStateRootOf(RE), authCtxAnchor(C))

  syntax Bool ::= AuthChildEOk ( LinRecE ) [function, total]
  rule AuthChildEOk(RE:LinRecE)
    => BytesEq(linChildEOf(RE), AuthChildE(linRecOfE(RE), linStateRootOf(RE)))

  syntax String ::= VerifyLineageA ( LinRecE , AuthCtx , Int , Bytes ) [function, total]

  // The legacy base of the chain is VerifyLineagePE — the composition-aware
  // chain with the CORRECTED apply (§0). This mirrors the Python verifier,
  // whose legacy chain INCLUDES the L7 exact map equality computed with the
  // correct per-slot apply_effects (Python L7-STATE <-> K
  // "invalid-state-composition").
  rule VerifyLineageA(RE:LinRecE, C:AuthCtx, T:Int, HEAD:Bytes)
    => VerifyLineagePE(linRecOfE(RE), authCtxLin(C), T, HEAD)
    requires notBool VerifyLineagePE(linRecOfE(RE), authCtxLin(C), T, HEAD)
                                        ==String "valid"

  rule VerifyLineageA(RE:LinRecE, C:AuthCtx, T:Int, HEAD:Bytes)
    => "invalid-capacity"
    requires VerifyLineagePE(linRecOfE(RE), authCtxLin(C), T, HEAD) ==String "valid"
             andBool notBool AuthCapacityOk(AuthUniverseOf(C))

  rule VerifyLineageA(RE:LinRecE, C:AuthCtx, T:Int, HEAD:Bytes)
    => "invalid-padkey"
    requires VerifyLineagePE(linRecOfE(RE), authCtxLin(C), T, HEAD) ==String "valid"
             andBool AuthCapacityOk(AuthUniverseOf(C))
             andBool notBool AuthPadOk(AuthUniverseOf(C))

  rule VerifyLineageA(RE:LinRecE, C:AuthCtx, T:Int, HEAD:Bytes)
    => "invalid-state-root"
    requires VerifyLineagePE(linRecOfE(RE), authCtxLin(C), T, HEAD) ==String "valid"
             andBool AuthCapacityOk(AuthUniverseOf(C))
             andBool AuthPadOk(AuthUniverseOf(C))
             andBool notBool AuthStateRootOk(RE, C)

  rule VerifyLineageA(RE:LinRecE, C:AuthCtx, T:Int, HEAD:Bytes)
    => "invalid-anchor"
    requires VerifyLineagePE(linRecOfE(RE), authCtxLin(C), T, HEAD) ==String "valid"
             andBool AuthCapacityOk(AuthUniverseOf(C))
             andBool AuthPadOk(AuthUniverseOf(C))
             andBool AuthStateRootOk(RE, C)
             andBool notBool AuthAnchorOk(RE, C)

  rule VerifyLineageA(RE:LinRecE, C:AuthCtx, T:Int, HEAD:Bytes)
    => "invalid-childe"
    requires VerifyLineagePE(linRecOfE(RE), authCtxLin(C), T, HEAD) ==String "valid"
             andBool AuthCapacityOk(AuthUniverseOf(C))
             andBool AuthPadOk(AuthUniverseOf(C))
             andBool AuthStateRootOk(RE, C)
             andBool AuthAnchorOk(RE, C)
             andBool notBool AuthChildEOk(RE)

  rule VerifyLineageA(RE:LinRecE, C:AuthCtx, T:Int, HEAD:Bytes)
    => "valid-a"
    requires VerifyLineagePE(linRecOfE(RE), authCtxLin(C), T, HEAD) ==String "valid"
             andBool AuthCapacityOk(AuthUniverseOf(C))
             andBool AuthPadOk(AuthUniverseOf(C))
             andBool AuthStateRootOk(RE, C)
             andBool AuthAnchorOk(RE, C)
             andBool AuthChildEOk(RE)

  // Bool reflexivity (syntactic identity): used by the proof claims where
  // both sides of ==Bool reduce to the same (possibly stuck) Bool term.
  rule B:Bool ==Bool B => true [simplification]

  // ===========================================================================
  // §3b. Structured (sibling-list) form of the same proof data
  // ===========================================================================
  // The 260-byte proof format (§3) and the structured List form carry the
  // SAME data (index + 8 sibling digests, bottom-up). The byte-string form is
  // what travels on the wire and is exercised concretely (LLVM demo,
  // cross-layer byte checks); substrBytes does not reduce on symbolic Bytes,
  // so the SYMBOLIC claims (proofs/*.k) are stated over the List form, whose
  // reduction is purely structural. Both forms share AuthWalkStep /
  // AuthNodeHash — only the sibling EXTRACTION differs.

  syntax Bool ::= AuthProofWFList ( Int , Int , Int , List ) [function, total]
  rule AuthProofWFList(IDX:Int, PRES:Int, V:Int, SIBS:List)
    => size(SIBS) ==Int 8
       andBool IDX >=Int 0 andBool IDX <Int 256
       andBool (PRES ==Int 0 orBool PRES ==Int 1)
       andBool (PRES ==Int 1 orBool V ==Int 0)

  syntax Bytes ::= AuthWalkAuxList ( Bytes , Int , Int , List ) [function, total]
  rule AuthWalkAuxList(H:Bytes, _IDX:Int, D:Int, _SIBS:List) => H requires D >=Int 8
  rule AuthWalkAuxList(H:Bytes, IDX:Int, D:Int, ListItem(S:Bytes) REST:List)
    => AuthWalkAuxList( AuthWalkStep(H, S, IDX modInt 2)
                      , IDX /Int 2, D +Int 1, REST)
    requires D <Int 8

  syntax Bytes ::= AuthWalkRootList ( Int , Int , Int , Int , List ) [function, total]
  rule AuthWalkRootList(K:Int, PRES:Int, V:Int, IDX:Int, SIBS:List)
    => AuthWalkAuxList(Keccak256raw(AuthLeafBytes(K, PRES, V)), IDX, 0, SIBS)

  syntax Bool ::= AuthVerifyInclList ( Bytes , Int , Int , Int , Int , List ) [function, total]
  rule AuthVerifyInclList(R:Bytes, K:Int, PRES:Int, V:Int, IDX:Int, SIBS:List)
    => BytesEq(AuthWalkRootList(K, PRES, V, IDX, SIBS), R)
    requires AuthProofWFList(IDX, PRES, V, SIBS)
  rule AuthVerifyInclList(R:Bytes, K:Int, PRES:Int, V:Int, IDX:Int, SIBS:List)
    => false
    requires notBool AuthProofWFList(IDX, PRES, V, SIBS)

  syntax Bytes ::= AuthUpdateRootList ( Bytes , Int , Int , Int , Int , Int , List ) [function, total]
  rule AuthUpdateRootList(R:Bytes, K:Int, PRES:Int, V:Int, VNEW:Int, IDX:Int, SIBS:List)
    => AuthWalkRootList(K, 1, VNEW, IDX, SIBS)
    requires AuthVerifyInclList(R, K, PRES, V, IDX, SIBS)
  rule AuthUpdateRootList(R:Bytes, K:Int, PRES:Int, V:Int, VNEW:Int, IDX:Int, SIBS:List)
    => .Bytes
    requires notBool AuthVerifyInclList(R, K, PRES, V, IDX, SIBS)

  // producer-side sibling list from the tree (concrete companion of AuthProofOf)
  syntax List ::= AuthProofSibsOf ( List , Map , Int ) [function, total]
  rule AuthProofSibsOf(U:List, POST:Map, K:Int)
    => AuthPFSibs(U, POST, AuthLeafList(U, POST, 0), AuthIndexOf(K, U),
                  AuthIndexOf(K, U), 0, .List)
    requires AuthIndexOf(K, U) >=Int 0
  rule AuthProofSibsOf(U:List, _POST:Map, K:Int) => .List
    requires AuthIndexOf(K, U) <Int 0

  syntax List ::= AuthPFSibs ( List , Map , List , Int , Int , Int , List ) [function, total]
  rule AuthPFSibs(U:List, POST:Map, CUR:List, IDX0:Int, I:Int, D:Int, ACC:List)
    => AuthPFSibs(U, POST, AuthLevelUp(CUR), IDX0, I /Int 2, D +Int 1,
                  AppendListItem(AuthSibAt(CUR, I), ACC))
    requires D <Int 8
  rule AuthPFSibs(_U:List, _POST:Map, _CUR:List, _IDX0:Int, _I:Int, D:Int, ACC:List)
    => ACC
    requires D >=Int 8

  syntax List ::= AppendListItem ( Bytes , List ) [function, total]
  rule AppendListItem(B:Bytes, .List) => ListItem(B)
  rule AppendListItem(B:Bytes, ListItem(X:Bytes) REST:List)
    => ListItem(X) AppendListItem(B, REST)

  // structured 8-sibling proof data (bottom-up) — helper for the proof claims
  syntax List ::= AuthSib8 ( Bytes , Bytes , Bytes , Bytes , Bytes , Bytes , Bytes , Bytes ) [function, total]
  rule AuthSib8(A:Bytes, B:Bytes, C:Bytes, D:Bytes, E:Bytes, F:Bytes, G:Bytes, H2:Bytes)
    => ListItem(A) ListItem(B) ListItem(C) ListItem(D)
       ListItem(E) ListItem(F) ListItem(G) ListItem(H2)

endmodule
