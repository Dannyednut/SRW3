// =============================================================================
// SRW3 Phase 1D — Self-contained verifiable lineage records (k/phase1d/srw3lin.k)
//
// Parts II–VIII of the Phase-1D mandate: the commitment mechanism of Phase 1C
// is rebuilt as a SELF-CONTAINED, INDEPENDENTLY VERIFIABLE lineage record
//
//   Λ_i = ⟨ Version, ParentCommitment, TransitionId, AppSet, InputDigest,
//           EffectDigest, StateDigest, PolicyVersion, AuthorityId,
//           AuthorizationEvidence, Signature, ChildCommitment ⟩
//
// with the commitment formulas
//
//   CoreHash   = Keccak256(CanonicalSerialize(Λ minus Signature, Child))
//   IntentHash = Keccak256(Tid₄ ‖ InputDigest ‖ EffectDigest ‖ StateDigest)
//   Child      = Keccak256(CanonicalSerialize(Λ minus Child))
//
// Binding discipline (Phase-1D mandate):
//   * EffectDigest binds the TRUE EFFECTS of the transition (everything that
//     actually changed, declared or not) — never the declared footprint.
//     Declared-footprint/true-effect divergence cannot hide from the record.
//   * CryptographicAuthorization ≠ AuthoritySet membership: AuthorityId must
//     be a member of the authority set AND the authorization evidence (a
//     signature over the transition outcome intent) must recover to
//     AuthorityId, AND the record signature must recover to AuthorityId.
//   * VerifyLineage is INDEPENDENT: it consumes only the record, the claimed
//     artifacts (declared inputs, true effects, post-state, policy registry,
//     authority set) and the chain position. It re-derives every digest by
//     recomputation. It depends on no EVM execution, no hidden state, no
//     internal database, no ghost state.
//   * Every field tamper yields a DISTINCT verdict (tamper matrix).
//   * ChildCommitment covers all other 11 fields INCLUDING Signature and
//     AuthorizationEvidence — evidence substitution necessarily changes the
//     child commitment and fails verification.
//
// Naming discipline: StateDigest is the "prototype committed-state digest" of
// this model's canonical state encoding. It is NOT an Ethereum state root and
// MUST NOT be referred to as one (no Merkle/trie construction is claimed here;
// see the authenticated-state-proof interface, marked NOT YET MECHANIZED).
//
// Backend note: Keccak256raw/ECDSA* evaluate on the LLVM backend through the
// Phase-1C krypto shim (finding 1C-1: the Haskell backend has no KRYPTO
// evaluators). Structural chain claims are proved on the Haskell backend by
// keeping the commitment as an uninterpreted symbolic value there.
// =============================================================================

requires "krypto.md"

module SRW3LIN
  imports KRYPTO
  imports DOMAINS
  imports BYTES

  // ===========================================================================
  // §1. Primitives (1C-probe patterns: hex parsing, byte equality, sig split)
  // ===========================================================================

  syntax Bytes ::= LinHex ( String ) [function, total]
                 | LinHexAux ( String ) [function, total]
  syntax String ::= LinHexAlign ( String ) [function, total]

  rule LinHex(S)      => LinHexAux(LinHexAlign(S))
  rule LinHexAlign(S) => S             requires         lengthString(S) modInt 2 ==Int 0
  rule LinHexAlign(S) => "0" +String S requires notBool lengthString(S) modInt 2 ==Int 0
  rule LinHexAux("")  => .Bytes
  rule LinHexAux(S)   => Int2Bytes(lengthString(S) /Int 2, String2Base(S, 16), BE)
    requires lengthString(S) >=Int 2

  syntax Bool ::= BytesEq ( Bytes , Bytes ) [function, total]
  rule BytesEq(B, B) => true
  rule BytesEq(B1, B2) => false [owise]

  syntax Bytes ::= I2B4 ( Int ) [function, total]
  rule I2B4(N:Int) => Int2Bytes(4, N, BE)

  // root commitment: 32 zero bytes
  syntax Bytes ::= "LinRoot" [function, total]
  rule LinRoot => Int2Bytes(32, 0, BE)

  // Ethereum-style authority address from a signing key:
  // addr = last 20 bytes of keccak256(pubkey(sk))
  syntax Bytes ::= LinAddrOf ( Bytes ) [function, total]
  rule LinAddrOf(SK:Bytes) => LinHex(substrString(Keccak256(LinHex(ECDSAPubKey(SK:Bytes))), 24, 64))
    requires lengthString(ECDSAPubKey(SK:Bytes)) ==Int 128
  rule LinAddrOf(_:Bytes) => Int2Bytes(20, 0, BE) [owise]

  // ===========================================================================
  // §2. Explicit-recursion canonical encodings (order-deterministic by
  //     min-key walk; independent of backend map iteration order)
  // ===========================================================================

  syntax Int ::= MinI ( Int , Int ) [function, total]
  rule MinI(A:Int, B:Int) => A requires A <=Int B
  rule MinI(A:Int, B:Int) => B [owise]

  // minimum key of a Map of Int keys (-1 sentinel for empty). Split-independent:
  // min(all) = MinI(anyKey, min(rest)); the empty-rest split terminates the walk.
  syntax Int ::= MinKeyOfMap ( Map ) [function, total]
  rule MinKeyOfMap(.Map) => -1
  rule MinKeyOfMap(K:Int |-> _V:KItem .Map) => K
  rule MinKeyOfMap(K:Int |-> _V:KItem REST:Map) => MinI(K, MinKeyOfMap(REST))
    requires sizeMap(REST) >=Int 1

  // value (an inner Map) stored at a given Int key
  syntax Map ::= LinMapAt ( Map , Int ) [function, total]
  rule LinMapAt(K:Int |-> V:Map REST:Map, K2:Int) => V requires K ==Int K2
  rule LinMapAt(K:Int |-> _:Map REST:Map, K2:Int) => LinMapAt(REST, K2) requires K =/=Int K2
  rule LinMapAt(.Map, _:Int) => .Map

  // value (an Int) stored at a given Int key
  syntax Int ::= LinIntAt ( Map , Int ) [function, total]
  rule LinIntAt(K:Int |-> V:Int REST:Map, K2:Int) => V requires K ==Int K2
  rule LinIntAt(K:Int |-> _:Int REST:Map, K2:Int) => LinIntAt(REST, K2) requires K =/=Int K2
  rule LinIntAt(.Map, _:Int) => 0

  // canonical encoding of Map slot:Int -> val:Int :
  //   count₄ ‖ ( slot₄ ‖ val₄ )*   in ascending slot order
  syntax Bytes ::= LinCanonSlots ( Map ) [function, total]
  rule LinCanonSlots(S:Map) => I2B4(sizeMap(S)) +Bytes LinSlotsIter(S)

  syntax Bytes ::= LinSlotsIter ( Map ) [function, total]
  rule LinSlotsIter(.Map) => .Bytes
  rule LinSlotsIter(S:Map) => I2B4(MinKeyOfMap(S))
                              +Bytes I2B4(LinIntAt(S, MinKeyOfMap(S)))
                              +Bytes LinSlotsIter(S[MinKeyOfMap(S) <- undef])
    requires sizeMap(S) >=Int 1

  // canonical encoding of Map app:Int -> (Map slot:Int -> val:Int) — the
  // prototype state / effects encoding:
  //   appCount₄ ‖ ( app₄ ‖ slotCount₄ ‖ ( slot₄ ‖ val₄ )* )*   ascending order
  syntax Bytes ::= LinCanonKV ( Map ) [function, total]
  rule LinCanonKV(M:Map) => I2B4(sizeMap(M)) +Bytes LinKVIter(M)

  syntax Bytes ::= LinKVIter ( Map ) [function, total]
  rule LinKVIter(.Map) => .Bytes
  rule LinKVIter(M:Map) => I2B4(MinKeyOfMap(M))
                            +Bytes LinCanonSlots(LinMapAt(M, MinKeyOfMap(M)))
                            +Bytes LinKVIter(M[MinKeyOfMap(M) <- undef])
    requires sizeMap(M) >=Int 1

  // ascending List of Int app ids from an effects map (min-key extraction)
  syntax List ::= LinAppsOfMap ( Map ) [function, total]
  rule LinAppsOfMap(.Map) => .List
  rule LinAppsOfMap(M:Map) => ListItem(MinKeyOfMap(M)) LinAppsOfMap(M[MinKeyOfMap(M) <- undef])
    requires sizeMap(M) >=Int 1

  // canonical encoding of the AppSet field (ascending app ids):
  //   count₄ ‖ app₄*
  syntax Bytes ::= LinAppsCanon ( List ) [function, total]
  rule LinAppsCanon(A:List) => I2B4(size(A)) +Bytes LinAppsIter(A)

  syntax Bytes ::= LinAppsIter ( List ) [function, total]
  rule LinAppsIter(.List) => .Bytes
  rule LinAppsIter(ListItem(X:Int) REST:List) => I2B4(X) +Bytes LinAppsIter(REST)

  // sorted, deduplicated insert (keeps the AppSet canonical by construction)
  syntax List ::= LinAppIns ( List , Int ) [function, total]
  rule LinAppIns(.List, X:Int) => ListItem(X)
  rule LinAppIns(ListItem(X:Int) REST:List, X:Int) => ListItem(X) REST
  rule LinAppIns(ListItem(X:Int) REST:List, Y:Int) => ListItem(Y) ListItem(X) REST
    requires Y <Int X
  rule LinAppIns(ListItem(X:Int) REST:List, Y:Int) => ListItem(X) LinAppIns(REST, Y)
    requires Y >Int X

  // ===========================================================================
  // §3. The lineage record Λ_i (12 fields) and its serialization
  // ===========================================================================

  // field order is the canonical serialization order:
  //   Version₄ ‖ Parent₃₂ ‖ Tid₄ ‖ AppCanon ‖ InputD₃₂ ‖ EffectD₃₂
  //   ‖ StateD₃₂ ‖ PolicyV₄ ‖ Authority₂₀ ‖ EvLen₄ ‖ Evidence ‖ SigLen₄ ‖ Sig
  // (Child excluded; Signature excluded from Core serialization)
  syntax LinRec ::= "linRec" "(" linVersion:Int "," linParent:Bytes "," linTid:Int ","
                      linApps:List "," linInputD:Bytes "," linEffectD:Bytes ","
                      linStateD:Bytes "," linPolicyV:Int "," linAuthority:Bytes ","
                      linEvidence:Bytes "," linSig:Bytes "," linChild:Bytes ")"

  syntax Bytes ::= LinCanonCore ( Int , Bytes , Int , List , Bytes , Bytes ,
                                  Bytes , Int , Bytes , Bytes ) [function]
  rule LinCanonCore(V:Int, P:Bytes, T:Int, A:List, In:Bytes, Ef:Bytes, St:Bytes,
                    PV:Int, Au:Bytes, Ev:Bytes)
    => I2B4(V) +Bytes P +Bytes I2B4(T) +Bytes LinAppsCanon(A)
       +Bytes In +Bytes Ef +Bytes St +Bytes I2B4(PV)
       +Bytes Au +Bytes I2B4(lengthBytes(Ev)) +Bytes Ev

  syntax Bytes ::= LinCanonFull ( Int , Bytes , Int , List , Bytes , Bytes ,
                                  Bytes , Int , Bytes , Bytes , Bytes ) [function]
  rule LinCanonFull(V:Int, P:Bytes, T:Int, A:List, In:Bytes, Ef:Bytes, St:Bytes,
                    PV:Int, Au:Bytes, Ev:Bytes, Sig:Bytes)
    => LinCanonCore(V, P, T, A, In, Ef, St, PV, Au, Ev)
       +Bytes I2B4(lengthBytes(Sig)) +Bytes Sig

  // ===========================================================================
  // §4. Commitment formulas (real keccak256 via the Phase-1C shim)
  // ===========================================================================

  syntax Bytes ::= LinH ( Bytes ) [function]
  rule LinH(B:Bytes) => Keccak256raw(B)

  // what the record signature commits to: every content field
  syntax Bytes ::= LinCoreHash ( Int , Bytes , Int , List , Bytes , Bytes ,
                                 Bytes , Int , Bytes , Bytes ) [function]
  rule LinCoreHash(V, P, T, A, In, Ef, St, PV, Au, Ev)
    => LinH(LinCanonCore(V, P, T, A, In, Ef, St, PV, Au, Ev))

  // what the authorization evidence commits to: the transition outcome intent
  syntax Bytes ::= LinIntentHash ( Int , Bytes , Bytes , Bytes ) [function]
  rule LinIntentHash(T:Int, In:Bytes, Ef:Bytes, St:Bytes)
    => LinH(I2B4(T) +Bytes In +Bytes Ef +Bytes St)

  // the child commitment: ALL 11 non-child fields (incl. Signature)
  syntax Bytes ::= LinChildOf ( Int , Bytes , Int , List , Bytes , Bytes ,
                                Bytes , Int , Bytes , Bytes , Bytes ) [function]
  rule LinChildOf(V, P, T, A, In, Ef, St, PV, Au, Ev, Sig)
    => LinH(LinCanonFull(V, P, T, A, In, Ef, St, PV, Au, Ev, Sig))

  // signature/evidence creation (secp256k1 via the pinned libsecp256k1 path)
  // sig layout: 65 raw bytes r[0:32] ‖ s[32:64] ‖ recid[64]
  syntax Bytes ::= LinMakeSig ( Bytes , Int , Bytes , Int , List , Bytes , Bytes ,
                                Bytes , Int , Bytes , Bytes ) [function]
  rule LinMakeSig(SK:Bytes, V:Int, P:Bytes, T:Int, A:List, In:Bytes, Ef:Bytes,
                  St:Bytes, PV:Int, Au:Bytes, Ev:Bytes)
    => LinHex(ECDSASign(LinCoreHash(V, P, T, A, In, Ef, St, PV, Au, Ev), SK))
    requires lengthString(ECDSASign(LinCoreHash(V, P, T, A, In, Ef, St, PV, Au, Ev), SK)) ==Int 130
  rule LinMakeSig(_:Bytes, _:Int, _:Bytes, _:Int, _:List, _:Bytes, _:Bytes,
                  _:Bytes, _:Int, _:Bytes, _:Bytes) => Int2Bytes(65, 0, BE) [owise]

  syntax Bytes ::= LinMakeEvidence ( Bytes , Int , Bytes , Bytes , Bytes ) [function]
  rule LinMakeEvidence(SK:Bytes, T:Int, In:Bytes, Ef:Bytes, St:Bytes)
    => LinHex(ECDSASign(LinIntentHash(T, In, Ef, St), SK))
    requires lengthString(ECDSASign(LinIntentHash(T, In, Ef, St), SK)) ==Int 130
  rule LinMakeEvidence(_:Bytes, _:Int, _:Bytes, _:Bytes, _:Bytes) => Int2Bytes(65, 0, BE) [owise]

  // recover the signer address from a 65-byte raw signature
  syntax Bytes ::= LinRecoverAddr ( Bytes , Bytes ) [function, total]
  rule LinRecoverAddr(MSG:Bytes, SIG:Bytes)
    => LinHex(substrString(Keccak256(
         ECDSARecover(MSG, 27 +Int (SIG[64] modInt 2), substrBytes(SIG, 0, 32), substrBytes(SIG, 32, 64))
       ), 24, 64))
    requires lengthBytes(SIG) ==Int 65
  rule LinRecoverAddr(_:Bytes, _:Bytes) => Int2Bytes(20, 0, BE) [owise]

  // ===========================================================================
  // §5. Record accessors (explicit recursion discipline, Phase-0 style)
  // ===========================================================================

  syntax Int    ::= linVersionOf ( LinRec ) [function]
  syntax Bytes  ::= linParentOf  ( LinRec ) [function]
  syntax Int    ::= linTidOf     ( LinRec ) [function]
  syntax List   ::= linAppsOf    ( LinRec ) [function]
  syntax Bytes  ::= linInputDOf  ( LinRec ) [function]
  syntax Bytes  ::= linEffectDOf ( LinRec ) [function]
  syntax Bytes  ::= linStateDOf  ( LinRec ) [function]
  syntax Int    ::= linPolicyVOf ( LinRec ) [function]
  syntax Bytes  ::= linAuthOf    ( LinRec ) [function]
  syntax Bytes  ::= linEvOf      ( LinRec ) [function]
  syntax Bytes  ::= linSigOf     ( LinRec ) [function]
  syntax Bytes  ::= linChildOf   ( LinRec ) [function]

  rule linVersionOf(linRec(V:Int, _:Bytes, _:Int, _:List, _:Bytes, _:Bytes, _:Bytes, _:Int, _:Bytes, _:Bytes, _:Bytes, _:Bytes)) => V
  rule linParentOf(linRec(_:Int, P:Bytes, _:Int, _:List, _:Bytes, _:Bytes, _:Bytes, _:Int, _:Bytes, _:Bytes, _:Bytes, _:Bytes)) => P
  rule linTidOf(linRec(_:Int, _:Bytes, T:Int, _:List, _:Bytes, _:Bytes, _:Bytes, _:Int, _:Bytes, _:Bytes, _:Bytes, _:Bytes)) => T
  rule linAppsOf(linRec(_:Int, _:Bytes, _:Int, A:List, _:Bytes, _:Bytes, _:Bytes, _:Int, _:Bytes, _:Bytes, _:Bytes, _:Bytes)) => A
  rule linInputDOf(linRec(_:Int, _:Bytes, _:Int, _:List, In:Bytes, _:Bytes, _:Bytes, _:Int, _:Bytes, _:Bytes, _:Bytes, _:Bytes)) => In
  rule linEffectDOf(linRec(_:Int, _:Bytes, _:Int, _:List, _:Bytes, Ef:Bytes, _:Bytes, _:Int, _:Bytes, _:Bytes, _:Bytes, _:Bytes)) => Ef
  rule linStateDOf(linRec(_:Int, _:Bytes, _:Int, _:List, _:Bytes, _:Bytes, St:Bytes, _:Int, _:Bytes, _:Bytes, _:Bytes, _:Bytes)) => St
  rule linPolicyVOf(linRec(_:Int, _:Bytes, _:Int, _:List, _:Bytes, _:Bytes, _:Bytes, PV:Int, _:Bytes, _:Bytes, _:Bytes, _:Bytes)) => PV
  rule linAuthOf(linRec(_:Int, _:Bytes, _:Int, _:List, _:Bytes, _:Bytes, _:Bytes, _:Int, Au:Bytes, _:Bytes, _:Bytes, _:Bytes)) => Au
  rule linEvOf(linRec(_:Int, _:Bytes, _:Int, _:List, _:Bytes, _:Bytes, _:Bytes, _:Int, _:Bytes, Ev:Bytes, _:Bytes, _:Bytes)) => Ev
  rule linSigOf(linRec(_:Int, _:Bytes, _:Int, _:List, _:Bytes, _:Bytes, _:Bytes, _:Int, _:Bytes, _:Bytes, Sig:Bytes, _:Bytes)) => Sig
  rule linChildOf(linRec(_:Int, _:Bytes, _:Int, _:List, _:Bytes, _:Bytes, _:Bytes, _:Int, _:Bytes, _:Bytes, _:Bytes, C:Bytes)) => C
endmodule
