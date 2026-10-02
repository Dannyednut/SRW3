// =============================================================================
// SRW3 Phase 1D — Lineage-creating gate + demo programs (k/phase1d/srw3lin-gate.k)
//
// Parts IV–VII (binding construction at commit time) and the executable
// demonstration surface.
//
// The gate is the ONLY place where <committed>, <head> and <lineage> change
// (one-gate discipline, unchanged from the 1B/1C architecture). At gate time
// the transition's lineage record Λ is CONSTRUCTED from the actual outcome:
//
//   InputDigest  = H(CanonicalKV(declared writes))          (the declared input)
//   EffectDigest = H(CanonicalKV(TRUE effects))             (declared ∪ hidden!)
//   StateDigest  = H(CanonicalKV(post-state))               (prototype digest)
//   AppSet       = ascending app ids of the TRUE effects    (derived, not claimed)
//   Evidence     = ECDSA-sign(authKey, IntentHash)          (outcome intent)
//   Signature    = ECDSA-sign(authKey, CoreHash)            (record integrity)
//   Child        = Keccak256(CanonicalSerialize(Λ minus Child))
//
// Two gate paths:
//   * linGate           — construct-and-commit (the honest committer path);
//                         an internal integrity obligation re-derives the
//                         child by recomputation before appending (the 1C
//                         gate-verifies-by-recomputation discipline, retained).
//   * linGatePresent(R) — presented-record path: accept iff VerifyLineage(R,
//                         claimedCtx, lineageNext, head) = "valid" (the
//                         replay/tamper defense surface).
// Reject restores prospective/pend/hidden and does NOT touch lineage/head.
//
// The standalone verify path (linVerifyChain) reads only the record set and
// the claimed-artifact book — no committed/prospective cells — demonstrating
// verifier independence by construction.
// =============================================================================

requires "srw3lin-verify.k"

module SRW3LIN-GATE
  imports SRW3LIN-VERIFY

  // ---- commands --------------------------------------------------------------
  syntax LinCmd ::= "linBegin"
                  | "linInit" "(" Int "," Int "," Int ")"          // app, slot, v
                  | "linW"    "(" Int "," Int "," Int ")"          // declared write
                  | "linHiddenW" "(" Int "," Int "," Int ")"       // undeclared side effect
                  | "linGate"
                  | "linGatePresent" "(" LinRec "," LinCtx ")"
                  | "linSetPolicy" "(" Int ")"
                  | "linEndMarker"
  syntax LinPgm ::= List{LinCmd,","}

  // ---- configuration (shape mirrors the 1C/1B gate; one-gate discipline) -----
  configuration <srw3lin>
                  <k> $PGM:LinPgm </k>
                  <committed> .Map </committed>      // Map app -> Map slot -> Int
                  <prospective> .Map </prospective>
                  <pend> .Map </pend>                // declared writes
                  <hidden> .Map </hidden>            // undeclared true effects
                  <lineage> .Map </lineage>          // Map tid -> LinRec
                  <lineageNext> 0 </lineageNext>
                  <head> LinRoot </head>
                  <authKey> LinDemoKey1 </authKey>
                  <policyV> 5 </policyV>
                  <result> "" </result>
                </srw3lin>

  // demo signing keys (Ethereum-style 32-byte secrets; authority = addr(key))
  syntax Bytes ::= "LinDemoKey1" [function, total]
  syntax Bytes ::= "LinDemoKey2" [function, total]
  rule LinDemoKey1 => Int2Bytes(32, 77, BE)
  rule LinDemoKey2 => Int2Bytes(32, 4242, BE)

  // ---- helpers ---------------------------------------------------------------
  syntax Map ::= LinSetKV ( Map , Int , Int , Int ) [function]   // m[a][s] := v
  rule LinSetKV(M:Map, A:Int, S:Int, V:Int)
    => M[A <- LinSetSlots(LinMapAt(M, A), S, V)]

  syntax Map ::= LinSetSlots ( Map , Int , Int ) [function]
  rule LinSetSlots(S:Map, K:Int, V:Int) => S[K <- V]

  // merge declared and hidden writes into the TRUE effects map (right-biased:
  // hidden side effects override — the actually-landed value wins)
  syntax Map ::= LinTrueEffects ( Map , Map ) [function, total]
  rule LinTrueEffects(D:Map, .Map) => D
  rule LinTrueEffects(D:Map, H:Map)
    => LinTrueEffects(
         LinSetKV(D, MinKeyOfMap(H), MinKeyOfMap(LinMapAt(H, MinKeyOfMap(H))),
                  LinIntAt(LinMapAt(H, MinKeyOfMap(H)),
                           MinKeyOfMap(LinMapAt(H, MinKeyOfMap(H))))),
         H[MinKeyOfMap(H) <- undef])
    requires sizeMap(H) >=Int 1

  // ---- sequential composition -------------------------------------------------
  rule <k> (C:LinCmd , REST:LinPgm) => C ~> REST ... </k>

  rule <k> linInit(A:Int, S:Int, V:Int) => .K ... </k>
       <committed> M:Map => LinSetKV(M, A, S, V) </committed>

  rule <k> linBegin => .K ... </k>
       <committed> C:Map </committed>
       <prospective> _:Map => C </prospective>
       <pend> _:Map => .Map </pend>
       <hidden> _:Map => .Map </hidden>

  // declared write: prospective AND declared footprint
  rule <k> linW(A:Int, S:Int, V:Int) => .K ... </k>
       <prospective> P:Map => LinSetKV(P, A, S, V) </prospective>
       <pend> Q:Map => LinSetKV(Q, A, S, V) </pend>

  // undeclared side effect: prospective changes but the declared footprint
  // does NOT — the divergence that EffectDigest (true effects) makes visible
  rule <k> linHiddenW(A:Int, S:Int, V:Int) => .K ... </k>
       <prospective> P:Map => LinSetKV(P, A, S, V) </prospective>
       <hidden> H:Map => LinSetKV(H, A, S, V) </hidden>

  rule <k> linSetPolicy(PV:Int) => .K ... </k>
       <policyV> _:Int => PV </policyV>

  // ---- linGate: construct-and-commit (honest path) ---------------------------
  rule <k> linGate => .K ... </k>
       <prospective> P:Map => .Map </prospective>
       <pend> Q:Map => .Map </pend>
       <hidden> H:Map => .Map </hidden>
       <committed> _:Map => P </committed>
       <lineage> L:Map
          => L[N:Int <- LinBuildRec(N:Int, HEADB:Bytes, Q:Map, LinTrueEffects(Q, H:Map), P:Map, KEY:Bytes, PV:Int)] </lineage>
       <lineageNext> N:Int => N +Int 1 </lineageNext>
       <head> HEADB:Bytes => linChildOf(LinBuildRec(N:Int, HEADB:Bytes, Q:Map, LinTrueEffects(Q, H:Map), P:Map, KEY:Bytes, PV:Int)) </head>
       <authKey> KEY:Bytes </authKey>
       <policyV> PV:Int </policyV>
       <result> R:String => R +String "commit;" </result>
    requires LinGateIntegrityOk(N:Int, HEADB:Bytes, Q:Map, LinTrueEffects(Q, H:Map), P:Map, KEY:Bytes, PV:Int)

  // internal integrity obligation: the constructed record re-derives its own
  // child by recomputation (gate-verifies-by-recomputation discipline)
  syntax Bool ::= LinGateIntegrityOk ( Int , Bytes , Map , Map , Map , Bytes , Int ) [function, total]
  rule LinGateIntegrityOk(N:Int, HEADB:Bytes, Q:Map, E:Map, P:Map, KEY:Bytes, PV:Int)
    => BytesEq(linChildOf(LinBuildRec(N, HEADB, Q, E, P, KEY, PV)),
               LinChildOf(1, HEADB, N, LinAppsOfMap(E),
                          LinH(LinCanonKV(Q)), LinH(LinCanonKV(E)),
                          LinH(LinCanonKV(P)), PV, LinAddrOf(KEY),
                          LinMakeEvidence(KEY, N, LinH(LinCanonKV(Q)),
                                          LinH(LinCanonKV(E)), LinH(LinCanonKV(P))),
                          LinMakeSig(KEY, 1, HEADB, N, LinAppsOfMap(E),
                                     LinH(LinCanonKV(Q)), LinH(LinCanonKV(E)),
                                     LinH(LinCanonKV(P)), PV, LinAddrOf(KEY),
                                     LinMakeEvidence(KEY, N, LinH(LinCanonKV(Q)),
                                                     LinH(LinCanonKV(E)),
                                                     LinH(LinCanonKV(P))))))

  // Λ construction from the actual outcome
  syntax LinRec ::= LinBuildRec ( Int , Bytes , Map , Map , Map , Bytes , Int ) [function]
  rule LinBuildRec(N:Int, HEADB:Bytes, Q:Map, E:Map, P:Map, KEY:Bytes, PV:Int)
    => linRec(1, HEADB, N, LinAppsOfMap(E),
              LinH(LinCanonKV(Q)), LinH(LinCanonKV(E)), LinH(LinCanonKV(P)),
              PV, LinAddrOf(KEY),
              LinMakeEvidence(KEY, N, LinH(LinCanonKV(Q)), LinH(LinCanonKV(E)),
                              LinH(LinCanonKV(P))),
              LinMakeSig(KEY, 1, HEADB, N, LinAppsOfMap(E), LinH(LinCanonKV(Q)),
                         LinH(LinCanonKV(E)), LinH(LinCanonKV(P)), PV,
                         LinAddrOf(KEY),
                         LinMakeEvidence(KEY, N, LinH(LinCanonKV(Q)),
                                         LinH(LinCanonKV(E)), LinH(LinCanonKV(P)))),
              LinChildOf(1, HEADB, N, LinAppsOfMap(E), LinH(LinCanonKV(Q)),
                         LinH(LinCanonKV(E)), LinH(LinCanonKV(P)), PV,
                         LinAddrOf(KEY),
                         LinMakeEvidence(KEY, N, LinH(LinCanonKV(Q)),
                                         LinH(LinCanonKV(E)), LinH(LinCanonKV(P))),
                         LinMakeSig(KEY, 1, HEADB, N, LinAppsOfMap(E),
                                    LinH(LinCanonKV(Q)), LinH(LinCanonKV(E)),
                                    LinH(LinCanonKV(P)), PV, LinAddrOf(KEY),
                                    LinMakeEvidence(KEY, N, LinH(LinCanonKV(Q)),
                                                    LinH(LinCanonKV(E)),
                                                    LinH(LinCanonKV(P))))))

  // ---- linGatePresent: presented-record path (verify-then-accept) ------------
  rule <k> linGatePresent(R:LinRec, CTX:LinCtx) => .K ... </k>
       <prospective> _:Map => .Map </prospective>
       <pend> _:Map => .Map </pend>
       <hidden> _:Map => .Map </hidden>
       <committed> M:Map </committed>
       <lineage> L:Map => L[linTidOf(R) <- R] </lineage>
       <lineageNext> N:Int => N +Int 1 </lineageNext>
       <head> HEADB:Bytes => linChildOf(R) </head>
       <result> RES:String => RES +String "commit;" </result>
    requires VerifyLineage(R, CTX, N:Int, HEADB:Bytes) ==String "valid"

  rule <k> linGatePresent(R:LinRec, CTX:LinCtx) => .K ... </k>
       <prospective> _:Map => .Map </prospective>
       <pend> _:Map => .Map </pend>
       <hidden> _:Map => .Map </hidden>
       <committed> M:Map </committed>
       <lineage> L:Map </lineage>
       <lineageNext> N:Int </lineageNext>
       <head> HEADB:Bytes </head>
       <result> RES:String
          => RES +String "reject:" +String VerifyLineage(R, CTX, N:Int, HEADB:Bytes) +String ";" </result>
    requires VerifyLineage(R, CTX, N:Int, HEADB:Bytes) =/=String "valid"

  // ---- standalone independent verification (no gate cells touched) -----------
  rule <k> linEndMarker => .K ... </k>

  syntax LinCmd ::= "linVerifyChain" "(" Map "," Map "," Int "," Bytes ")"
  rule <k> linVerifyChain(RS:Map, CS:Map, N:Int, ROOT:Bytes) => .K ... </k>
       <result> _:String => LinVerifyChain(RS, CS, 0, N, ROOT) </result>
    requires ROOT ==K LinRoot

  // ---- tamper matrix (Part IX demonstration) ----------------------------------
  syntax LinCmd ::= "linTamperMatrix" "(" LinRec "," LinCtx "," Int "," Bytes ")"
  rule <k> linTamperMatrix(R:LinRec, CTX:LinCtx, T:Int, HEAD:Bytes)
        => .K ... </k>
       <result> _:String
          => LinTamperMatrix(R, CTX, T, HEAD,
               ListItem(fVersion) ListItem(fParent) ListItem(fTid) ListItem(fApps)
               ListItem(fInputD) ListItem(fEffectD) ListItem(fStateD) ListItem(fPolicyV)
               ListItem(fAuthority) ListItem(fEvidence) ListItem(fSig) ListItem(fChild)) </result>

  // ---- impersonation (CM-L4): authority swapped to a second IN-SET member ----
  syntax LinRec ::= LinImpersonate ( LinRec , Bytes ) [function]
  rule LinImpersonate(R:LinRec, AU:Bytes)
    => linRec(linVersionOf(R), linParentOf(R), linTidOf(R), linAppsOf(R),
              linInputDOf(R), linEffectDOf(R), linStateDOf(R), linPolicyVOf(R),
              AU, linEvOf(R), linSigOf(R), linChildOf(R))

  syntax LinCmd ::= "linImpersonateCheck" "(" LinRec "," LinCtx "," Int "," Bytes "," Bytes ")"
  rule <k> linImpersonateCheck(R:LinRec, CTX:LinCtx, T:Int, HEAD:Bytes, AU:Bytes)
        => .K ... </k>
       <result> _:String
          => "impersonate=" +String VerifyLineage(LinImpersonate(R, AU), CTX, T, HEAD) </result>
endmodule
