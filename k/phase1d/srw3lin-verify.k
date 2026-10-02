// =============================================================================
// SRW3 Phase 1D — Independent lineage verifier (k/phase1d/srw3lin-verify.k)
//
// Part VIII (independent verifier VerifyLineage), Part IX (per-field tamper
// matrix machinery) and Part X/XI support (chain walk with position binding).
//
// VerifyLineage(R, CTX, T, HEAD) consumes ONLY:
//   * the record R,
//   * the claimed artifacts CTX (declared inputs, true effects, post-state,
//     policy registry, authority set) that travel with the record,
//   * the expected transition id T and the expected parent commitment HEAD
//     (the chain position),
// and re-derives every digest and every signature by recomputation. It reads
// no execution state, no hidden cells, no ghost state, no database —
// independence is by construction (the function has no access to any other
// configuration cell or global state).
//
// Verdict priority (each failure yields a DISTINCT verdict, one per field —
// the tamper matrix contract):
//   invalid-version | invalid-tid | invalid-parent | invalid-appset |
//   invalid-inputdigest | invalid-effectdigest | invalid-statedigest |
//   invalid-policyversion | invalid-authority | invalid-evidence |
//   invalid-signature | invalid-commitment | valid
//
// "invalid-authority" = membership failure (AuthorityId not in authority set);
// "invalid-evidence"  = cryptographic authorization failure (the evidence
// signature does not recover to AuthorityId) — the two are deliberately
// distinct: set membership is necessary but NEVER sufficient (CM-L3/CM-L4).
// =============================================================================

requires "srw3lin.k"

module SRW3LIN-VERIFY
  imports SRW3LIN

  // ---- verification context (claimed artifacts traveling with the record) ---
  syntax LinCtx ::= "linCtx" "(" linInputs:Map "," linTrueEffects:Map ","
                      linPostState:Map "," linRegistry:Map "," linAuthSet:Set ")"

  syntax Map ::= linCtxInputs  ( LinCtx ) [function]
  syntax Map ::= linCtxEffects ( LinCtx ) [function]
  syntax Map ::= linCtxState   ( LinCtx ) [function]
  syntax Map ::= linCtxRegistry( LinCtx ) [function]
  syntax Set ::= linCtxAuthSet ( LinCtx ) [function]

  rule linCtxInputs  (linCtx(I:Map, _:Map, _:Map, _:Map, _:Set)) => I
  rule linCtxEffects (linCtx(_:Map, E:Map, _:Map, _:Map, _:Set)) => E
  rule linCtxState   (linCtx(_:Map, _:Map, S:Map, _:Map, _:Set)) => S
  rule linCtxRegistry(linCtx(_:Map, _:Map, _:Map, R:Map, _:Set)) => R
  rule linCtxAuthSet (linCtx(_:Map, _:Map, _:Map, _:Map, A:Set)) => A

  // ---- the twelve per-field checks ------------------------------------------
  syntax Bool ::= LinVersionOk ( LinRec ) [function, total]
  rule LinVersionOk(R:LinRec) => linVersionOf(R) ==Int 1

  syntax Bool ::= LinParentOk ( LinRec , Bytes ) [function, total]
  rule LinParentOk(R:LinRec, HEAD:Bytes) => BytesEq(linParentOf(R), HEAD)

  syntax Bool ::= LinTidOk ( LinRec , Int ) [function, total]
  rule LinTidOk(R:LinRec, T:Int) => linTidOf(R) ==Int T

  syntax Bool ::= LinAppsOk ( LinRec , LinCtx ) [function, total]
  rule LinAppsOk(R:LinRec, CTX:LinCtx)
    => linAppsOf(R) ==K LinAppsOfMap(linCtxEffects(CTX))

  syntax Bool ::= LinInputOk ( LinRec , LinCtx ) [function, total]
  rule LinInputOk(R:LinRec, CTX:LinCtx)
    => BytesEq(linInputDOf(R), LinH(LinCanonKV(linCtxInputs(CTX))))

  syntax Bool ::= LinEffectOk ( LinRec , LinCtx ) [function, total]
  rule LinEffectOk(R:LinRec, CTX:LinCtx)
    => BytesEq(linEffectDOf(R), LinH(LinCanonKV(linCtxEffects(CTX))))

  syntax Bool ::= LinStateOk ( LinRec , LinCtx ) [function, total]
  rule LinStateOk(R:LinRec, CTX:LinCtx)
    => BytesEq(linStateDOf(R), LinH(LinCanonKV(linCtxState(CTX))))

  syntax Bool ::= LinPolicyOk ( LinRec , LinCtx ) [function, total]
  rule LinPolicyOk(R:LinRec, CTX:LinCtx)
    => linPolicyVOf(R) in_keys(linCtxRegistry(CTX))

  syntax Bool ::= LinAuthOk ( LinRec , LinCtx ) [function, total]
  rule LinAuthOk(R:LinRec, CTX:LinCtx)
    => linAuthOf(R) in linCtxAuthSet(CTX)

  syntax Bool ::= LinEvidenceOk ( LinRec ) [function, total]
  rule LinEvidenceOk(R:LinRec)
    => BytesEq(linAuthOf(R),
               LinRecoverAddr(LinIntentHash(linTidOf(R), linInputDOf(R),
                                            linEffectDOf(R), linStateDOf(R)),
                              linEvOf(R)))

  syntax Bool ::= LinSigOk ( LinRec ) [function, total]
  rule LinSigOk(R:LinRec)
    => BytesEq(linAuthOf(R),
               LinRecoverAddr(LinCoreHash(linVersionOf(R), linParentOf(R),
                                linTidOf(R), linAppsOf(R), linInputDOf(R),
                                linEffectDOf(R), linStateDOf(R),
                                linPolicyVOf(R), linAuthOf(R), linEvOf(R)),
                              linSigOf(R)))

  syntax Bool ::= LinChildOk ( LinRec ) [function, total]
  rule LinChildOk(R:LinRec)
    => BytesEq(linChildOf(R),
               LinChildOf(linVersionOf(R), linParentOf(R), linTidOf(R),
                          linAppsOf(R), linInputDOf(R), linEffectDOf(R),
                          linStateDOf(R), linPolicyVOf(R), linAuthOf(R),
                          linEvOf(R), linSigOf(R)))

  // ---- VerifyLineage: first-fail verdict chain (total) -----------------------
  syntax String ::= VerifyLineage ( LinRec , LinCtx , Int , Bytes ) [function, total]

  rule VerifyLineage(R:LinRec, CTX:LinCtx, T:Int, HEAD:Bytes) => "invalid-version"
    requires notBool LinVersionOk(R)
  rule VerifyLineage(R:LinRec, CTX:LinCtx, T:Int, HEAD:Bytes) => "invalid-tid"
    requires LinVersionOk(R) andBool notBool LinTidOk(R, T)
  rule VerifyLineage(R:LinRec, CTX:LinCtx, T:Int, HEAD:Bytes) => "invalid-parent"
    requires LinVersionOk(R) andBool LinTidOk(R, T) andBool notBool LinParentOk(R, HEAD)
  rule VerifyLineage(R:LinRec, CTX:LinCtx, T:Int, HEAD:Bytes) => "invalid-appset"
    requires LinVersionOk(R) andBool LinTidOk(R, T) andBool LinParentOk(R, HEAD)
             andBool notBool LinAppsOk(R, CTX)
  rule VerifyLineage(R:LinRec, CTX:LinCtx, T:Int, HEAD:Bytes) => "invalid-inputdigest"
    requires LinVersionOk(R) andBool LinParentOk(R, HEAD) andBool LinTidOk(R, T)
             andBool LinAppsOk(R, CTX) andBool notBool LinInputOk(R, CTX)
  rule VerifyLineage(R:LinRec, CTX:LinCtx, T:Int, HEAD:Bytes) => "invalid-effectdigest"
    requires LinVersionOk(R) andBool LinParentOk(R, HEAD) andBool LinTidOk(R, T)
             andBool LinAppsOk(R, CTX) andBool LinInputOk(R, CTX)
             andBool notBool LinEffectOk(R, CTX)
  rule VerifyLineage(R:LinRec, CTX:LinCtx, T:Int, HEAD:Bytes) => "invalid-statedigest"
    requires LinVersionOk(R) andBool LinParentOk(R, HEAD) andBool LinTidOk(R, T)
             andBool LinAppsOk(R, CTX) andBool LinInputOk(R, CTX)
             andBool LinEffectOk(R, CTX) andBool notBool LinStateOk(R, CTX)
  rule VerifyLineage(R:LinRec, CTX:LinCtx, T:Int, HEAD:Bytes) => "invalid-policyversion"
    requires LinVersionOk(R) andBool LinParentOk(R, HEAD) andBool LinTidOk(R, T)
             andBool LinAppsOk(R, CTX) andBool LinInputOk(R, CTX)
             andBool LinEffectOk(R, CTX) andBool LinStateOk(R, CTX)
             andBool notBool LinPolicyOk(R, CTX)
  rule VerifyLineage(R:LinRec, CTX:LinCtx, T:Int, HEAD:Bytes) => "invalid-authority"
    requires LinVersionOk(R) andBool LinParentOk(R, HEAD) andBool LinTidOk(R, T)
             andBool LinAppsOk(R, CTX) andBool LinInputOk(R, CTX)
             andBool LinEffectOk(R, CTX) andBool LinStateOk(R, CTX)
             andBool LinPolicyOk(R, CTX) andBool notBool LinAuthOk(R, CTX)
  rule VerifyLineage(R:LinRec, CTX:LinCtx, T:Int, HEAD:Bytes) => "invalid-evidence"
    requires LinVersionOk(R) andBool LinParentOk(R, HEAD) andBool LinTidOk(R, T)
             andBool LinAppsOk(R, CTX) andBool LinInputOk(R, CTX)
             andBool LinEffectOk(R, CTX) andBool LinStateOk(R, CTX)
             andBool LinPolicyOk(R, CTX) andBool LinAuthOk(R, CTX)
             andBool notBool LinEvidenceOk(R)
  rule VerifyLineage(R:LinRec, CTX:LinCtx, T:Int, HEAD:Bytes) => "invalid-signature"
    requires LinVersionOk(R) andBool LinParentOk(R, HEAD) andBool LinTidOk(R, T)
             andBool LinAppsOk(R, CTX) andBool LinInputOk(R, CTX)
             andBool LinEffectOk(R, CTX) andBool LinStateOk(R, CTX)
             andBool LinPolicyOk(R, CTX) andBool LinAuthOk(R, CTX)
             andBool LinEvidenceOk(R) andBool notBool LinSigOk(R)
  rule VerifyLineage(R:LinRec, CTX:LinCtx, T:Int, HEAD:Bytes) => "invalid-commitment"
    requires LinVersionOk(R) andBool LinParentOk(R, HEAD) andBool LinTidOk(R, T)
             andBool LinAppsOk(R, CTX) andBool LinInputOk(R, CTX)
             andBool LinEffectOk(R, CTX) andBool LinStateOk(R, CTX)
             andBool LinPolicyOk(R, CTX) andBool LinAuthOk(R, CTX)
             andBool LinEvidenceOk(R) andBool LinSigOk(R)
             andBool notBool LinChildOk(R)
  rule VerifyLineage(_:LinRec, _:LinCtx, _:Int, _:Bytes) => "valid" [owise]

  // ---- chain walk: every record verified against its claimed artifacts,
  //      position-bound (expected tid = position; expected parent = previous
  //      child, starting from LinRoot). Returns "i:verdict;..." per record.
  syntax String ::= LinVerifyChain ( Map , Map , Int , Int , Bytes ) [function, total]

  rule LinVerifyChain(RS:Map, CS:Map, I:Int, N:Int, HEAD:Bytes)
    => Int2String(I) +String ":" +String VerifyLineage(linRecAt(RS, I), linCtxAt(CS, I), I, HEAD)
       +String ";" +String LinVerifyChain(RS, CS, I +Int 1, N, linChildOf(linRecAt(RS, I)))
    requires I <Int N
  rule LinVerifyChain(_:Map, _:Map, _:Int, _:Int, _:Bytes) => "" [owise]

  // record/context lookup by position (total; sentinel ctx for absence —
  // digest checks then fail loudly rather than getting stuck)
  syntax LinRec ::= linRecAt ( Map , Int ) [function, total]
  rule linRecAt(T:Int |-> R:LinRec REST:Map, T2:Int) => R requires T ==Int T2
  rule linRecAt(T:Int |-> _:LinRec REST:Map, T2:Int) => linRecAt(REST, T2) requires T =/=Int T2
  rule linRecAt(.Map, _:Int)
    => linRec(0, Int2Bytes(32, 1, BE), -1, .List, Int2Bytes(32, 1, BE),
              Int2Bytes(32, 1, BE), Int2Bytes(32, 1, BE), -1, Int2Bytes(20, 0, BE),
              Int2Bytes(65, 0, BE), Int2Bytes(65, 0, BE), Int2Bytes(32, 1, BE))

  syntax LinCtx ::= linCtxAt ( Map , Int ) [function, total]
  rule linCtxAt(T:Int |-> C:LinCtx REST:Map, T2:Int) => C requires T ==Int T2
  rule linCtxAt(T:Int |-> _:LinCtx REST:Map, T2:Int) => linCtxAt(REST, T2) requires T =/=Int T2
  rule linCtxAt(.Map, _:Int) => linCtx(.Map, .Map, .Map, .Map, .Set)

  // ---- Part IX: tamper-matrix machinery -------------------------------------
  syntax LinField ::= "fVersion"  | "fParent"   | "fTid"      | "fApps"
                    | "fInputD"   | "fEffectD"  | "fStateD"   | "fPolicyV"
                    | "fAuthority" | "fEvidence" | "fSig"      | "fChild"

  syntax String ::= LinFieldTag ( LinField ) [function, total]
  rule LinFieldTag(F:LinField) => "f?" [owise]
  rule LinFieldTag(fVersion)   => "version"
  rule LinFieldTag(fParent)    => "parent"
  rule LinFieldTag(fTid)       => "tid"
  rule LinFieldTag(fApps)      => "apps"
  rule LinFieldTag(fInputD)    => "inputD"
  rule LinFieldTag(fEffectD)   => "effectD"
  rule LinFieldTag(fStateD)    => "stateD"
  rule LinFieldTag(fPolicyV)   => "policyV"
  rule LinFieldTag(fAuthority) => "authority"
  rule LinFieldTag(fEvidence)  => "evidence"
  rule LinFieldTag(fSig)       => "sig"
  rule LinFieldTag(fChild)     => "child"

  // tamper one field (byte-level flips / value bumps; deterministic)
  syntax LinRec ::= LinTamper ( LinField , LinRec ) [function]

  rule LinTamper(fVersion, R:LinRec)   => linRec(2, linParentOf(R), linTidOf(R), linAppsOf(R), linInputDOf(R), linEffectDOf(R), linStateDOf(R), linPolicyVOf(R), linAuthOf(R), linEvOf(R), linSigOf(R), linChildOf(R))
  rule LinTamper(fParent, R:LinRec)    => linRec(linVersionOf(R), LinXorByte(linParentOf(R), 0), linTidOf(R), linAppsOf(R), linInputDOf(R), linEffectDOf(R), linStateDOf(R), linPolicyVOf(R), linAuthOf(R), linEvOf(R), linSigOf(R), linChildOf(R))
  rule LinTamper(fTid, R:LinRec)       => linRec(linVersionOf(R), linParentOf(R), linTidOf(R) +Int 1, linAppsOf(R), linInputDOf(R), linEffectDOf(R), linStateDOf(R), linPolicyVOf(R), linAuthOf(R), linEvOf(R), linSigOf(R), linChildOf(R))
  rule LinTamper(fApps, R:LinRec)      => linRec(linVersionOf(R), linParentOf(R), linTidOf(R), LinAppIns(linAppsOf(R), 99), linInputDOf(R), linEffectDOf(R), linStateDOf(R), linPolicyVOf(R), linAuthOf(R), linEvOf(R), linSigOf(R), linChildOf(R))
  rule LinTamper(fInputD, R:LinRec)    => linRec(linVersionOf(R), linParentOf(R), linTidOf(R), linAppsOf(R), LinXorByte(linInputDOf(R), 0), linEffectDOf(R), linStateDOf(R), linPolicyVOf(R), linAuthOf(R), linEvOf(R), linSigOf(R), linChildOf(R))
  rule LinTamper(fEffectD, R:LinRec)   => linRec(linVersionOf(R), linParentOf(R), linTidOf(R), linAppsOf(R), linInputDOf(R), LinXorByte(linEffectDOf(R), 0), linStateDOf(R), linPolicyVOf(R), linAuthOf(R), linEvOf(R), linSigOf(R), linChildOf(R))
  rule LinTamper(fStateD, R:LinRec)    => linRec(linVersionOf(R), linParentOf(R), linTidOf(R), linAppsOf(R), linInputDOf(R), linEffectDOf(R), LinXorByte(linStateDOf(R), 0), linPolicyVOf(R), linAuthOf(R), linEvOf(R), linSigOf(R), linChildOf(R))
  rule LinTamper(fPolicyV, R:LinRec)   => linRec(linVersionOf(R), linParentOf(R), linTidOf(R), linAppsOf(R), linInputDOf(R), linEffectDOf(R), linStateDOf(R), linPolicyVOf(R) +Int 1, linAuthOf(R), linEvOf(R), linSigOf(R), linChildOf(R))
  rule LinTamper(fAuthority, R:LinRec) => linRec(linVersionOf(R), linParentOf(R), linTidOf(R), linAppsOf(R), linInputDOf(R), linEffectDOf(R), linStateDOf(R), linPolicyVOf(R), LinOtherAuth(linAuthOf(R)), linEvOf(R), linSigOf(R), linChildOf(R))
  rule LinTamper(fEvidence, R:LinRec)  => linRec(linVersionOf(R), linParentOf(R), linTidOf(R), linAppsOf(R), linInputDOf(R), linEffectDOf(R), linStateDOf(R), linPolicyVOf(R), linAuthOf(R), LinXorByte(linEvOf(R), 0), linSigOf(R), linChildOf(R))
  rule LinTamper(fSig, R:LinRec)       => linRec(linVersionOf(R), linParentOf(R), linTidOf(R), linAppsOf(R), linInputDOf(R), linEffectDOf(R), linStateDOf(R), linPolicyVOf(R), linAuthOf(R), linEvOf(R), LinXorByte(linSigOf(R), 0), linChildOf(R))
  rule LinTamper(fChild, R:LinRec)     => linRec(linVersionOf(R), linParentOf(R), linTidOf(R), linAppsOf(R), linInputDOf(R), linEffectDOf(R), linStateDOf(R), linPolicyVOf(R), linAuthOf(R), linEvOf(R), linSigOf(R), LinXorByte(linChildOf(R), 0))

  // flip the last byte of a Bytes value (a minimal, deterministic tamper)
  syntax Bytes ::= LinXorByte ( Bytes , Int ) [function, total]
  rule LinXorByte(B:Bytes, I:Int)
    => substrBytes(B, 0, lengthBytes(B) -Int 1)
       +Bytes Int2Bytes(1, ((B[lengthBytes(B) -Int 1] +Int 1) modInt 256), BE)
    requires lengthBytes(B) >=Int 1 andBool I ==Int 0
  rule LinXorByte(B:Bytes, _:Int) => B [owise]

  // the "other" authority: a second demo authority address (member of the set)
  syntax Bytes ::= LinOtherAuth ( Bytes ) [function, total]
  rule LinOtherAuth(_:Bytes) => LinHex("2020202020202020202020202020202020202020")

  // ---- tamper-matrix report: "field:verdict;" for each field ----------------
  syntax String ::= LinTamperMatrix ( LinRec , LinCtx , Int , Bytes , List ) [function, total]

  rule LinTamperMatrix(R:LinRec, CTX:LinCtx, T:Int, HEAD:Bytes, .List) => ""
  rule LinTamperMatrix(R:LinRec, CTX:LinCtx, T:Int, HEAD:Bytes, ListItem(F:LinField) REST:List)
    => LinFieldTag(F) +String "="
       +String VerifyLineage(LinTamper(F, R), CTX, T, HEAD) +String ";"
       +String LinTamperMatrix(R, CTX, T, HEAD, REST)
endmodule
