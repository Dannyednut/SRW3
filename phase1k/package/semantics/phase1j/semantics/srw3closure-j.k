// =============================================================================
// SRW3 Phase 1J — REACHABILITY SAFETY CLOSURE & EXECUTION-EVIDENCE COMPLETENESS
//                    (phase1j/semantics/srw3closure-j.k, isolated J machine)
//
// Backend: HASKELL (proofs/structural core) + LLVM (concrete keccak demos via
// the Phase-1C krypto shim) + Python executable mirror (j_model.py).
//
// IMPLEMENTS (handoff: SRW3_Phase1J_Security_Closure_Handoff.md):
//   §1  objective — a reachable-committed-state safety theorem
//       J-REACHABLE-COMMITTED-SAFE over the transition system M_J, with
//       Safe_P defined INDEPENDENTLY of the accept transition (not "the gate
//       accepted"); §3 decomposition; §4 Option A (closed-fragment theorem);
//       §5 concrete policy catalog + hypergraph interaction closure;
//       §6 safety state + frame; §7 one chain-extending rule with the nine
//       commit-guard requirement classes; §8 adversarial matrix; §9 proof
//       inventory discipline (per-claim exit code + retained log, one source
//       of truth); §10 scope/assumptions/labels; §11 deliverable layout;
//       §12 completion gate.
//
// J DESIGN (following the frozen R3 machine discipline, handoff §2):
//
//   1. ISOLATED MACHINE SURFACE.  This definition imports ONLY the frozen
//      Phase 1G gate module SRW3AUTHZ (phase1g/semantics/srw3authz.k,
//      unchanged down to srw3lin.k+krypto.md).  It does NOT import
//      SRW3PROTO-R3 or any earlier protocol machine (handoff §2: reproduce
//      R3 formulas instead of importing the R3 machine, with correspondence
//      claims and byte-level vectors).  The R3 formulas ARE reproduced below
//      with IDENTICAL tags and composition (0x9D/0xA5/0xA6/0x9E/0x9F and the
//      R3 canonical config preimage) — byte-level correspondence is claimed
//      in the proofs module and demonstrated by the cross-layer certificate.
//      The legacy commands (1I/R1/R2/R3 command names) are NOT in the J
//      command language: not declared, not matched by any rule (kparse
//      rejects; J-LEGACY-SURFACE-EXCLUDED).  A new application-policy gate
//      (the J policy evaluation, §7 below) is DISTINCT from and COMPOSED
//      WITH the frozen lineage gate VerifyLineageG (handoff §2).
//
//   2. THE FROZEN R3 ROOT AND ANCHOR ARE PRESERVED (handoff §2).  The J
//      machine pins the SAME ProtoCfgR3 13-field configuration and requires
//      ProtoRootR3(C) ==K <janchor> at initialization, where <janchor> is
//      filled by the explicit authenticated external input $SRW3JANCHOR and
//      written by NO rule (immutability by construction).  R3's canonical
//      encoding is NOT redefined.  R3's scope boundary is NOT silently
//      closed: protocol-root AUTHORITY/governance remains an explicit
//      external assumption (reported, not claimed solved).
//
//   3. THE CONCRETE POLICY CATALOG (handoff §5.1).  The catalog is
//      represented as CONTENTS, not only digests:
//        - Apps:        registered app identities + names (+ owned keys,
//                       derivable from the resource table; the canon includes
//                       the per-app name only — ownership is per-resource);
//        - Resources:   state locations (flat key K = app*2^32 + slot, the
//                       frozen Phase 1E key space) + the authorized owner app;
//        - Hyperedges:  n-ary interaction sets over resource keys (a node set
//                       may involve any number of apps/resources — a
//                       hypergraph, not a pairwise-only graph, handoff §5.2);
//        - LocalInvariants:      per-resource bound invariants;
//        - HyperedgeInvariants:  sum/eq invariants over a hyperedge's nodes;
//        - GlobalInvariants:     sum invariants over any resource set.
//      Canonical encoding: NEW domain separator "SRW3/PolicyCat/J"||0x00,
//      versioned (U32BE(1)), length-delimited (LP32), deterministic field
//      order.  Three sub-roots commit to the content classes:
//        JAppSetRootJ  = LinH(0xB1 || appsCanon || resourcesCanon)
//        JGraphRootJ   = LinH(0xB2 || hyperCanon)
//        JPolicyRootJ  = LinH(0xB3 || invariantsCanon)
//      and the FULL catalog root JCatalogRootJ = LinH(JCatalogCanonJ(P)).
//      NEW TAGS 0xB1/0xB2/0xB3 are distinct from every frozen tag (0x00-0x02
//      1E; 0x03/0x11/0x12/0x13/0x1F/0x57 1F; 0x9C-0x9F/0xA5/0xA6 1I/1G) — no
//      frozen namespace is reused (domain separation, handoff §4.3).
//      INITIALIZATION binds the catalog to the R3-rooted configuration:
//        JAppSetRootJ(P) ==K qcrAppSetDOf(C)  (field 4)
//        JGraphRootJ(P)  ==K qcrGraphDOf(C)   (field 5)
//        JPolicyRootJ(P) ==K qcrPolicyDOf(C)  (field 3)
//        U32BE(policyV)  ==  qcrPolicyVOf(C)  (field 2)
//      so the catalog CONTENTS are authenticated by the same R3 anchor
//      (J-CATALOG-ROOT-BINDING: a digest without verified contents is not
//      accepted, and contents without the matching digest are refused).
//      Catalog well-formedness (fail-closed): every resource's owner is a
//      registered app; every hyperedge node is a registered resource; every
//      invariant node is a registered resource; no duplicate app ids /
//      resource keys / hyperedge ids / invariant ids; every invariant that
//      names a hyperedge names a registered one; the app set is non-empty.
//      Violation => pInitJ refuses with state unchanged (handoff §5.1).
//
//   4. THE CLOSED EXECUTION FRAGMENT EVM_F (handoff §4.1 Option A).  The
//      modeled execution relation #ExecFragmentJ interprets the CLOSED
//      fragment program over the abstract state <jstate>:
//        fragment ops: jRead(a,s) | jWrite(a,s,v) | jCall(a,t,v)
//                    | jReturn(a,o,z)                        (the 1F vocabulary)
//        excluded ops: jUnsupported(n) — an EXPLICIT marker for every
//                      excluded effect class (LOGn, CREATE/CREATE2, CALLCODE,
//                      DELEGATECALL, STATICCALL, SELFDESTRUCT, gas, memory,
//                      precompile/system effects — one declaration class, a
//                      concrete integer n names the excluded op).
//      The interpreter DERIVES, from the pre-state and the program:
//        the ordered event trace T (exact execution order, 1F events), the
//        effective write-delta E, the post-state P, and the refusal verdict
//        for anything outside the fragment (jExecUnsupported/jExecBounds —
//        never skipped, never a harmless no-op, never silently omitted from
//        the footprint).  Field bounds are the 1F bounds (0 <= a,s < 2^32,
//        0 <= v < 2^64); violation is an explicit refusal class.
//      THE TRACE IS EMITTED BY THE SEMANTICS: the ONLY trace a J execution
//      receipt can carry is the one #ExecFragmentJ built (structural: the
//      receipt's trace field is written by the pExecJ rule from the
//      interpreter result; no command takes a trace argument —
//      J-TRACE-ORIGIN by rule inventory + the correspondence claims).
//
//   5. EVIDENCE IDENTITY (handoff §4.3).  A NEW domain-separated, versioned,
//      length-delimited identity binds the full execution context:
//        EvidenceCanonJ = "SRW3/Evidence/J" || 0x00 || U32BE(1)
//          || LP32(configRootR3) || LP32(catalogRootJ) || LP32(chainId)
//          || LP32(fork) || LP32(parentStateRootJ) || LP32(payloadDigestJ)
//          || LP32(executionSourceId) || LP32(postStateRootJ)
//          || LP32(orderedTraceDigest) || LP32(completeFootprintDigest)
//          || LP32(policyContextDigest)
//        EvidenceIDJ = LinH(EvidenceCanonJ)
//      (fixed new tag 0xB5 for the policy-context digest; the domain string
//      separates from every frozen preimage; the Ethereum Keccak-256 hook is
//      the established LinH — sha3_256 is NEVER substituted).  The identity
//      helps prevent cross-payload/config/parent replay; it does NOT itself
//      prove the trace is true — that comes from the derivation relation
//      (the fragment interpreter) and the frozen gate (handoff §4.3).
//
//   6. THE J STATE ROOT.  The abstract state <jstate> (flat-key Map) is
//      committed by StateRootJ(σ) = LinH(0xB4 || LinCanonKV(σ)) — the frozen
//      ascending canonical map encoding under a NEW tag.  This is the
//      J-level state identity threading pre/post state; the frozen 1E
//      Merkle root inside the evidence records is unchanged and continues
//      to be validated by the frozen gate internally.
//
//   7. SAFETY IS COMPUTED, INDEPENDENT OF THE GATE (handoff §3/§6).
//      SafeJ(P, σ) = AllLocalJ(locals, σ) AND AllHyperJ(hypers, σ)
//                    AND AllGlobalJ(globals, σ)
//      — a recursion over the catalog's registered invariant CONTENTS
//      evaluated on the abstract state (uninitialized storage reads 0, the
//      EVM convention, documented).  The commit guard evaluates SafeJ on the
//      DERIVED post-state; no caller-supplied policy Boolean exists in the
//      command language (J-NO-CALLER-EVIDENCE-VERDICT).
//
//   8. THE BOUNDED HYPERGRAPH CLOSURE (handoff §5.2).  AffectedClosureJ
//      computes the least closure of the touched resource keys (derived from
//      the footprint = first-occurrence projection of the derived trace)
//      plus every hyperedge incident to any touched node plus the additional
//      nodes needed to evaluate each such invariant, to a fixed point, under
//      an explicit fuel bound.  Exhaustion => jClosureExhausted; a touched
//      key not present in the catalog => jClosureUnknown; both REJECT the
//      commit (bounded closure exhaustion is NEVER interpreted as "no more
//      interactions"; handoff §5.2).
//
//   9. THE COMMIT BOUNDARY (handoff §7).  Exactly ONE rule extends the
//      committed chain: pCommitJ.  Its guard requires (in the R3 order —
//      decidable conjuncts first so structural rejections resolve concretely
//      on the Haskell backend): (1) authorized configuration-root anchor /
//      R3 root equality (init + receipt re-check); (2) an execution receipt
//      for this exact candidate and parent state, derived by the fragment
//      semantics from the CURRENT <jstate>; (3) the COMPUTED frozen
//      VerifyLineageG verdict == "valid-g" (via the derived-decision mapping
//      on the gate receipt); (4) verified root-bound catalog contents (pin +
//      receipt re-check); (5) complete effect/affected-hyperedge closure for
//      the supported fragment (computed by the machine from the derived
//      footprint); (6) every applicable local, hyperedge, and global
//      invariant check SUCCEEDS on the derived post-state (machine-evaluated
//      SafeJ); (7) protocol head, evidence-lineage head, slot/counter
//      freshness; (8) parent/post-state/trace/footprint identities equal the
//      execution-derived values; (9) receipts single-use (gate AND exec) and
//      NO alternate transition to committed state (one chain-extending rule;
//      every other command consumes to .K or refuses with state unchanged).
//      Rejections leave committed state, roots, counters, and both heads
//      unchanged (fail-closed).  Evidence/catalog unavailability is the
//      documented fail-closed availability cost (handoff §7): a commit whose
//      receipts/closure/invariants are unavailable simply never fires; the
//      [owise] reject is the total refusal path (a defer without commit).
//
//   10. LEVEL-III MODEL; NO ETHEREUM CONSENSUS-INTEGRATION CLAIM.  The
//       off-chain gate result is not a real consensus rule; the Phase 1H
//       Geth adapter was a shadow boundary and remains one (handoff §7).
//       Option B (full-EVM evidence theorem) is NOT claimed and remains
//       open: only the four-event fragment is instrumented (handoff §4.1).
//
// CONFIGURATION NOTE: K admits exactly one <k> cell per definition; the J
// machine declares its own configuration <srw3closureJ> (cells <k> <jlineage>
// <jnext> <jhead> <jlinhead> <janchor> <jstate> <jrefuse> <jvalid>).  The
// reserved-negative-key discipline is retained: pinned configuration = key
// -1, gate-receipt pool = -2, pinned catalog = -3, exec-receipt pool = -4
// (negative keys can never collide with block slots >= 0).  <jrefuse> holds
// the LAST execution refusal (observable non-committing diagnostics; written
// ONLY by the exec rules; it is machine bookkeeping, never a verdict input).
//
// TRUST BOUNDARIES (stated, not hidden): (a) the verdict is the frozen
// VerifyLineageG result — soundness rests on the frozen gate (mechanized in
// Phase 1G); (b) hash equalities are symbolic constraints on the Haskell
// backend; concrete digests are decided on the LLVM backend (krypto shim,
// real Keccak-256) and in the Python mirror (real keccak, collision
// resistance ASSUMED, not proved); (c) the authorized root anchor is an
// explicitly external authenticated input — protocol-root AUTHORITY remains
// an explicit assumption; (d) trace AUTHENTICITY (historical truth) is NOT
// claimed: the closed-fragment theorem establishes DERIVATION
// (trace-from-semantics) + CORRESPONDENCE + COVERAGE for EVM_F, not
// unrestricted Ethereum execution (handoff §4.1 Option A, stated boundary);
// (e) the invariant language is the DECLARED finite typed fragment
// (bounds/sum/eq) — the arbitrary-policy theorem is NOT mechanized and is
// reported as an open item; (f) Level-III model — no consensus-integration
// claim is made or implied.
// =============================================================================

requires "../../phase1g/semantics/srw3authz.k"

module SRW3CLOSURE-J

  imports SRW3AUTHZ

  // ===========================================================================
  // §A. THE R3 CONFIGURATION FORMULAS — REPRODUCED, BYTE-IDENTICAL (handoff
  //     §2: if the J semantics must reproduce R3 formulas instead of
  //     importing the R3 machine, add correspondence claims and byte-level
  //     vectors).  Identical tags, identical composition, identical names
  //     modulo the R3 suffix.  The proofs module states the correspondence
  //     claims (J-CORRESPONDENCE-*); the cross-layer certificate emits the
  //     bytes (conformance vectors).
  // ===========================================================================

  syntax ProtoCfgR3 ::= "protoCfgR3" "(" qcrChainId:Bytes ","
                        qcrPolicyV:Int "," qcrPolicyD:Bytes ","
                        qcrAppSetD:Bytes "," qcrGraphD:Bytes ","
                        qcrClientCfgD:Bytes "," qcrExecClientD:Bytes ","
                        qcrFork:Bytes "," qcrSched:Bytes "," qcrSpec:Int ","
                        qcrAuthPT:Int "," qcrAuthGuestD:Bytes ","
                        qcrAuthCfgD:Bytes ")"

  syntax Bytes ::= qcrChainIdOf    ( ProtoCfgR3 ) [function, total]
  rule qcrChainIdOf(protoCfgR3(CH:Bytes, _:Int, _:Bytes, _:Bytes, _:Bytes,
                               _:Bytes, _:Bytes, _:Bytes, _:Bytes, _:Int,
                               _:Int, _:Bytes, _:Bytes)) => CH:Bytes
  syntax Int ::= qcrPolicyVOf      ( ProtoCfgR3 ) [function, total]
  rule qcrPolicyVOf(protoCfgR3(_:Bytes, V:Int, _:Bytes, _:Bytes, _:Bytes,
                               _:Bytes, _:Bytes, _:Bytes, _:Bytes, _:Int,
                               _:Int, _:Bytes, _:Bytes)) => V:Int
  syntax Bytes ::= qcrPolicyDOf    ( ProtoCfgR3 ) [function, total]
  rule qcrPolicyDOf(protoCfgR3(_:Bytes, _:Int, PD:Bytes, _:Bytes, _:Bytes,
                               _:Bytes, _:Bytes, _:Bytes, _:Bytes, _:Int,
                               _:Int, _:Bytes, _:Bytes)) => PD:Bytes
  syntax Bytes ::= qcrAppSetDOf    ( ProtoCfgR3 ) [function, total]
  rule qcrAppSetDOf(protoCfgR3(_:Bytes, _:Int, _:Bytes, AS:Bytes, _:Bytes,
                               _:Bytes, _:Bytes, _:Bytes, _:Bytes, _:Int,
                               _:Int, _:Bytes, _:Bytes)) => AS:Bytes
  syntax Bytes ::= qcrGraphDOf     ( ProtoCfgR3 ) [function, total]
  rule qcrGraphDOf(protoCfgR3(_:Bytes, _:Int, _:Bytes, _:Bytes, GR:Bytes,
                              _:Bytes, _:Bytes, _:Bytes, _:Bytes, _:Int,
                              _:Int, _:Bytes, _:Bytes)) => GR:Bytes
  syntax Bytes ::= qcrClientCfgDOf ( ProtoCfgR3 ) [function, total]
  rule qcrClientCfgDOf(protoCfgR3(_:Bytes, _:Int, _:Bytes, _:Bytes, _:Bytes,
                                  CC:Bytes, _:Bytes, _:Bytes, _:Bytes, _:Int,
                                  _:Int, _:Bytes, _:Bytes)) => CC:Bytes
  syntax Bytes ::= qcrExecClientDOf( ProtoCfgR3 ) [function, total]
  rule qcrExecClientDOf(protoCfgR3(_:Bytes, _:Int, _:Bytes, _:Bytes, _:Bytes,
                                   _:Bytes, EC:Bytes, _:Bytes, _:Bytes, _:Int,
                                   _:Int, _:Bytes, _:Bytes)) => EC:Bytes
  syntax Bytes ::= qcrForkOf       ( ProtoCfgR3 ) [function, total]
  rule qcrForkOf(protoCfgR3(_:Bytes, _:Int, _:Bytes, _:Bytes, _:Bytes,
                            _:Bytes, _:Bytes, FK:Bytes, _:Bytes, _:Int,
                            _:Int, _:Bytes, _:Bytes)) => FK:Bytes
  syntax Bytes ::= qcrSchedOf      ( ProtoCfgR3 ) [function, total]
  rule qcrSchedOf(protoCfgR3(_:Bytes, _:Int, _:Bytes, _:Bytes, _:Bytes,
                             _:Bytes, _:Bytes, _:Bytes, SC:Bytes, _:Int,
                             _:Int, _:Bytes, _:Bytes)) => SC:Bytes
  syntax Int ::= qcrSpecOf         ( ProtoCfgR3 ) [function, total]
  rule qcrSpecOf(protoCfgR3(_:Bytes, _:Int, _:Bytes, _:Bytes, _:Bytes,
                            _:Bytes, _:Bytes, _:Bytes, _:Bytes, SP:Int,
                            _:Int, _:Bytes, _:Bytes)) => SP:Int
  syntax Int ::= qcrAuthPTOf       ( ProtoCfgR3 ) [function, total]
  rule qcrAuthPTOf(protoCfgR3(_:Bytes, _:Int, _:Bytes, _:Bytes, _:Bytes,
                              _:Bytes, _:Bytes, _:Bytes, _:Bytes, _:Int,
                              PT:Int, _:Bytes, _:Bytes)) => PT:Int
  syntax Bytes ::= qcrAuthGuestDOf ( ProtoCfgR3 ) [function, total]
  rule qcrAuthGuestDOf(protoCfgR3(_:Bytes, _:Int, _:Bytes, _:Bytes, _:Bytes,
                                  _:Bytes, _:Bytes, _:Bytes, _:Bytes, _:Int,
                                  _:Int, GD:Bytes, _:Bytes)) => GD:Bytes
  syntax Bytes ::= qcrAuthCfgDOf   ( ProtoCfgR3 ) [function, total]
  rule qcrAuthCfgDOf(protoCfgR3(_:Bytes, _:Int, _:Bytes, _:Bytes, _:Bytes,
                                _:Bytes, _:Bytes, _:Bytes, _:Bytes, _:Int,
                                _:Int, _:Bytes, CD:Bytes)) => CD:Bytes

  // the R3 canonical configuration preimage — IDENTICAL to the frozen R3
  // machine's ProtoCfgCanonR3 (domain "SRW3/ProtoCfg/R3", U32BE(1), LP32).
  syntax Bytes ::= "R3DomainSep" [function, total]
  rule R3DomainSep
    => LinHex("535257332f50726f746f4366672f523300")   // "SRW3/ProtoCfg/R3" || 0x00

  syntax Int ::= "R3EncodingVersion" [function, total]
  rule R3EncodingVersion => 1

  syntax Bytes ::= LP32R3 ( Bytes ) [function, total]
  rule LP32R3(B:Bytes) => I2B4(lengthBytes(B)) +Bytes B

  syntax Bytes ::= ProtoCfgCanonR3 ( ProtoCfgR3 ) [function, total]
  rule ProtoCfgCanonR3(C:ProtoCfgR3)
    => R3DomainSep
       +Bytes I2B4(R3EncodingVersion)
       +Bytes LP32R3(qcrChainIdOf(C))
       +Bytes I2B4(qcrPolicyVOf(C))
       +Bytes LP32R3(qcrPolicyDOf(C))
       +Bytes LP32R3(qcrAppSetDOf(C))
       +Bytes LP32R3(qcrGraphDOf(C))
       +Bytes LP32R3(qcrClientCfgDOf(C))
       +Bytes LP32R3(qcrExecClientDOf(C))
       +Bytes LP32R3(qcrForkOf(C))
       +Bytes LP32R3(qcrSchedOf(C))
       +Bytes I2B4(qcrSpecOf(C))
       +Bytes I2B4(qcrAuthPTOf(C))
       +Bytes LP32R3(qcrAuthGuestDOf(C))
       +Bytes LP32R3(qcrAuthCfgDOf(C))

  syntax Bytes ::= ProtoRootR3 ( ProtoCfgR3 ) [function]
  rule ProtoRootR3(C:ProtoCfgR3) => LinH(ProtoCfgCanonR3(C))

  syntax Bool ::= CfgEqR3 ( ProtoCfgR3 , ProtoCfgR3 ) [function, total]
  rule CfgEqR3(C1:ProtoCfgR3, C2:ProtoCfgR3)
    => BytesEq(qcrChainIdOf(C1), qcrChainIdOf(C2))
       andBool qcrPolicyVOf(C1) ==Int qcrPolicyVOf(C2)
       andBool BytesEq(qcrPolicyDOf(C1), qcrPolicyDOf(C2))
       andBool BytesEq(qcrAppSetDOf(C1), qcrAppSetDOf(C2))
       andBool BytesEq(qcrGraphDOf(C1), qcrGraphDOf(C2))
       andBool BytesEq(qcrClientCfgDOf(C1), qcrClientCfgDOf(C2))
       andBool BytesEq(qcrExecClientDOf(C1), qcrExecClientDOf(C2))
       andBool BytesEq(qcrForkOf(C1), qcrForkOf(C2))
       andBool BytesEq(qcrSchedOf(C1), qcrSchedOf(C2))
       andBool qcrSpecOf(C1) ==Int qcrSpecOf(C2)
       andBool qcrAuthPTOf(C1) ==Int qcrAuthPTOf(C2)
       andBool BytesEq(qcrAuthGuestDOf(C1), qcrAuthGuestDOf(C2))
       andBool BytesEq(qcrAuthCfgDOf(C1), qcrAuthCfgDOf(C2))

  // frozen 1I policy commitment / authorized context / ctx digest (0x9D/0xA5/
  // 0xA6 — UNCHANGED; the historical correspondence points).
  syntax Bytes ::= PolicyCommitmentR3 ( ProtoCfgR3 ) [function]
  rule PolicyCommitmentR3(C:ProtoCfgR3)
    => LinH( Int2Bytes(1, 157, BE)                // 0x9D (frozen 1I tag)
             +Bytes I2B4(qcrPolicyVOf(C)) +Bytes qcrPolicyDOf(C)
             +Bytes qcrAppSetDOf(C) +Bytes qcrGraphDOf(C)
             +Bytes LinH( Int2Bytes(1, 165, BE)   // 0xA5 (frozen 1I tag)
                          +Bytes qcrChainIdOf(C) +Bytes qcrForkOf(C) ) )

  syntax SecCtx ::= ProtoAuthorizedSecCtxR3 ( ProtoCfgR3 , Bytes ) [function]
  rule ProtoAuthorizedSecCtxR3(C:ProtoCfgR3, LH:Bytes)
    => secCtx(qcrPolicyVOf(C), qcrChainIdOf(C), qcrAppSetDOf(C),
              qcrGraphDOf(C), LH:Bytes)

  syntax Bytes ::= CtxCanonR3 ( SecCtx ) [function, total]
  rule CtxCanonR3(secCtx(V:Int, CH:Bytes, AS:Bytes, GR:Bytes, LH:Bytes))
    => Int2Bytes(1, 166, BE)                      // 0xA6 (frozen 1I tag)
       +Bytes I2B4(V) +Bytes CH +Bytes AS +Bytes GR +Bytes LH
  syntax Bytes ::= CtxDigestR3 ( SecCtx ) [function]
  rule CtxDigestR3(S:SecCtx) => LinH(CtxCanonR3(S))

  // frozen 1I decisions (fail-closed mapping; ONLY "valid-g" is valid).
  syntax Int ::= "pdecValidJ"   [function, total]
  syntax Int ::= "pdecRejectJ"  [function, total]
  syntax Int ::= "pdecUnknownJ" [function, total]
  rule pdecValidJ   => 1
  rule pdecRejectJ  => 0
  rule pdecUnknownJ => 2

  syntax Int ::= ProtoDecisionOfGateJ ( String ) [function, total]
  rule ProtoDecisionOfGateJ("valid-g") => pdecValidJ
  rule ProtoDecisionOfGateJ(S:String)  => pdecRejectJ [owise]

  // ===========================================================================
  // §B. THE CONCRETE POLICY CATALOG (handoff §5.1) — contents, not digests.
  // ===========================================================================

  // A registered application: identity + name.  (Owned resources are the
  // resources whose owner field is this id — derived, so not duplicated.)
  syntax JApp ::= jApp ( jaId:Int , jaName:Bytes )

  syntax Int ::= jaIdOf   ( JApp ) [function, total]
  rule jaIdOf(jApp(I:Int, _:Bytes)) => I:Int
  syntax Bytes ::= jaNameOf ( JApp ) [function, total]
  rule jaNameOf(jApp(_:Int, N:Bytes)) => N:Bytes

  // A registered resource: the flat state key (app*2^32+slot, the 1E space)
  // and the AUTHORIZED owner app.  The owner resolver is total over the
  // registered resources; an unregistered key has NO owner (fail-closed).
  syntax JResource ::= jRes ( jrKey:Int , jrOwner:Int )

  syntax Int ::= jrKeyOf   ( JResource ) [function, total]
  rule jrKeyOf(jRes(K:Int, _:Int)) => K:Int
  syntax Int ::= jrOwnerOf ( JResource ) [function, total]
  rule jrOwnerOf(jRes(_:Int, O:Int)) => O:Int

  // A hyperedge: n-ary interaction set over REGISTERED resource keys.
  syntax JHyper ::= jHyper ( jhId:Int , jhNodes:List )

  syntax Int  ::= jhIdOf   ( JHyper ) [function, total]
  rule jhIdOf(jHyper(I:Int, _:List)) => I:Int
  syntax List ::= jhNodesOf ( JHyper ) [function, total]
  rule jhNodesOf(jHyper(_:Int, N:List)) => N:List

  // The invariant language — the DECLARED finite typed fragment (handoff
  // §6: "If the full policy language cannot be quantified over in K, define
  // a finite typed fragment and prove closure for that fragment; label the
  // arbitrary-policy theorem as not mechanized").  Three kinds:
  //   jInvLocal(id, key, lo, hi)     : lo <= value(key) <= hi      (local)
  //   jInvSum(id, heId, keys, cap)   : sum value(keys) <= cap      (hyper/global)
  //   jInvEq(id, heId, keys)         : all value(keys) equal       (hyper)
  // heId names the hyperedge the invariant is over (0 = global scope for
  // sum invariants registered in the GLOBAL list).
  syntax JInv ::= jInvLocal ( jiId:Int , jiKey:Int , jiLo:Int , jiHi:Int )
                | jInvSum   ( jiId:Int , jiHe:Int , jiKeys:List , jiCap:Int )
                | jInvEq    ( jiId:Int , jiHe:Int , jiKeys:List )

  syntax Int ::= jiIdOf ( JInv ) [function, total]
  rule jiIdOf(jInvLocal(I:Int, _:Int, _:Int, _:Int)) => I:Int
  rule jiIdOf(jInvSum(I:Int, _:Int, _:List, _:Int)) => I:Int
  rule jiIdOf(jInvEq(I:Int, _:Int, _:List)) => I:Int

  // The catalog: policy version + content lists.  List order is the
  // canonical order (the canon encodes lists in exactly this order).
  syntax JCatalog ::= jCatalog ( jcPolicyV:Int
                               , jcApps:List , jcResources:List
                               , jcHypers:List
                               , jcLocals:List , jcHypersInv:List
                               , jcGlobals:List )

  syntax Int  ::= jcPolicyVOf ( JCatalog ) [function, total]
  rule jcPolicyVOf(jCatalog(V:Int, _:List, _:List, _:List, _:List,
                            _:List, _:List)) => V:Int
  syntax List ::= jcAppsOf      ( JCatalog ) [function, total]
  rule jcAppsOf(jCatalog(_:Int, A:List, _:List, _:List, _:List,
                         _:List, _:List)) => A:List
  syntax List ::= jcResourcesOf ( JCatalog ) [function, total]
  rule jcResourcesOf(jCatalog(_:Int, _:List, R:List, _:List, _:List,
                              _:List, _:List)) => R:List
  syntax List ::= jcHypersOf   ( JCatalog ) [function, total]
  rule jcHypersOf(jCatalog(_:Int, _:List, _:List, H:List, _:List,
                           _:List, _:List)) => H:List
  syntax List ::= jcLocalsOf   ( JCatalog ) [function, total]
  rule jcLocalsOf(jCatalog(_:Int, _:List, _:List, _:List, L:List,
                           _:List, _:List)) => L:List
  syntax List ::= jcHypersInvOf ( JCatalog ) [function, total]
  rule jcHypersInvOf(jCatalog(_:Int, _:List, _:List, _:List, _:List,
                              H:List, _:List)) => H:List
  syntax List ::= jcGlobalsOf  ( JCatalog ) [function, total]
  rule jcGlobalsOf(jCatalog(_:Int, _:List, _:List, _:List, _:List,
                            _:List, G:List)) => G:List

  // --------------------------------------------------------------------------
  // §B.1 canonical encoding — NEW domain "SRW3/PolicyCat/J"||0x00, U32BE(1),
  //      length-delimited.  Deterministic field order: apps, resources,
  //      hyperedges, locals, hyperedge invariants, globals.
  // --------------------------------------------------------------------------

  syntax Bytes ::= "JCatDomainSep" [function, total]
  rule JCatDomainSep
    => LinHex("535257332f506f6c6963794361742f4a00")   // "SRW3/PolicyCat/J" || 0x00

  syntax Int ::= "JCatEncodingVersion" [function, total]
  rule JCatEncodingVersion => 1

  syntax Bytes ::= JCanonApps ( List ) [function, total]
  rule JCanonApps(.List) => .Bytes
  rule JCanonApps(ListItem(A:JApp) REST:List)
    => I2B4(jaIdOf(A)) +Bytes LP32R3(jaNameOf(A)) +Bytes JCanonApps(REST)

  syntax Bytes ::= JCanonResources ( List ) [function, total]
  rule JCanonResources(.List) => .Bytes
  rule JCanonResources(ListItem(R:JResource) REST:List)
    => Int2Bytes(8, jrKeyOf(R), BE) +Bytes I2B4(jrOwnerOf(R))
       +Bytes JCanonResources(REST)

  syntax Bytes ::= JCanonHypers ( List ) [function, total]
  rule JCanonHypers(.List) => .Bytes
  rule JCanonHypers(ListItem(H:JHyper) REST:List)
    => I2B4(jhIdOf(H)) +Bytes I2B4(size(jhNodesOf(H)))
       +Bytes JCanonKeys(jhNodesOf(H)) +Bytes JCanonHypers(REST)

  // the resource keys are the 64-bit flat 1E keys (app*2^32 + slot) — the
  // canonical key encoding is 8 bytes, big-endian
  syntax Bytes ::= JCanonKeys ( List ) [function, total]
  rule JCanonKeys(.List) => .Bytes
  rule JCanonKeys(ListItem(K:Int) REST:List)
    => Int2Bytes(8, K, BE) +Bytes JCanonKeys(REST)

  // invariant canon: id || kind || heId || lo/cap || hi || nKeys || keys
  //   kind 1 = local (lo/hi), kind 2 = sum (cap/0), kind 3 = eq (0/0)
  syntax Int ::= "JInvKindLocal" [function, total]
  syntax Int ::= "JInvKindSum"   [function, total]
  syntax Int ::= "JInvKindEq"    [function, total]
  rule JInvKindLocal => 1
  rule JInvKindSum   => 2
  rule JInvKindEq    => 3

  syntax Bytes ::= JCanonInv ( JInv ) [function, total]
  rule JCanonInv(jInvLocal(I:Int, K:Int, LO:Int, HI:Int))
    => I2B4(I) +Bytes I2B4(JInvKindLocal) +Bytes I2B4(0) +Bytes I2B4(LO)
       +Bytes I2B4(HI) +Bytes I2B4(1) +Bytes Int2Bytes(8, K, BE)
  rule JCanonInv(jInvSum(I:Int, HE:Int, KS:List, CAP:Int))
    => I2B4(I) +Bytes I2B4(JInvKindSum) +Bytes I2B4(HE) +Bytes I2B4(CAP)
       +Bytes I2B4(0) +Bytes I2B4(size(KS)) +Bytes JCanonKeys(KS)
  rule JCanonInv(jInvEq(I:Int, HE:Int, KS:List))
    => I2B4(I) +Bytes I2B4(JInvKindEq) +Bytes I2B4(HE) +Bytes I2B4(0)
       +Bytes I2B4(0) +Bytes I2B4(size(KS)) +Bytes JCanonKeys(KS)

  syntax Bytes ::= JCanonInvs ( List ) [function, total]
  rule JCanonInvs(.List) => .Bytes
  rule JCanonInvs(ListItem(V:JInv) REST:List)
    => JCanonInv(V) +Bytes JCanonInvs(REST)

  // the full canonical catalog preimage
  syntax Bytes ::= JCatalogCanonJ ( JCatalog ) [function, total]
  rule JCatalogCanonJ(P:JCatalog)
    => JCatDomainSep
       +Bytes I2B4(JCatEncodingVersion)
       +Bytes I2B4(jcPolicyVOf(P))
       +Bytes I2B4(size(jcAppsOf(P)))      +Bytes JCanonApps(jcAppsOf(P))
       +Bytes I2B4(size(jcResourcesOf(P))) +Bytes JCanonResources(jcResourcesOf(P))
       +Bytes I2B4(size(jcHypersOf(P)))    +Bytes JCanonHypers(jcHypersOf(P))
       +Bytes I2B4(size(jcLocalsOf(P)))    +Bytes JCanonInvs(jcLocalsOf(P))
       +Bytes I2B4(size(jcHypersInvOf(P))) +Bytes JCanonInvs(jcHypersInvOf(P))
       +Bytes I2B4(size(jcGlobalsOf(P)))   +Bytes JCanonInvs(jcGlobalsOf(P))

  // the three content-class sub-roots (NEW tags 0xB1/0xB2/0xB3) + full root
  syntax Bytes ::= JAppSetRootJ ( JCatalog ) [function]
  rule JAppSetRootJ(P:JCatalog)
    => LinH( Int2Bytes(1, 177, BE)   // 0xB1
             +Bytes JCanonApps(jcAppsOf(P)) +Bytes JCanonResources(jcResourcesOf(P)) )

  syntax Bytes ::= JGraphRootJ ( JCatalog ) [function]
  rule JGraphRootJ(P:JCatalog)
    => LinH( Int2Bytes(1, 178, BE)   // 0xB2
             +Bytes JCanonHypers(jcHypersOf(P)) )

  syntax Bytes ::= JPolicyRootJ ( JCatalog ) [function]
  rule JPolicyRootJ(P:JCatalog)
    => LinH( Int2Bytes(1, 179, BE)   // 0xB3
             +Bytes JCanonInvs(jcLocalsOf(P))
             +Bytes JCanonInvs(jcHypersInvOf(P))
             +Bytes JCanonInvs(jcGlobalsOf(P)) )

  syntax Bytes ::= JCatalogRootJ ( JCatalog ) [function]
  rule JCatalogRootJ(P:JCatalog) => LinH(JCatalogCanonJ(P))

  // --------------------------------------------------------------------------
  // §B.2 catalog lookup + well-formedness (fail-closed; handoff §5.1:
  //      "An unresolvable resource, unknown app, missing dependency,
  //      duplicate/conflicting mapping, or digest mismatch must fail closed").
  // --------------------------------------------------------------------------

  // resource lookup: the owner of a key, or -1 if unregistered
  syntax Int ::= JResOwnerOf ( List , Int ) [function, total]
  rule JResOwnerOf(.List, _:Int) => -1
  rule JResOwnerOf(ListItem(jRes(K:Int, O:Int)) REST:List, K2:Int) => O:Int
    requires K ==Int K2
  rule JResOwnerOf(ListItem(jRes(K:Int, _:Int)) REST:List, K2:Int)
    => JResOwnerOf(REST, K2)  requires K =/=Int K2

  // hyperedge lookup: the node list of a hyperedge id, or noHyperJ
  syntax JHyperOrNone ::= JHyper | "noHyperJ"
  syntax JHyperOrNone ::= JHyperAt ( List , Int ) [function, total]
  rule JHyperAt(.List, _:Int) => noHyperJ
  rule JHyperAt(ListItem(H:JHyper) REST:List, I:Int) => H:JHyper
    requires jhIdOf(H) ==Int I
  rule JHyperAt(ListItem(H:JHyper) REST:List, I:Int) => JHyperAt(REST, I)
    requires jhIdOf(H) =/=Int I

  // app-id membership in the registered app list
  syntax Bool ::= JAppRegistered ( List , Int ) [function, total]
  rule JAppRegistered(.List, _:Int) => false
  rule JAppRegistered(ListItem(A:JApp) REST:List, I:Int) => true
    requires jaIdOf(A) ==Int I
  rule JAppRegistered(ListItem(A:JApp) REST:List, I:Int)
    => JAppRegistered(REST, I)  requires jaIdOf(A) =/=Int I

  // key membership in the registered resource list
  syntax Bool ::= JKeyRegistered ( List , Int ) [function, total]
  rule JKeyRegistered(.List, _:Int) => false
  rule JKeyRegistered(ListItem(R:JResource) REST:List, K:Int) => true
    requires jrKeyOf(R) ==Int K
  rule JKeyRegistered(ListItem(R:JResource) REST:List, K:Int)
    => JKeyRegistered(REST, K)  requires jrKeyOf(R) =/=Int K

  // invariant-node list registered?
  syntax Bool ::= JKeysRegistered ( List , List ) [function, total]
  rule JKeysRegistered(.List, _:List) => true
  rule JKeysRegistered(ListItem(K:Int) REST:List, RS:List)
    => JKeyRegistered(RS, K) andBool JKeysRegistered(REST, RS)

  // hyperedge-id membership
  syntax Bool ::= JHeRegistered ( List , Int ) [function, total]
  rule JHeRegistered(.List, _:Int) => false
  rule JHeRegistered(ListItem(H:JHyper) REST:List, I:Int) => true
    requires jhIdOf(H) ==Int I
  rule JHeRegistered(ListItem(H:JHyper) REST:List, I:Int)
    => JHeRegistered(REST, I)  requires jhIdOf(H) =/=Int I

  // duplicate-id checks (no duplicate app ids / resource keys / hyperedge
  // ids / invariant ids — the conflicting-mapping refusal)
  syntax Bool ::= JNoDupApps ( List ) [function, total]
  rule JNoDupApps(.List) => true
  rule JNoDupApps(ListItem(A:JApp) REST:List)
    => notBool JAppRegistered(REST, jaIdOf(A)) andBool JNoDupApps(REST)

  syntax Bool ::= JNoDupRes ( List ) [function, total]
  rule JNoDupRes(.List) => true
  rule JNoDupRes(ListItem(R:JResource) REST:List)
    => notBool JKeyRegistered(REST, jrKeyOf(R)) andBool JNoDupRes(REST)

  syntax Bool ::= JNoDupHypers ( List ) [function, total]
  rule JNoDupHypers(.List) => true
  rule JNoDupHypers(ListItem(H:JHyper) REST:List)
    => notBool JHeRegistered(REST, jhIdOf(H)) andBool JNoDupHypers(REST)

  syntax Bool ::= JNoDupInvs ( List ) [function, total]
  rule JNoDupInvs(.List) => true
  rule JNoDupInvs(ListItem(V:JInv) REST:List)
    => notBool JIdInInvs(REST, jiIdOf(V)) andBool JNoDupInvs(REST)

  syntax Bool ::= JIdInInvs ( List , Int ) [function, total]
  rule JIdInInvs(.List, _:Int) => false
  rule JIdInInvs(ListItem(V:JInv) REST:List, I:Int) => true
    requires jiIdOf(V) ==Int I
  rule JIdInInvs(ListItem(V:JInv) REST:List, I:Int)
    => JIdInInvs(REST, I)  requires jiIdOf(V) =/=Int I

  // well-formedness of the whole catalog (all classes, fail-closed)
  syntax Bool ::= JCatalogWF ( JCatalog ) [function, total]
  rule JCatalogWF(P:JCatalog)
    => size(jcAppsOf(P)) >=Int 1
       andBool JNoDupApps(jcAppsOf(P))
       andBool JNoDupRes(jcResourcesOf(P))
       andBool JNoDupHypers(jcHypersOf(P))
       andBool JNoDupInvs(jcLocalsOf(P)) andBool JNoDupInvs(jcHypersInvOf(P))
       andBool JNoDupInvs(jcGlobalsOf(P))
       andBool JResAllOwned(jcResourcesOf(P), jcAppsOf(P))
       andBool JHyperAllNodesReg(jcHypersOf(P), jcResourcesOf(P))
       andBool JInvsAllNodesReg(jcLocalsOf(P), jcResourcesOf(P))
       andBool JInvsAllNodesReg(jcHypersInvOf(P), jcResourcesOf(P))
       andBool JInvsAllNodesReg(jcGlobalsOf(P), jcResourcesOf(P))
       andBool JInvsAllHesReg(jcHypersInvOf(P), jcHypersOf(P))

  // every resource's owner is a registered app
  syntax Bool ::= JResAllOwned ( List , List ) [function, total]
  rule JResAllOwned(.List, _:List) => true
  rule JResAllOwned(ListItem(R:JResource) REST:List, AS:List)
    => JAppRegistered(AS, jrOwnerOf(R)) andBool JResAllOwned(REST, AS)

  // every hyperedge node is a registered resource key
  syntax Bool ::= JHyperAllNodesReg ( List , List ) [function, total]
  rule JHyperAllNodesReg(.List, _:List) => true
  rule JHyperAllNodesReg(ListItem(H:JHyper) REST:List, RS:List)
    => JKeysRegistered(jhNodesOf(H), RS) andBool JHyperAllNodesReg(REST, RS)

  // every invariant node list is registered
  syntax Bool ::= JInvsAllNodesReg ( List , List ) [function, total]
  rule JInvsAllNodesReg(.List, _:List) => true
  rule JInvsAllNodesReg(ListItem(V:JInv) REST:List, RS:List)
    => JInvNodesReg(V, RS) andBool JInvsAllNodesReg(REST, RS)

  syntax Bool ::= JInvNodesReg ( JInv , List ) [function, total]
  rule JInvNodesReg(jInvLocal(_:Int, K:Int, _:Int, _:Int), RS:List)
    => JKeyRegistered(RS, K)
  rule JInvNodesReg(jInvSum(_:Int, _:Int, KS:List, _:Int), RS:List)
    => JKeysRegistered(KS, RS)
  rule JInvNodesReg(jInvEq(_:Int, _:Int, KS:List), RS:List)
    => JKeysRegistered(KS, RS)

  // hyperedge invariants name registered hyperedges
  syntax Bool ::= JInvsAllHesReg ( List , List ) [function, total]
  rule JInvsAllHesReg(.List, _:List) => true
  rule JInvsAllHesReg(ListItem(V:JInv) REST:List, HS:List)
    => JInvHeReg(V, HS) andBool JInvsAllHesReg(REST, HS)

  syntax Bool ::= JInvHeReg ( JInv , List ) [function, total]
  rule JInvHeReg(jInvLocal(_:Int, _:Int, _:Int, _:Int), _:List) => true
  rule JInvHeReg(jInvSum(_:Int, HE:Int, _:List, _:Int), HS:List)
    => JHeRegistered(HS, HE)
  rule JInvHeReg(jInvEq(_:Int, HE:Int, _:List), HS:List)
    => JHeRegistered(HS, HE)

  // ===========================================================================
  // §C. THE CLOSED EXECUTION FRAGMENT EVM_F (handoff §4.1 Option A) — the
  //     ONLY trace producer in the J machine.
  // ===========================================================================

  // the fragment vocabulary (the frozen 1F four-event fragment, J form);
  // jUnsupported(n) names an EXCLUDED effect class explicitly (never a
  // silent no-op): concrete n is the excluded op code.
  syntax JOp ::= jRead    ( ja:Int , js:Int )
              | jWrite    ( ja:Int , js:Int , jv:Int )
              | jCall     ( ja:Int , jt:Int , jv:Int )
              | jReturn   ( ja:Int , jo:Int , jz:Int )
              | jUnsupported ( jn:Int )

  syntax Int ::= "JOpRead"    [function, total]
  syntax Int ::= "JOpWrite"   [function, total]
  syntax Int ::= "JOpCall"    [function, total]
  syntax Int ::= "JOpReturn"  [function, total]
  rule JOpRead   => 1
  rule JOpWrite  => 2
  rule JOpCall   => 3
  rule JOpReturn => 4

  // the flat key space (the frozen 1E convention: k = app*2^32 + slot)
  syntax Int ::= "JBoundApp" [function, total]
  syntax Int ::= "JBoundVal" [function, total]
  rule JBoundApp => 4294967296              // 2^32
  rule JBoundVal => 18446744073709551616    // 2^64

  syntax Int ::= A2Key ( Int , Int ) [function, total]
  rule A2Key(A:Int, SL:Int) => A *Int JBoundApp +Int SL

  // the state reader — the J state uses the SAME nested representation as
  // the frozen lineage maps (Map app:Int -> Map slot:Int -> val:Int), so the
  // derived Q/E/P maps feed ExecBuildRecF directly; the flat 1E key space
  // (k = app*2^32 + slot) is the CATALOG/footprint identity (J-StateGet).
  // Uninitialized storage reads 0 (the EVM convention; documented).
  syntax Int ::= JStateGet ( Map , Int ) [function, total]
  rule JStateGet(S:Map, K:Int)
    => JSlotGet( JInnerAt(S, K /Int JBoundApp), K modInt JBoundApp )

  syntax Map ::= JInnerAt ( Map , Int ) [function, total]
  rule JInnerAt(A:Int |-> INNER:Map _:Map, A2:Int) => INNER:Map
    requires A ==Int A2
  rule JInnerAt(A:Int |-> _:Map REST:Map, A2:Int) => JInnerAt(REST, A2)
    requires A =/=Int A2
  rule JInnerAt(.Map, _:Int) => .Map

  syntax Int ::= JSlotGet ( Map , Int ) [function, total]
  rule JSlotGet(SL:Int |-> V:Int _:Map, SL2:Int) => V:Int
    requires SL ==Int SL2
  rule JSlotGet(SL:Int |-> _:Int REST:Map, SL2:Int) => JSlotGet(REST, SL2)
    requires SL =/=Int SL2
  rule JSlotGet(.Map, _:Int) => 0

  // the nested write (merge into the app's inner map)
  syntax Map ::= JNestedWrite ( Map , Int , Int , Int ) [function, total]
  rule JNestedWrite(S:Map, A:Int, SL:Int, V:Int)
    => S[ A <- JInnerAt(S, A) [SL <- V] ]

  // the execution result: OK derives (post-state P, effective write-delta E,
  // ordered trace T); the two refusal classes carry the refusing op — a
  // refusal has NO post-state, NO footprint, NO receipt (fail-closed).
  syntax JExecResult ::= jExecOk        ( jeqPost:Map , jeqEff:Map
                                       , jeqTrace:List )
                      | jExecUnsupported ( jeuOp:Int )
                      | jExecBounds      ( jebOp:Int )

  // THE FRAGMENT INTERPRETER.  The trace is EMITTED BY THE SEMANTICS in
  // exact execution order (J-TRACE-ORIGIN, by rule inventory: the only
  // producers of jExecOk traces are these rules).  The pre-state threads
  // through writes; a Read observes the CURRENT threaded state.
  syntax JExecResult ::= ExecFragmentJ ( Map , List ) [function, total]

  // the empty program: the derived execution is the identity
  rule ExecFragmentJ(S:Map, .List) => jExecOk(S, .Map, .List)

  // the head step + tail recursion (bounded operands only — out-of-range
  // operands hit the explicit JExecBounds rules below)
  syntax Bool ::= NotUnsupportedJ ( JOp ) [function, total]
  rule NotUnsupportedJ(jUnsupported(_:Int)) => false
  rule NotUnsupportedJ(_:JOp) => true [owise]

  rule ExecFragmentJ(S:Map, ListItem(OP:JOp) REST:List)
    => ExecFragmentStep(S, OP, ExecFragmentJ(JExecThreadState(S, OP), REST))
    requires JOpInBounds(OP) andBool NotUnsupportedJ(OP)

  // thread the state through a Write (the only state-changing fragment op;
  // the nested merge keeps prior slots of the same app)
  syntax Map ::= JExecThreadState ( Map , JOp ) [function, total]
  rule JExecThreadState(S:Map, jWrite(A:Int, SL:Int, V:Int))
    => JNestedWrite(S, A, SL, V)
  rule JExecThreadState(S:Map, _:JOp) => S:Map [owise]

  // fragment operand bounds (the 1F field bounds; violation = the explicit
  // refusal class, never silent)
  syntax Bool ::= JOpInBounds ( JOp ) [function, total]
  rule JOpInBounds(jRead(A:Int, S:Int))
    => 0 <=Int A andBool A <Int JBoundApp
       andBool 0 <=Int S andBool S <Int JBoundApp
  rule JOpInBounds(jWrite(A:Int, S:Int, V:Int))
    => 0 <=Int A andBool A <Int JBoundApp
       andBool 0 <=Int S andBool S <Int JBoundApp
       andBool 0 <=Int V andBool V <Int JBoundVal
  rule JOpInBounds(jCall(A:Int, T:Int, V:Int))
    => 0 <=Int A andBool A <Int JBoundApp
       andBool 0 <=Int T andBool T <Int JBoundApp
       andBool 0 <=Int V andBool V <Int JBoundVal
  rule JOpInBounds(jReturn(A:Int, O:Int, Z:Int))
    => 0 <=Int A andBool A <Int JBoundApp
       andBool 0 <=Int O andBool O <Int JBoundApp
       andBool 0 <=Int Z andBool Z <Int JBoundApp
  rule JOpInBounds(jUnsupported(_:Int)) => true

  // the head-step projector: prepends the head event (execution order) and
  // merges the effective write-delta (later writes override earlier ones;
  // the tail's delta already holds every later write, so the head write is
  // inserted under it).
  syntax JExecResult ::= ExecFragmentStep ( Map , JOp , JExecResult )
                        [function, total]

  rule ExecFragmentStep(S:Map, jRead(A:Int, SL:Int),
                        jExecOk(P:Map, E:Map, T:List))
    => jExecOk(P, E,
               ListItem(exEvt(JOpRead, A, SL, JStateGet(S, A2Key(A, SL)))) T)
  rule ExecFragmentStep(_:Map, jWrite(A:Int, SL:Int, V:Int),
                        jExecOk(P:Map, E:Map, T:List))
    => jExecOk(P, JNestedWrite(E, A, SL, V),
               ListItem(exEvt(JOpWrite, A, SL, V)) T)
  rule ExecFragmentStep(_:Map, jCall(A:Int, T2:Int, V:Int),
                        jExecOk(P:Map, E:Map, T:List))
    => jExecOk(P, E, ListItem(exEvt(JOpCall, A, T2, V)) T)
  rule ExecFragmentStep(_:Map, jReturn(A:Int, O:Int, Z:Int),
                        jExecOk(P:Map, E:Map, T:List))
    => jExecOk(P, E, ListItem(exEvt(JOpReturn, A, O, Z)) T)

  // refusals propagate unchanged: once the execution refuses, there is no
  // derived post-state (the prefix effects are discarded with the run)
  rule ExecFragmentStep(_:Map, _:JOp, jExecUnsupported(N:Int))
    => jExecUnsupported(N:Int)
  rule ExecFragmentStep(_:Map, _:JOp, jExecBounds(N:Int))
    => jExecBounds(N:Int)

  // EXCLUDED EFFECT: explicit refusal (handoff §4.1: must "produce an
  // explicit unsupported-effect/invalid-execution-fragment refusal; it must
  // not be skipped, approximated as a harmless no-op, or silently omitted")
  rule ExecFragmentJ(_:Map, ListItem(jUnsupported(N:Int)) _:List)
    => jExecUnsupported(N:Int)

  // FIELD-BOUNDS refusal: the same fail-closed discipline for out-of-range
  // operands (the 1F invalid-execbounds class)
  rule ExecFragmentJ(_:Map, ListItem(OP:JOp) _:List)
    => jExecBounds(JOpCodeOf(OP))
    requires notBool JOpInBounds(OP)

  syntax Int ::= JOpCodeOf ( JOp ) [function, total]
  rule JOpCodeOf(jRead(_:Int, _:Int))         => JOpRead
  rule JOpCodeOf(jWrite(_:Int, _:Int, _:Int)) => JOpWrite
  rule JOpCodeOf(jCall(_:Int, _:Int, _:Int))  => JOpCall
  rule JOpCodeOf(jReturn(_:Int, _:Int, _:Int)) => JOpReturn
  rule JOpCodeOf(jUnsupported(N:Int))         => N:Int

  // ===========================================================================
  // §D. STATE ROOT / TRACE / FOOTPRINT (the derived projections)
  // ===========================================================================

  // the canonical J program encoding (the payload preimage; NEW tag 0xB8 =
  // 184 — distinct from the frozen 1F trace tag 0x03 and payload tag 0x11)
  syntax Bytes ::= JProgCanonJ ( List ) [function, total]
  rule JProgCanonJ(.List) => .Bytes
  rule JProgCanonJ(ListItem(jRead(A:Int, S:Int)) REST:List)
    => Int2Bytes(1, JOpRead, BE) +Bytes I2B4(A)  +Bytes Int2Bytes(8, S, BE)
       +Bytes JProgCanonJ(REST)
  rule JProgCanonJ(ListItem(jWrite(A:Int, S:Int, V:Int)) REST:List)
    => Int2Bytes(1, JOpWrite, BE) +Bytes I2B4(A)  +Bytes Int2Bytes(8, S, BE)  +Bytes Int2Bytes(8, V, BE)
       +Bytes JProgCanonJ(REST)
  rule JProgCanonJ(ListItem(jCall(A:Int, T:Int, V:Int)) REST:List)
    => Int2Bytes(1, JOpCall, BE) +Bytes I2B4(A)  +Bytes Int2Bytes(8, T, BE)  +Bytes Int2Bytes(8, V, BE)
       +Bytes JProgCanonJ(REST)
  rule JProgCanonJ(ListItem(jReturn(A:Int, O:Int, Z:Int)) REST:List)
    => Int2Bytes(1, JOpReturn, BE) +Bytes I2B4(A)  +Bytes Int2Bytes(8, O, BE)  +Bytes Int2Bytes(8, Z, BE)
       +Bytes JProgCanonJ(REST)
  rule JProgCanonJ(ListItem(jUnsupported(N:Int)) REST:List)
    => Int2Bytes(1, 255, BE)  +Bytes Int2Bytes(8, N, BE) +Bytes JProgCanonJ(REST)

  // the canonical program bytes: count || canon.  The PAYLOAD DIGEST reuses
  // the FROZEN 1F formula UNCHANGED (ExecPayloadDigest = Keccak(0x11 || PL),
  // srw3exec.k) applied to these bytes — the same digest family the frozen
  // authority certificate binds (azCPayloadD), so the J candidate, the exec
  // receipt, and the certificate share ONE payload identity.  No new payload
  // tag is introduced (the 0xB8 tag inside the canon is the program-encoding
  // domain separator; the frozen 0x11 prefix remains the payload-digest tag).
  syntax Bytes ::= JProgBytesJ ( List ) [function, total]
  rule JProgBytesJ(PG:List)
    => I2B4(size(PG)) +Bytes JProgCanonJ(PG)

  syntax Bytes ::= JPayloadDigestJ ( List ) [function]
  rule JPayloadDigestJ(PG:List) => ExecPayloadDigest(JProgBytesJ(PG))

  // the J state root — NEW tag 0xB4 = 180 over the frozen ascending map canon
  syntax Int ::= "JStateTagJ" [function, total]
  rule JStateTagJ => 180   // 0xB4

  syntax Bytes ::= StateRootJ ( Map ) [function]
  rule StateRootJ(S:Map) => LinH( Int2Bytes(1, JStateTagJ, BE)
                                  +Bytes LinCanonKV(S) )

  // the trace digest — the FROZEN 1F order-preserving trace encoding
  // (ExecTraceDigest over the 1F event list; order is never destroyed)
  syntax Bytes ::= JTraceDigestJ ( List ) [function]
  rule JTraceDigestJ(T:List) => ExecTraceDigest(T)

  // the footprint — first-occurrence projection of the trace onto touched
  // resource keys (deterministic given the trace; the footprint is DERIVED,
  // never caller-supplied — handoff §3: F is "projected from the trace")
  syntax List ::= JFootprintKeysOf ( List ) [function, total]
  rule JFootprintKeysOf(.List) => .List
  rule JFootprintKeysOf(ListItem(exEvt(_:Int, A:Int, S:Int, _:Int)) REST:List)
    => JFPAppend(A2Key(A, S), JFootprintKeysOf(REST))

  // the footprint preserves FIRST-OCCURRENCE order (append-at-end; the
  // byte-identical Python mirror's semantics)
  syntax List ::= JFPAppend ( Int , List ) [function, total]
  rule JFPAppend(K:Int, .List) => ListItem(K) .List
  rule JFPAppend(K:Int, ListItem(K2:Int) REST:List) => ListItem(K2) JFPAppend(K, REST)
    requires K =/=Int K2
  rule JFPAppend(K:Int, ListItem(K2:Int) REST:List) => ListItem(K2) REST:List
    requires K ==Int K2

  syntax List ::= JFPCons ( Int , List ) [function, total]
  rule JFPCons(K:Int, KS:List) => KS:List  requires JKeyInList(K, KS)
  rule JFPCons(K:Int, KS:List) => ListItem(K) KS:List
    requires notBool JKeyInList(K, KS)

  syntax Bool ::= JKeyInList ( Int , List ) [function, total]
  rule JKeyInList(_:Int, .List) => false
  rule JKeyInList(K:Int, ListItem(K2:Int) REST:List) => true
    requires K ==Int K2
  rule JKeyInList(K:Int, ListItem(K2:Int) REST:List) => JKeyInList(K, REST)
    requires K =/=Int K2

  // footprint canon (NEW tag 0xB7 = 183): count || keys in first-occurrence
  // order; the footprint digest binds the complete touched-key set AND its
  // derivation order
  syntax Bytes ::= JFootprintCanonJ ( List ) [function, total]
  rule JFootprintCanonJ(KS:List)
    => Int2Bytes(1, 183, BE) +Bytes I2B4(size(KS)) +Bytes JCanonKeys(KS)

  syntax Bytes ::= JFootprintDigestJ ( List ) [function]
  rule JFootprintDigestJ(T:List) => LinH(JFootprintCanonJ(JFootprintKeysOf(T)))

  // ===========================================================================
  // §E. EVIDENCE IDENTITY (handoff §4.3) — NEW domain "SRW3/Evidence/J",
  //     version 1, length-delimited; binds config root, catalog root,
  //     chain/fork identity, parent/post state roots, payload digest,
  //     execution-source identity, ordered trace digest, complete footprint
  //     digest, and the policy-context digest (NEW tag 0xB5 = 181).
  // ===========================================================================

  syntax Bytes ::= "JEvidenceDomainSep" [function, total]
  rule JEvidenceDomainSep
    => LinHex("535257332f45766964656e63652f4a00")   // "SRW3/Evidence/J" || 0x00

  syntax Int ::= "JEvidenceEncodingVersion" [function, total]
  rule JEvidenceEncodingVersion => 1

  // the policy-context digest: configRoot || catalogRoot || policyVersion
  // (the J policy evaluation context; NEW tag 0xB5)
  syntax Bytes ::= JPolicyCtxDigestJ ( Bytes , Bytes , Int ) [function]
  rule JPolicyCtxDigestJ(CR:Bytes, CAT:Bytes, PV:Int)
    => LinH( Int2Bytes(1, 181, BE)   // 0xB5
             +Bytes LP32R3(CR) +Bytes LP32R3(CAT) +Bytes I2B4(PV) )

  syntax Bytes ::= EvidenceCanonJ ( Bytes    /* configRootR3 */
                                  , Bytes    /* catalogRootJ */
                                  , Bytes    /* chainId */
                                  , Bytes    /* fork */
                                  , Bytes    /* parentStateRootJ */
                                  , Bytes    /* payloadDigestJ */
                                  , Bytes    /* execSourceId */
                                  , Bytes    /* postStateRootJ */
                                  , Bytes    /* orderedTraceDigest */
                                  , Bytes    /* completeFootprintDigest */
                                  , Bytes )  /* policyContextDigest */
    [function, total]
  rule EvidenceCanonJ(CR:Bytes, CAT:Bytes, CH:Bytes, FK:Bytes, PR:Bytes,
                      PL:Bytes, SR:Bytes, PO:Bytes, TD:Bytes, FD:Bytes,
                      PX:Bytes)
    => JEvidenceDomainSep
       +Bytes I2B4(JEvidenceEncodingVersion)
       +Bytes LP32R3(CR) +Bytes LP32R3(CAT) +Bytes LP32R3(CH)
       +Bytes LP32R3(FK) +Bytes LP32R3(PR) +Bytes LP32R3(PL)
       +Bytes LP32R3(SR) +Bytes LP32R3(PO) +Bytes LP32R3(TD)
       +Bytes LP32R3(FD) +Bytes LP32R3(PX)

  syntax Bytes ::= EvidenceIDJ ( Bytes , Bytes , Bytes , Bytes , Bytes ,
                                 Bytes , Bytes , Bytes , Bytes , Bytes ,
                                 Bytes ) [function]
  rule EvidenceIDJ(CR:Bytes, CAT:Bytes, CH:Bytes, FK:Bytes, PR:Bytes,
                   PL:Bytes, SR:Bytes, PO:Bytes, TD:Bytes, FD:Bytes, PX:Bytes)
    => LinH(EvidenceCanonJ(CR, CAT, CH, FK, PR, PL, SR, PO, TD, FD, PX))

  // ===========================================================================
  // §F. SAFETY: THE TYPED INVARIANT FRAGMENT + Safe_P (handoff §3/§6) —
  //     DEFINED INDEPENDENTLY OF THE ACCEPT TRANSITION (never "the gate
  //     accepted").
  // ===========================================================================

  // one invariant instance on the abstract state
  syntax Bool ::= InvHoldsJ ( JInv , Map ) [function, total]
  rule InvHoldsJ(jInvLocal(_:Int, K:Int, LO:Int, HI:Int), S:Map)
    => LO <=Int JStateGet(S, K) andBool JStateGet(S, K) <=Int HI
  rule InvHoldsJ(jInvSum(_:Int, _:Int, KS:List, CAP:Int), S:Map)
    => JSumOf(S, KS) <=Int CAP
  rule InvHoldsJ(jInvEq(_:Int, _:Int, KS:List), S:Map)
    => JAllEqOf(S, KS)

  // sum over a key list (uninitialized reads 0)
  syntax Int ::= JSumOf ( Map , List ) [function, total]
  rule JSumOf(_:Map, .List) => 0
  rule JSumOf(S:Map, ListItem(K:Int) REST:List)
    => JStateGet(S, K) +Int JSumOf(S, REST)

  // all values equal
  syntax Bool ::= JAllEqOf ( Map , List ) [function, total]
  rule JAllEqOf(_:Map, .List) => true
  rule JAllEqOf(_:Map, ListItem(_:Int) .List) => true
  rule JAllEqOf(S:Map, ListItem(K1:Int) ListItem(K2:Int) REST:List)
    => JStateGet(S, K1) ==Int JStateGet(S, K2)
       andBool JAllEqOf(S, ListItem(K2:Int) REST:List)

  // the three invariant classes (handoff §3 Safe_P shape)
  syntax Bool ::= AllLocalJ ( List , Map ) [function, total]
  rule AllLocalJ(.List, _:Map) => true
  rule AllLocalJ(ListItem(V:JInv) REST:List, S:Map)
    => InvHoldsJ(V, S) andBool AllLocalJ(REST, S)

  syntax Bool ::= AllHyperJ ( List , Map ) [function, total]
  rule AllHyperJ(.List, _:Map) => true
  rule AllHyperJ(ListItem(V:JInv) REST:List, S:Map)
    => InvHoldsJ(V, S) andBool AllHyperJ(REST, S)

  syntax Bool ::= AllGlobalJ ( List , Map ) [function, total]
  rule AllGlobalJ(.List, _:Map) => true
  rule AllGlobalJ(ListItem(V:JInv) REST:List, S:Map)
    => InvHoldsJ(V, S) andBool AllGlobalJ(REST, S)

  // Safe_P(σ) — the safety predicate, INDEPENDENT of the gate/commit guard:
  // AND over every registered local invariant, every registered hyperedge
  // invariant, and every registered global invariant, evaluated on σ.
  syntax Bool ::= SafeJ ( JCatalog , Map ) [function, total]
  rule SafeJ(P:JCatalog, S:Map)
    => AllLocalJ(jcLocalsOf(P), S)
       andBool AllHyperJ(jcHypersInvOf(P), S)
       andBool AllGlobalJ(jcGlobalsOf(P), S)

  // ===========================================================================
  // §G. THE BOUNDED HYPERGRAPH CLOSURE (handoff §5.2) — the least closure of
  //     the touched keys + every hyperedge incident to any touched node +
  //     the additional nodes needed to evaluate each such invariant, to a
  //     fixed point, under an explicit fuel bound.  Exhaustion REJECTS
  //     (never "no more interactions"); the touched keys must all be
  //     REGISTERED resources (the unknown/ambiguous-mapping refusal is the
  //     separate guard conjunct JFootprintRegistered, §H).
  // ===========================================================================

  syntax JClosure ::= jClosureOk ( jclAffected:List )
                   | "jClosureExhausted"

  syntax JClosure ::= AffectedClosureJ ( List /*affected keys*/
                                       , List /*hyperedges*/
                                       , Int /*fuel rounds*/ )
                     [function, total]

  // one round: compute the union of the node sets of all hyperedges
  // incident to the current affected set, then grow.
  rule AffectedClosureJ(AFF:List, HS:List, FUEL:Int)
    => JClosureRound(AFF, JIncidentUnion(AFF, HS), HS, FUEL)

  // union of the node lists of all INCIDENT hyperedges
  syntax List ::= JIncidentUnion ( List , List ) [function, total]
  rule JIncidentUnion(_:List, .List) => .List
  rule JIncidentUnion(AFF:List, ListItem(H:JHyper) REST:List)
    => JListUnionIf(JHeTouches(H, AFF), jhNodesOf(H),
                    JIncidentUnion(AFF, REST))

  syntax Bool ::= JHeTouches ( JHyper , List ) [function, total]
  rule JHeTouches(_:JHyper, .List) => false
  rule JHeTouches(H:JHyper, ListItem(K:Int) REST:List)
    => JKeyInList(K, jhNodesOf(H)) orBool JHeTouches(H, REST)

  syntax List ::= JListUnionIf ( Bool , List , List ) [function, total]
  rule JListUnionIf(true, ADD:List, ACC:List) => JListUnion(ADD, ACC)
  rule JListUnionIf(false, _:List, ACC:List) => ACC:List

  // the grow step: if the incident union added nothing, the closure is at
  // its fixed point; else one fuel round is consumed (0 fuel left with
  // growth still needed => EXHAUSTED => reject, handoff §5.2).
  syntax JClosure ::= JClosureRound ( List , List , List , Int )
                     [function, total]
  rule JClosureRound(AFF:List, INC:List, _:List, _:Int)
    => jClosureOk(AFF:List)
    requires JNoNewKeys(INC, AFF)
  rule JClosureRound(AFF:List, INC:List, HS:List, 0)
    => jClosureExhausted
    requires notBool JNoNewKeys(INC, AFF)
  rule JClosureRound(AFF:List, INC:List, HS:List, FUEL:Int)
    => AffectedClosureJ(JListUnion(INC, AFF), HS, FUEL -Int 1)
    requires notBool JNoNewKeys(INC, AFF) andBool FUEL >=Int 1

  syntax Bool ::= JNoNewKeys ( List , List ) [function, total]
  rule JNoNewKeys(.List, _:List) => true
  rule JNoNewKeys(ListItem(K:Int) REST:List, AFF:List)
    => JKeyInList(K, AFF) andBool JNoNewKeys(REST, AFF)

  syntax List ::= JListUnion ( List , List ) [function, total]
  rule JListUnion(.List, ACC:List) => ACC:List
  rule JListUnion(ListItem(K:Int) REST:List, ACC:List)
    => JListUnion(REST, JFPCons(K, ACC))

  // the touched keys must ALL be registered resources (an unregistered key
  // in the footprint is the unknown/ambiguous-mapping refusal — J-A11)
  syntax Bool ::= JFootprintRegistered ( List , List ) [function, total]
  rule JFootprintRegistered(.List, _:List) => true
  rule JFootprintRegistered(ListItem(K:Int) REST:List, RS:List)
    => JKeyRegistered(RS, K) andBool JFootprintRegistered(REST, RS)

  // ===========================================================================
  // §H. THE J CANDIDATE BLOCK + RECEIPTS
  // ===========================================================================

  // The J candidate block: parent commitment, payload digest (the canonical
  // fragment program), J parent/post state roots, ordered trace digest,
  // complete footprint digest, evidence identity, catalog root, config root,
  // execution-source identity, decision, slot.  EVERY identity field must
  // equal the execution-derived value at the commit boundary (the block
  // fields are candidate data; the derived values are machine state).
  syntax JBlockJ ::= "jBlockJ" "(" jbParentCommit:Bytes ","
                       jbPayloadD:Bytes ","
                       jbParentRoot:Bytes "," jbPostRoot:Bytes ","
                       jbTraceD:Bytes "," jbFootD:Bytes ","
                       jbEvidenceId:Bytes "," jbCatalogRoot:Bytes ","
                       jbConfigRoot:Bytes "," jbExecSrc:Bytes ","
                       jbDecision:Int "," jbSlot:Int ")"

  syntax Bytes ::= jbParentCommitOf ( JBlockJ ) [function, total]
  rule jbParentCommitOf(jBlockJ(PC:Bytes, _:Bytes, _:Bytes, _:Bytes, _:Bytes,
                                _:Bytes, _:Bytes, _:Bytes, _:Bytes, _:Bytes,
                                _:Int, _:Int)) => PC:Bytes
  syntax Bytes ::= jbPayloadDOf ( JBlockJ ) [function, total]
  rule jbPayloadDOf(jBlockJ(_:Bytes, PL:Bytes, _:Bytes, _:Bytes, _:Bytes,
                            _:Bytes, _:Bytes, _:Bytes, _:Bytes, _:Bytes,
                            _:Int, _:Int)) => PL:Bytes
  syntax Bytes ::= jbParentRootOf ( JBlockJ ) [function, total]
  rule jbParentRootOf(jBlockJ(_:Bytes, _:Bytes, PR:Bytes, _:Bytes, _:Bytes,
                              _:Bytes, _:Bytes, _:Bytes, _:Bytes, _:Bytes,
                              _:Int, _:Int)) => PR:Bytes
  syntax Bytes ::= jbPostRootOf ( JBlockJ ) [function, total]
  rule jbPostRootOf(jBlockJ(_:Bytes, _:Bytes, _:Bytes, PO:Bytes, _:Bytes,
                            _:Bytes, _:Bytes, _:Bytes, _:Bytes, _:Bytes,
                            _:Int, _:Int)) => PO:Bytes
  syntax Bytes ::= jbTraceDOf ( JBlockJ ) [function, total]
  rule jbTraceDOf(jBlockJ(_:Bytes, _:Bytes, _:Bytes, _:Bytes, TD:Bytes,
                          _:Bytes, _:Bytes, _:Bytes, _:Bytes, _:Bytes,
                          _:Int, _:Int)) => TD:Bytes
  syntax Bytes ::= jbFootDOf ( JBlockJ ) [function, total]
  rule jbFootDOf(jBlockJ(_:Bytes, _:Bytes, _:Bytes, _:Bytes, _:Bytes,
                         FD:Bytes, _:Bytes, _:Bytes, _:Bytes, _:Bytes,
                         _:Int, _:Int)) => FD:Bytes
  syntax Bytes ::= jbEvidenceIdOf ( JBlockJ ) [function, total]
  rule jbEvidenceIdOf(jBlockJ(_:Bytes, _:Bytes, _:Bytes, _:Bytes, _:Bytes,
                              _:Bytes, EV:Bytes, _:Bytes, _:Bytes, _:Bytes,
                              _:Int, _:Int)) => EV:Bytes
  syntax Bytes ::= jbCatalogRootOf ( JBlockJ ) [function, total]
  rule jbCatalogRootOf(jBlockJ(_:Bytes, _:Bytes, _:Bytes, _:Bytes, _:Bytes,
                               _:Bytes, _:Bytes, CA:Bytes, _:Bytes, _:Bytes,
                               _:Int, _:Int)) => CA:Bytes
  syntax Bytes ::= jbConfigRootOf ( JBlockJ ) [function, total]
  rule jbConfigRootOf(jBlockJ(_:Bytes, _:Bytes, _:Bytes, _:Bytes, _:Bytes,
                              _:Bytes, _:Bytes, _:Bytes, CR:Bytes, _:Bytes,
                              _:Int, _:Int)) => CR:Bytes
  syntax Bytes ::= jbExecSrcOf ( JBlockJ ) [function, total]
  rule jbExecSrcOf(jBlockJ(_:Bytes, _:Bytes, _:Bytes, _:Bytes, _:Bytes,
                           _:Bytes, _:Bytes, _:Bytes, _:Bytes, SR:Bytes,
                           _:Int, _:Int)) => SR:Bytes
  syntax Int ::= jbDecisionOf ( JBlockJ ) [function, total]
  rule jbDecisionOf(jBlockJ(_:Bytes, _:Bytes, _:Bytes, _:Bytes, _:Bytes,
                            _:Bytes, _:Bytes, _:Bytes, _:Bytes, _:Bytes,
                            D:Int, _:Int)) => D:Int
  syntax Int ::= jbSlotOf ( JBlockJ ) [function, total]
  rule jbSlotOf(jBlockJ(_:Bytes, _:Bytes, _:Bytes, _:Bytes, _:Bytes,
                        _:Bytes, _:Bytes, _:Bytes, _:Bytes, _:Bytes,
                        _:Int, SL:Int)) => SL:Int

  // the J block commitment (NEW tag 0xB6 = 182; the frozen 1I block shape
  // is NOT reused — the J block has different fields; the frozen 0x9E
  // formula continues to exist only in the R3 machines)
  syntax Bytes ::= JBlockCommitCanonJ ( JBlockJ , Bytes ) [function, total]
  rule JBlockCommitCanonJ(B:JBlockJ, PC:Bytes)
    => Int2Bytes(1, 182, BE)   // 0xB6
       +Bytes jbParentCommitOf(B) +Bytes jbPayloadDOf(B)
       +Bytes jbParentRootOf(B)   +Bytes jbPostRootOf(B)
       +Bytes jbTraceDOf(B)       +Bytes jbFootDOf(B)
       +Bytes jbEvidenceIdOf(B)   +Bytes jbCatalogRootOf(B)
       +Bytes jbConfigRootOf(B)   +Bytes jbExecSrcOf(B)
       +Bytes I2B4(jbDecisionOf(B)) +Bytes I2B4(jbSlotOf(B))
       +Bytes PC

  syntax Bytes ::= JBlockCommitJ ( JBlockJ , ProtoCfgR3 ) [function]
  rule JBlockCommitJ(B:JBlockJ, C:ProtoCfgR3)
    => LinH(JBlockCommitCanonJ(B, PolicyCommitmentR3(C)))

  // execution binding (the frozen 1I ExecValidP discipline, J form): the
  // block's child root and payload identity must equal the client-derived
  // execution results that the receipts bind.
  syntax Bool ::= ExecValidPJ ( JBlockJ , Bytes , Bytes ) [function, total]
  rule ExecValidPJ(B:JBlockJ, ERC:Bytes, ERP:Bytes)
    => jbPostRootOf(B) ==K ERC  andBool  jbPayloadDOf(B) ==K ERP

  // --------------------------------------------------------------------------
  // §H.1 THE EXECUTION RECEIPT — the ONLY carrier of a derived execution.
  //      Minted ONLY by pExecJ, from the fragment interpreter's result; the
  //      trace/effective-delta/post-state fields are machine-derived, never
  //      caller-supplied.  Consumed exactly once by pCommitJ (via the gate
  //      receipt that embeds it).
  // --------------------------------------------------------------------------
  syntax JExecReceipt ::= "jExecReceipt" "(" jerPayload:Bytes ","
                            jerCaller:Bytes "," jerValue:Int ","
                            jerPre:Map "," jerEff:Map "," jerPost:Map ","
                            jerTrace:List ","
                            jerPreRoot:Bytes "," jerPostRoot:Bytes ","
                            jerTraceD:Bytes "," jerFootD:Bytes ","
                            jerPayloadD:Bytes "," jerExecSrc:Bytes ","
                            jerCfgRoot:Bytes "," jerCatRoot:Bytes ","
                            jerAnchor:Bytes "," jerHead:Bytes ","
                            jerSlot:Int "," jerLinHead:Bytes ","
                            jerEvidenceId:Bytes ")"

  syntax Bytes ::= jerPreRootOf    ( JExecReceipt ) [function, total]
  syntax Map   ::= jerPreOf        ( JExecReceipt ) [function, total]
  syntax Map   ::= jerPostOf       ( JExecReceipt ) [function, total]
  syntax List  ::= jerTraceOf      ( JExecReceipt ) [function, total]
  syntax Bytes ::= jerPostRootOf   ( JExecReceipt ) [function, total]
  syntax Bytes ::= jerTraceDOf     ( JExecReceipt ) [function, total]
  syntax Bytes ::= jerFootDOf      ( JExecReceipt ) [function, total]
  syntax Bytes ::= jerPayloadDOf   ( JExecReceipt ) [function, total]
  syntax Bytes ::= jerExecSrcOf    ( JExecReceipt ) [function, total]
  syntax Bytes ::= jerCfgRootOf    ( JExecReceipt ) [function, total]
  syntax Bytes ::= jerCatRootOf    ( JExecReceipt ) [function, total]
  syntax Bytes ::= jerAnchorOf     ( JExecReceipt ) [function, total]
  syntax Bytes ::= jerHeadOf       ( JExecReceipt ) [function, total]
  syntax Int   ::= jerSlotOf       ( JExecReceipt ) [function, total]
  syntax Bytes ::= jerLinHeadOf    ( JExecReceipt ) [function, total]
  syntax Bytes ::= jerEvidenceIdOf ( JExecReceipt ) [function, total]

  rule jerPreRootOf(jExecReceipt(_:Bytes, _:Bytes, _:Int, _:Map, _:Map,
                                 _:Map, _:List, PR:Bytes, _:Bytes, _:Bytes,
                                 _:Bytes, _:Bytes, _:Bytes, _:Bytes, _:Bytes,
                                 _:Bytes, _:Bytes, _:Int, _:Bytes, _:Bytes))
    => PR:Bytes
  rule jerPreOf(jExecReceipt(_:Bytes, _:Bytes, _:Int, Q:Map, _:Map, _:Map,
                             _:List, _:Bytes, _:Bytes, _:Bytes, _:Bytes,
                             _:Bytes, _:Bytes, _:Bytes, _:Bytes, _:Bytes,
                             _:Bytes, _:Int, _:Bytes, _:Bytes))
    => Q:Map
  rule jerPostOf(jExecReceipt(_:Bytes, _:Bytes, _:Int, _:Map, _:Map, P:Map,
                              _:List, _:Bytes, _:Bytes, _:Bytes, _:Bytes,
                              _:Bytes, _:Bytes, _:Bytes, _:Bytes, _:Bytes,
                              _:Bytes, _:Int, _:Bytes, _:Bytes))
    => P:Map
  rule jerTraceOf(jExecReceipt(_:Bytes, _:Bytes, _:Int, _:Map, _:Map, _:Map,
                               T:List, _:Bytes, _:Bytes, _:Bytes, _:Bytes,
                               _:Bytes, _:Bytes, _:Bytes, _:Bytes, _:Bytes,
                               _:Bytes, _:Int, _:Bytes, _:Bytes))
    => T:List
  rule jerPostRootOf(jExecReceipt(_:Bytes, _:Bytes, _:Int, _:Map, _:Map,
                                  _:Map, _:List, _:Bytes, PO:Bytes, _:Bytes,
                                  _:Bytes, _:Bytes, _:Bytes, _:Bytes,
                                  _:Bytes, _:Bytes, _:Bytes, _:Int,
                                  _:Bytes, _:Bytes))
    => PO:Bytes
  rule jerTraceDOf(jExecReceipt(_:Bytes, _:Bytes, _:Int, _:Map, _:Map, _:Map,
                                _:List, _:Bytes, _:Bytes, TD:Bytes, _:Bytes,
                                _:Bytes, _:Bytes, _:Bytes, _:Bytes, _:Bytes,
                                _:Bytes, _:Int, _:Bytes, _:Bytes))
    => TD:Bytes
  rule jerFootDOf(jExecReceipt(_:Bytes, _:Bytes, _:Int, _:Map, _:Map, _:Map,
                               _:List, _:Bytes, _:Bytes, _:Bytes, FD:Bytes,
                               _:Bytes, _:Bytes, _:Bytes, _:Bytes, _:Bytes,
                               _:Bytes, _:Int, _:Bytes, _:Bytes))
    => FD:Bytes
  rule jerPayloadDOf(jExecReceipt(_:Bytes, _:Bytes, _:Int, _:Map, _:Map,
                                  _:Map, _:List, _:Bytes, _:Bytes, _:Bytes,
                                  _:Bytes, PL:Bytes, _:Bytes, _:Bytes,
                                  _:Bytes, _:Bytes, _:Bytes, _:Int,
                                  _:Bytes, _:Bytes))
    => PL:Bytes
  rule jerExecSrcOf(jExecReceipt(_:Bytes, _:Bytes, _:Int, _:Map, _:Map,
                                 _:Map, _:List, _:Bytes, _:Bytes, _:Bytes,
                                 _:Bytes, _:Bytes, SR:Bytes, _:Bytes,
                                 _:Bytes, _:Bytes, _:Bytes, _:Int, _:Bytes,
                                 _:Bytes))
    => SR:Bytes
  rule jerCfgRootOf(jExecReceipt(_:Bytes, _:Bytes, _:Int, _:Map, _:Map,
                                 _:Map, _:List, _:Bytes, _:Bytes, _:Bytes,
                                 _:Bytes, _:Bytes, _:Bytes, CR:Bytes,
                                 _:Bytes, _:Bytes, _:Bytes, _:Int, _:Bytes,
                                 _:Bytes))
    => CR:Bytes
  rule jerCatRootOf(jExecReceipt(_:Bytes, _:Bytes, _:Int, _:Map, _:Map,
                                 _:Map, _:List, _:Bytes, _:Bytes, _:Bytes,
                                 _:Bytes, _:Bytes, _:Bytes, _:Bytes,
                                 CA:Bytes, _:Bytes, _:Bytes, _:Int, _:Bytes,
                                 _:Bytes))
    => CA:Bytes
  rule jerAnchorOf(jExecReceipt(_:Bytes, _:Bytes, _:Int, _:Map, _:Map, _:Map,
                                _:List, _:Bytes, _:Bytes, _:Bytes, _:Bytes,
                                _:Bytes, _:Bytes, _:Bytes, _:Bytes,
                                AN:Bytes, _:Bytes, _:Int, _:Bytes, _:Bytes))
    => AN:Bytes
  rule jerHeadOf(jExecReceipt(_:Bytes, _:Bytes, _:Int, _:Map, _:Map, _:Map,
                              _:List, _:Bytes, _:Bytes, _:Bytes, _:Bytes,
                              _:Bytes, _:Bytes, _:Bytes, _:Bytes, _:Bytes,
                              H:Bytes, _:Int, _:Bytes, _:Bytes))
    => H:Bytes
  rule jerSlotOf(jExecReceipt(_:Bytes, _:Bytes, _:Int, _:Map, _:Map, _:Map,
                              _:List, _:Bytes, _:Bytes, _:Bytes, _:Bytes,
                              _:Bytes, _:Bytes, _:Bytes, _:Bytes, _:Bytes,
                              _:Bytes, S:Int, _:Bytes, _:Bytes))
    => S:Int
  rule jerLinHeadOf(jExecReceipt(_:Bytes, _:Bytes, _:Int, _:Map, _:Map,
                                 _:Map, _:List, _:Bytes, _:Bytes, _:Bytes,
                                 _:Bytes, _:Bytes, _:Bytes, _:Bytes, _:Bytes,
                                 _:Bytes, _:Bytes, _:Int, LH:Bytes, _:Bytes))
    => LH:Bytes
  rule jerEvidenceIdOf(jExecReceipt(_:Bytes, _:Bytes, _:Int, _:Map, _:Map,
                                    _:Map, _:List, _:Bytes, _:Bytes,
                                    _:Bytes, _:Bytes, _:Bytes, _:Bytes,
                                    _:Bytes, _:Bytes, _:Bytes, _:Bytes,
                                    _:Int, _:Bytes, EV:Bytes))
    => EV:Bytes

  // --------------------------------------------------------------------------
  // §H.2 THE GATE RECEIPT — the ONLY carrier of a frozen-gate verdict.
  //      Minted ONLY by pGateEvalJ; embeds the execution receipt it was
  //      derived from (the J correspondence discipline); binds the computed
  //      root/anchor/catalog-root and the position.  NO verdict argument
  //      exists on any command.
  // --------------------------------------------------------------------------
  syntax JGateReceipt ::= "jGateReceipt" "(" jgBlock:JBlockJ ","
                            jgErc:Bytes "," jgErp:Bytes ","
                            jgFC:ExecCtx "," jgRG:LinRecG ","
                            jgCERT:AuthzCert "," jgAC:AzCtx ","
                            jgExec:JExecReceipt ","
                            jgVerdict:String "," jgHead:Bytes ","
                            jgSlot:Int "," jgLinHead:Bytes ","
                            jgCfg:ProtoCfgR3 "," jgRoot:Bytes ","
                            jgAnchor:Bytes "," jgCatRoot:Bytes ")"

  syntax JBlockJ      ::= jgBlockOf    ( JGateReceipt ) [function, total]
  syntax Bytes        ::= jgErcOf      ( JGateReceipt ) [function, total]
  syntax Bytes        ::= jgErpOf      ( JGateReceipt ) [function, total]
  syntax ExecCtx      ::= jgFCOf       ( JGateReceipt ) [function, total]
  syntax LinRecG      ::= jgRGOf       ( JGateReceipt ) [function, total]
  syntax AuthzCert    ::= jgCERTOf     ( JGateReceipt ) [function, total]
  syntax AzCtx        ::= jgACOf       ( JGateReceipt ) [function, total]
  syntax JExecReceipt ::= jgExecOf     ( JGateReceipt ) [function, total]
  syntax String       ::= jgVerdictOf  ( JGateReceipt ) [function, total]
  syntax Bytes        ::= jgHeadOf     ( JGateReceipt ) [function, total]
  syntax Int          ::= jgSlotOf     ( JGateReceipt ) [function, total]
  syntax Bytes        ::= jgLinHeadOf  ( JGateReceipt ) [function, total]
  syntax ProtoCfgR3   ::= jgCfgOf      ( JGateReceipt ) [function, total]
  syntax Bytes        ::= jgRootOf     ( JGateReceipt ) [function, total]
  syntax Bytes        ::= jgAnchorOf   ( JGateReceipt ) [function, total]
  syntax Bytes        ::= jgCatRootOf  ( JGateReceipt ) [function, total]

  rule jgBlockOf(jGateReceipt(B:JBlockJ, _:Bytes, _:Bytes, _:ExecCtx,
                              _:LinRecG, _:AuthzCert, _:AzCtx,
                              _:JExecReceipt, _:String, _:Bytes, _:Int,
                              _:Bytes, _:ProtoCfgR3, _:Bytes, _:Bytes,
                              _:Bytes))
    => B:JBlockJ
  rule jgErcOf(jGateReceipt(_:JBlockJ, E:Bytes, _:Bytes, _:ExecCtx,
                            _:LinRecG, _:AuthzCert, _:AzCtx,
                            _:JExecReceipt, _:String, _:Bytes, _:Int,
                            _:Bytes, _:ProtoCfgR3, _:Bytes, _:Bytes,
                            _:Bytes))
    => E:Bytes
  rule jgErpOf(jGateReceipt(_:JBlockJ, _:Bytes, P:Bytes, _:ExecCtx,
                            _:LinRecG, _:AuthzCert, _:AzCtx,
                            _:JExecReceipt, _:String, _:Bytes, _:Int,
                            _:Bytes, _:ProtoCfgR3, _:Bytes, _:Bytes,
                            _:Bytes))
    => P:Bytes
  rule jgFCOf(jGateReceipt(_:JBlockJ, _:Bytes, _:Bytes, FC:ExecCtx,
                           _:LinRecG, _:AuthzCert, _:AzCtx,
                           _:JExecReceipt, _:String, _:Bytes, _:Int,
                           _:Bytes, _:ProtoCfgR3, _:Bytes, _:Bytes,
                           _:Bytes))
    => FC:ExecCtx
  rule jgRGOf(jGateReceipt(_:JBlockJ, _:Bytes, _:Bytes, _:ExecCtx,
                           RG:LinRecG, _:AuthzCert, _:AzCtx,
                           _:JExecReceipt, _:String, _:Bytes, _:Int,
                           _:Bytes, _:ProtoCfgR3, _:Bytes, _:Bytes,
                           _:Bytes))
    => RG:LinRecG
  rule jgCERTOf(jGateReceipt(_:JBlockJ, _:Bytes, _:Bytes, _:ExecCtx,
                             _:LinRecG, CT:AuthzCert, _:AzCtx,
                             _:JExecReceipt, _:String, _:Bytes, _:Int,
                             _:Bytes, _:ProtoCfgR3, _:Bytes, _:Bytes,
                             _:Bytes))
    => CT:AuthzCert
  rule jgACOf(jGateReceipt(_:JBlockJ, _:Bytes, _:Bytes, _:ExecCtx,
                           _:LinRecG, _:AuthzCert, AC:AzCtx,
                           _:JExecReceipt, _:String, _:Bytes, _:Int,
                           _:Bytes, _:ProtoCfgR3, _:Bytes, _:Bytes,
                           _:Bytes))
    => AC:AzCtx
  rule jgExecOf(jGateReceipt(_:JBlockJ, _:Bytes, _:Bytes, _:ExecCtx,
                             _:LinRecG, _:AuthzCert, _:AzCtx,
                             E:JExecReceipt, _:String, _:Bytes, _:Int,
                             _:Bytes, _:ProtoCfgR3, _:Bytes, _:Bytes,
                             _:Bytes))
    => E:JExecReceipt
  rule jgVerdictOf(jGateReceipt(_:JBlockJ, _:Bytes, _:Bytes, _:ExecCtx,
                                _:LinRecG, _:AuthzCert, _:AzCtx,
                                _:JExecReceipt, V:String, _:Bytes, _:Int,
                                _:Bytes, _:ProtoCfgR3, _:Bytes, _:Bytes,
                                _:Bytes))
    => V:String
  rule jgHeadOf(jGateReceipt(_:JBlockJ, _:Bytes, _:Bytes, _:ExecCtx,
                             _:LinRecG, _:AuthzCert, _:AzCtx,
                             _:JExecReceipt, _:String, H:Bytes, _:Int,
                             _:Bytes, _:ProtoCfgR3, _:Bytes, _:Bytes,
                             _:Bytes))
    => H:Bytes
  rule jgSlotOf(jGateReceipt(_:JBlockJ, _:Bytes, _:Bytes, _:ExecCtx,
                             _:LinRecG, _:AuthzCert, _:AzCtx,
                             _:JExecReceipt, _:String, _:Bytes, S:Int,
                             _:Bytes, _:ProtoCfgR3, _:Bytes, _:Bytes,
                             _:Bytes))
    => S:Int
  rule jgLinHeadOf(jGateReceipt(_:JBlockJ, _:Bytes, _:Bytes, _:ExecCtx,
                                _:LinRecG, _:AuthzCert, _:AzCtx,
                                _:JExecReceipt, _:String, _:Bytes, _:Int,
                                LH:Bytes, _:ProtoCfgR3, _:Bytes, _:Bytes,
                                _:Bytes))
    => LH:Bytes
  rule jgCfgOf(jGateReceipt(_:JBlockJ, _:Bytes, _:Bytes, _:ExecCtx,
                            _:LinRecG, _:AuthzCert, _:AzCtx,
                            _:JExecReceipt, _:String, _:Bytes, _:Int,
                            _:Bytes, C:ProtoCfgR3, _:Bytes, _:Bytes,
                            _:Bytes))
    => C:ProtoCfgR3
  rule jgRootOf(jGateReceipt(_:JBlockJ, _:Bytes, _:Bytes, _:ExecCtx,
                             _:LinRecG, _:AuthzCert, _:AzCtx,
                             _:JExecReceipt, _:String, _:Bytes, _:Int,
                             _:Bytes, _:ProtoCfgR3, RT:Bytes, _:Bytes,
                             _:Bytes))
    => RT:Bytes
  rule jgAnchorOf(jGateReceipt(_:JBlockJ, _:Bytes, _:Bytes, _:ExecCtx,
                               _:LinRecG, _:AuthzCert, _:AzCtx,
                               _:JExecReceipt, _:String, _:Bytes, _:Int,
                               _:Bytes, _:ProtoCfgR3, _:Bytes, AN:Bytes,
                               _:Bytes))
    => AN:Bytes
  rule jgCatRootOf(jGateReceipt(_:JBlockJ, _:Bytes, _:Bytes, _:ExecCtx,
                                _:LinRecG, _:AuthzCert, _:AzCtx,
                                _:JExecReceipt, _:String, _:Bytes, _:Int,
                                _:Bytes, _:ProtoCfgR3, _:Bytes, _:Bytes,
                                CA:Bytes))
    => CA:Bytes

  // THE DERIVED DECISION — computed from the receipt's INTERNALLY COMPUTED
  // verdict by the frozen fail-closed mapping (only "valid-g" is valid).
  syntax Int ::= jgDecisionOf ( JGateReceipt ) [function, total]
  rule jgDecisionOf(R:JGateReceipt)
    => ProtoDecisionOfGateJ(jgVerdictOf(R))

  // --------------------------------------------------------------------------
  // §H.3 THE J GATE-INPUT BINDING (the R3 predicates, J form + the derived-
  //      execution correspondence conjuncts).  Every caller-presented
  //      evidence object is bound to the EXACT candidate; the DERIVED
  //      execution receipt must agree with the presented record and the
  //      candidate (the J-EVIDENCE-STATE-CORRESPONDENCE enforcement).
  // --------------------------------------------------------------------------
  syntax Bool ::= GateInputMatchesBlockJ ( ExecCtx , LinRecG , AuthzCert ,
                                           JBlockJ ) [function, total]
  rule GateInputMatchesBlockJ(FC:ExecCtx, RG:LinRecG, CERT:AuthzCert,
                              B:JBlockJ)
    => BytesEq( azPayloadDOf(CERT), jbPayloadDOf(B) )              // payload identity
       andBool BytesEq( execCtxParentRoot(FC), jbParentRootOf(B) ) // parent state root
       andBool BytesEq( linEffTraceDOf(linRecGBase(RG)),
                        jbTraceDOf(B) )                             // trace digest
       andBool BytesEq( linAzCertDOf(RG), jbEvidenceIdOf(B) )       // evidence identity

  // the DERIVED-execution correspondence: the machine-derived values must
  // equal the candidate's declared identity fields (the caller cannot mint
  // a trace/root/footprint the semantics did not produce — the receipt's
  // fields were WRITTEN by pExecJ from the interpreter result).
  // NOTE on the pre-state identity: the receipt's jerPreRoot is the J-LEVEL
  // state root (StateRootJ, tag 0xB4) of the machine <jstate> at mint time;
  // the block's jbParentRoot is the FROZEN 1F exec-context parent identity
  // (the record-chain root the certificate binds).  They are two encodings
  // of the same pre-state; the receipt is tied to the exact pre-state by
  // its POSITION freshness (head/slot/lineage-head — machine state), and
  // cross-parent replay is excluded at the mint by the
  // execCtxParentRoot(FC) == jbParentRootOf(B) binding conjunct.
  syntax Bool ::= ExecReceiptMatchesBlockJ ( JExecReceipt , JBlockJ )
                  [function, total]
  rule ExecReceiptMatchesBlockJ(E:JExecReceipt, B:JBlockJ)
    => BytesEq( jerPayloadDOf(E), jbPayloadDOf(B) )
       andBool BytesEq( jerPostRootOf(E), jbPostRootOf(B) )
       andBool BytesEq( jerTraceDOf(E), jbTraceDOf(B) )
       andBool BytesEq( jerFootDOf(E), jbFootDOf(B) )
       andBool BytesEq( jerExecSrcOf(E), jbExecSrcOf(B) )
       andBool BytesEq( jerCfgRootOf(E), jbConfigRootOf(B) )
       andBool BytesEq( jerCatRootOf(E), jbCatalogRootOf(B) )

  // the presented record's trace must BE the derived trace (byte-level
  // digest equality against the machine-derived digest chain)
  syntax Bool ::= ExecReceiptMatchesRecordJ ( JExecReceipt , LinRecG )
                  [function, total]
  rule ExecReceiptMatchesRecordJ(E:JExecReceipt, RG:LinRecG)
    => BytesEq( jerTraceDOf(E), linEffTraceDOf(linRecGBase(RG)) )

  // pinned authority (schedule/spec arrive only through the pinned config)
  syntax Bool ::= GateAuthorityMatchesCfgJ ( ExecCtx , ProtoCfgR3 )
                  [function, total]
  rule GateAuthorityMatchesCfgJ(FC:ExecCtx, C:ProtoCfgR3)
    => BytesEq( execCtxSched(FC), qcrSchedOf(C) )
       andBool execCtxSpec(FC) ==Int qcrSpecOf(C)

  syntax Bool ::= AzSecEqJ ( SecCtx , SecCtx ) [function, total]
  rule AzSecEqJ(S1:SecCtx, S2:SecCtx)
    => secPolicyVOf(S1) ==Int secPolicyVOf(S2)
       andBool BytesEq(secChainIdOf(S1), secChainIdOf(S2))
       andBool BytesEq(secAppSetDOf(S1), secAppSetDOf(S2))
       andBool BytesEq(secGraphDOf(S1), secGraphDOf(S2))
       andBool BytesEq(secLineageHeadOf(S1), secLineageHeadOf(S2))

  syntax Bool ::= GateCtxAuthorizedJ ( AzCtx , ProtoCfgR3 , Bytes )
                  [function, total]
  rule GateCtxAuthorizedJ(AC:AzCtx, C:ProtoCfgR3, LH:Bytes)
    => AzSecEqJ( azSecOf(AC), ProtoAuthorizedSecCtxR3(C, LH) )
       andBool azAuthPTOf(AC) ==Int qcrAuthPTOf(C)
       andBool BytesEq( azAuthGuestDOf(AC), qcrAuthGuestDOf(C) )
       andBool BytesEq( azAuthCfgDOf(AC), qcrAuthCfgDOf(C) )

  // the F-child commitment of a record (the frozen lineage-head advance)
  syntax Bytes ::= JRecChildF ( LinRecG ) [function]
  rule JRecChildF(RG:LinRecG)
    => ExecChildF( linRecFBase(linRecGBase(RG))
                 , linExecIdOf(linRecGBase(RG))
                 , linEffTraceDOf(linRecGBase(RG))
                 , linExecWDOf(linRecGBase(RG))
                 , linExecCfgDOf(linRecGBase(RG)) )

  // ===========================================================================
  // §I. THE ISOLATED J MACHINE SURFACE — configuration and commands.
  //
  //     The command language is PProgJI = lists of PCmdJI.  The legacy
  //     commands (1I pInit/pAccept; R1 pInitR1/pGateEval/pAcceptR1; R2
  //     pInitR2/pGateEvalR2/pAcceptR2; R3 pInitR3/pGateEvalR3/pAcceptR3) are
  //     NOT in this language: their modules are not imported, their symbols
  //     are not declared here, and no rule matches them (kparse rejects —
  //     J-LEGACY-SURFACE-EXCLUDED).
  //
  //     THE ANCHOR IS NOT A COMMAND INPUT: <janchor> is filled by the
  //     AUTHENTICATED EXTERNAL INPUT $SRW3JANCHOR at machine instantiation
  //     and written by NO rule (immutable by construction).  NO command
  //     takes an anchor, a root, a verdict, a trace, a post-state, a
  //     coverage Boolean, or a policy-check Boolean — every one of those
  //     values is COMPUTED by the machine (handoff §4.2 forbidden patterns;
  //     J-NO-CALLER-EVIDENCE-VERDICT).
  // ===========================================================================

  // execution-refusal diagnostics (machine bookkeeping; written ONLY by the
  // exec rules; never a verdict input; a refused run leaves no receipt)
  syntax JRefuse ::= "jrefuseNoneJ"
                   | "jrefusedUnsupported" "(" Int ")"
                   | "jrefusedBounds" "(" Int ")"
                   | "jrefusedSource" "(" ")"

  // exec-result class predicates + selectors (the dispatch discipline)
  syntax Bool ::= isExecOkJ ( JExecResult ) [function, total]
  rule isExecOkJ(jExecOk(_:Map, _:Map, _:List)) => true
  rule isExecOkJ(_:JExecResult) => false [owise]

  syntax Bool ::= isExecUnsupportedJ ( JExecResult ) [function, total]
  rule isExecUnsupportedJ(jExecUnsupported(_:Int)) => true
  rule isExecUnsupportedJ(_:JExecResult) => false [owise]

  syntax Bool ::= isExecBoundsJ ( JExecResult ) [function, total]
  rule isExecBoundsJ(jExecBounds(_:Int)) => true
  rule isExecBoundsJ(_:JExecResult) => false [owise]

  syntax Map ::= jExecOkPostOf ( JExecResult ) [function, total]
  rule jExecOkPostOf(jExecOk(P:Map, _:Map, _:List)) => P:Map
  rule jExecOkPostOf(_:JExecResult) => .Map [owise]

  syntax Map ::= jExecOkEffOf ( JExecResult ) [function, total]
  rule jExecOkEffOf(jExecOk(_:Map, E:Map, _:List)) => E:Map
  rule jExecOkEffOf(_:JExecResult) => .Map [owise]

  syntax List ::= jExecOkTraceOf ( JExecResult ) [function, total]
  rule jExecOkTraceOf(jExecOk(_:Map, _:Map, T:List)) => T:List
  rule jExecOkTraceOf(_:JExecResult) => .List [owise]

  syntax Int ::= jExecUnsupportedOpOf ( JExecResult ) [function, total]
  rule jExecUnsupportedOpOf(jExecUnsupported(N:Int)) => N:Int
  rule jExecUnsupportedOpOf(_:JExecResult) => -1 [owise]

  syntax Int ::= jExecBoundsOpOf ( JExecResult ) [function, total]
  rule jExecBoundsOpOf(jExecBounds(N:Int)) => N:Int
  rule jExecBoundsOpOf(_:JExecResult) => -1 [owise]

  // the closure fuel bound (explicit, documented; the fixture closures need
  // two rounds; exhaustion beyond the bound REJECTS — handoff §5.2)
  syntax Int ::= "JClosureFuelJ" [function, total]
  rule JClosureFuelJ => 8

  // reserved metadata region accessors (keys -1/-2/-3/-4; negative keys can
  // never collide with block slots >= 0)
  syntax ProtoCfgR3OrNone ::= ProtoCfgR3 | "noCfgR3"
  syntax ProtoCfgR3OrNone ::= storedCfgJOf ( Map ) [function, total]
  rule storedCfgJOf(-1 |-> C:ProtoCfgR3 REST:Map) => C:ProtoCfgR3
  rule storedCfgJOf(REST:Map) => noCfgR3 [owise]

  syntax JCatalogOrNone ::= JCatalog | "noCatalogJ"
  syntax JCatalogOrNone ::= storedCatJOf ( Map ) [function, total]
  rule storedCatJOf(-3 |-> P:JCatalog REST:Map) => P:JCatalog
  rule storedCatJOf(REST:Map) => noCatalogJ [owise]

  syntax Set ::= gateReceiptsJOf ( Map ) [function, total]
  rule gateReceiptsJOf(-2 |-> S:Set REST:Map) => S:Set
  rule gateReceiptsJOf(REST:Map) => .Set [owise]

  syntax Set ::= execReceiptsJOf ( Map ) [function, total]
  rule execReceiptsJOf(-4 |-> S:Set REST:Map) => S:Set
  rule execReceiptsJOf(REST:Map) => .Set [owise]

  syntax Bool ::= cfgPinnedJ ( Map ) [function, total]
  rule cfgPinnedJ(-1 |-> _:ProtoCfgR3 REST:Map) => true
  rule cfgPinnedJ(REST:Map) => false [owise]

  syntax Bool ::= catPinnedJ ( Map ) [function, total]
  rule catPinnedJ(-3 |-> _:JCatalog REST:Map) => true
  rule catPinnedJ(REST:Map) => false [owise]

  // the command language
  //   pInitJ:    configuration + FULL catalog contents (authenticated by
  //              the digest checks against the R3-rooted config fields).
  //              NO root/anchor argument (the anchor is protocol input).
  //   pExecJ:    DECLARED execution source + fragment program + caller/value.
  //              NO trace, NO post-state, NO coverage/authenticity Boolean.
  //   pGateEvalJ: candidate + client execution context + lineage record +
  //              authority certificate + client-derived child root + client-
  //              derived payload identity.  NO verdict/decision argument.
  //   pCommitJ:  candidate + execution results + the DECLARED config-version
  //              witness.  NO verdict, NO config, NO root, NO receipt, NO
  //              policy Boolean (the receipt and the derived values are
  //              machine state; SafeJ is computed on the derived post-state).
  syntax PCmdJI ::= "pInitJ" "(" ProtoCfgR3 "," JCatalog ")"
                 | "pExecJ" "(" Bytes "," List "," Bytes "," Int ")"
                 | "pGateEvalJ" "(" JBlockJ "," ExecCtx "," LinRecG ","
                                  AuthzCert "," Bytes "," Bytes ")"
                 | "pCommitJ" "(" JBlockJ "," Bytes "," Bytes "," Int ")"
  syntax PProgJI ::= "runNilJ" | pConsJ(PCmdJI, PProgJI)

  configuration <srw3closureJ>
                  <k> $PGM:PProgJI </k>
                  <jlineage> .Map </jlineage>
                  // slot -> JBlockJ; -1 -> pinned ProtoCfgR3;
                  // -2 -> gate-receipt pool (Set); -3 -> pinned JCatalog;
                  // -4 -> exec-receipt pool (Set)
                  <jnext> 0 </jnext>
                  <jhead> JGenesisHead </jhead>
                  <jlinhead> JLinRoot </jlinhead>
                  // THE PROTOCOL-AUTHORIZED CONFIGURATION-ROOT ANCHOR —
                  // explicit authenticated external input; immutable: NO
                  // rule writes this cell.
                  <janchor> $SRW3JANCHOR:Bytes </janchor>
                  // the abstract execution state (the safety state Safe_P
                  // is evaluated on; the root hashes thread pre/post)
                  <jstate> .Map </jstate>
                  // last execution refusal (diagnostics; never an input)
                  <jrefuse> jrefuseNoneJ </jrefuse>
                  <jvalid> true </jvalid>
                </srw3closureJ>

  rule <k> pConsJ(C:PCmdJI, RUN:PProgJI) => C ~> RUN ... </k>
  rule <k> runNilJ => .K ... </k>

  // genesis anchors (the frozen 1I/1D discipline: the protocol head starts
  // at 0x00 and is OVERWRITTEN at initialization to ProtoRootR3(C) — equal
  // to the authorized anchor by the init check; the lineage root is 32 zero
  // bytes)
  syntax Bytes ::= "JGenesisHead" [function, total]
  rule JGenesisHead => Int2Bytes(1, 0, BE)
  syntax Bytes ::= "JLinRoot" [function, total]
  rule JLinRoot => Int2Bytes(32, 0, BE)

  // ---------------------------------------------------------------------------
  // pInitJ — pins the configuration AND the catalog ONCE, ONLY under the
  // authorized R3 root, with the catalog digest-bound to the config fields
  // and the genesis state SAFE (the J-INITIAL-SAFE base is an init guard —
  // an unsafe genesis is refused, fail-closed).  Refuses: re-init, root
  // mismatch, malformed catalog, digest mismatch, policy-version mismatch,
  // unsafe genesis.  There is deliberately NO upgrade/root-update/catalog-
  // update transition (documented deferral, the R1/R2/R3 discipline).
  // ---------------------------------------------------------------------------
  rule <k> pInitJ(C:ProtoCfgR3, P:JCatalog) => .K ... </k>
       <jhead> _:Bytes => ProtoRootR3(C) </jhead>
       <jlinhead> _:Bytes => JLinRoot </jlinhead>
       <jlineage> L:Map => L[-1 <- C][-3 <- P] </jlineage>
       <janchor> A:Bytes </janchor>
       <jstate> .Map </jstate>
    requires notBool cfgPinnedJ(L:Map)
         andBool notBool catPinnedJ(L:Map)
         andBool BytesEq(ProtoRootR3(C), A:Bytes)
         andBool JCatalogWF(P)
         andBool BytesEq(JAppSetRootJ(P), qcrAppSetDOf(C))
         andBool BytesEq(JGraphRootJ(P), qcrGraphDOf(C))
         andBool BytesEq(JPolicyRootJ(P), qcrPolicyDOf(C))
         andBool jcPolicyVOf(P) ==Int qcrPolicyVOf(C)
         andBool SafeJ(P, .Map)

  // refused initialization ([owise]): ANY failure — re-init, root mismatch
  // (including ANY config mutation re-presented under the old authorized
  // root), malformed/duplicate/unknown-owner catalog, catalog contents that
  // do not hash to the configured digests (the missing-hyperedge class —
  // J-REJECTS-MISSING-HYPEREDGE at the pin), policy-version mismatch, or an
  // unsafe genesis — consumes the command and changes NOTHING (fail-closed).
  rule <k> pInitJ(_:ProtoCfgR3, _:JCatalog) => .K ... </k>
       <jlineage> L:Map </jlineage>
       <jnext> N:Int </jnext>
       <jhead> H:Bytes </jhead>
       <jlinhead> LH:Bytes </jlinhead>
       <janchor> A:Bytes </janchor>
       <jstate> S:Map </jstate>
       <jrefuse> RF:JRefuse </jrefuse>
       <jvalid> V:Bool </jvalid>
    [owise]

  // ---------------------------------------------------------------------------
  // pExecJ — the ONLY rule that mints an execution receipt; the receipt's
  // trace/effective-delta/post-state/root/footprint/payload/evidence fields
  // are WRITTEN from the fragment interpreter's result (machine-derived).
  // The declared source must be the pinned execution-client identity
  // (J-A08).  Refused executions (unsupported/bounds) write <jrefuse> and
  // mint NOTHING; the state does not move.  Chain state never moves here.
  // ---------------------------------------------------------------------------
  // the exec-dispatch continuation (machine-internal; not caller syntax)
  syntax KItem ::= "jExecDispatch" "(" Bytes "," List "," Bytes "," Int ")"

  rule <k> pExecJ(SRC:Bytes, PG:List, CL:Bytes, VL:Int)
        => jExecDispatch(SRC, PG, CL, VL) ... </k>
       <jlineage> L:Map </jlineage>
    requires cfgPinnedJ(L:Map) andBool catPinnedJ(L:Map)

  // the dispatch: OK => mint into the exec-receipt pool
  rule <k> jExecDispatch(SRC:Bytes, PG:List, CL:Bytes, VL:Int) => .K ... </k>
       <jstate> S:Map </jstate>
       <jlineage> ( -1:Int |-> C:ProtoCfgR3 )
                  ( -3:Int |-> PCAT:JCatalog )
                  ( -4:Int |-> ES:Set )
                  L4:Map
               => ( -1:Int |-> C:ProtoCfgR3 )
                  ( -3:Int |-> PCAT:JCatalog )
                  ( -4:Int |-> SetItem(JExecReceiptOf(
                        SRC, PG, CL, VL, S, C, PCAT, A, H, N, LH,
                        jExecOkPostOf(ExecFragmentJ(S, PG)),
                        jExecOkEffOf(ExecFragmentJ(S, PG)),
                        jExecOkTraceOf(ExecFragmentJ(S, PG)))) ES )
                  L4:Map </jlineage>
       <jnext> N:Int </jnext>
       <jhead> H:Bytes </jhead>
       <jlinhead> LH:Bytes </jlinhead>
       <janchor> A:Bytes </janchor>
    requires isExecOkJ(ExecFragmentJ(S:Map, PG:List))
         andBool BytesEq(SRC:Bytes, qcrExecClientDOf(C:ProtoCfgR3))

  // the dispatch: the exec-receipt pool does not exist yet (first exec)
  rule <k> jExecDispatch(SRC:Bytes, PG:List, CL:Bytes, VL:Int) => .K ... </k>
       <jstate> S:Map </jstate>
       <jlineage> ( -1:Int |-> C:ProtoCfgR3 )
                  ( -3:Int |-> PCAT:JCatalog )
                  L2:Map
               => ( -1:Int |-> C:ProtoCfgR3 )
                  ( -3:Int |-> PCAT:JCatalog )
                  ( -4:Int |-> SetItem(JExecReceiptOf(
                        SRC, PG, CL, VL, S, C, PCAT, A, H, N, LH,
                        jExecOkPostOf(ExecFragmentJ(S, PG)),
                        jExecOkEffOf(ExecFragmentJ(S, PG)),
                        jExecOkTraceOf(ExecFragmentJ(S, PG)))) .Set )
                  L2:Map </jlineage>
       <jnext> N:Int </jnext>
       <jhead> H:Bytes </jhead>
       <jlinhead> LH:Bytes </jlinhead>
       <janchor> A:Bytes </janchor>
    requires notBool ( -4:Int in_keys(L2:Map) )
         andBool isExecOkJ(ExecFragmentJ(S:Map, PG:List))
         andBool BytesEq(SRC:Bytes, qcrExecClientDOf(C:ProtoCfgR3))

  // the receipt builder — every field is DERIVED (machine-computed); the
  // position/anchor fields are the machine cells at mint time
  syntax JExecReceipt ::= JExecReceiptOf ( Bytes   /* declared source */
                                         , List    /* program */
                                         , Bytes   /* caller */
                                         , Int     /* value */
                                         , Map     /* pre-state */
                                         , ProtoCfgR3
                                         , JCatalog
                                         , Bytes   /* anchor */
                                         , Bytes   /* head */
                                         , Int     /* slot */
                                         , Bytes   /* lineage head */
                                         , Map     /* derived post */
                                         , Map     /* derived eff */
                                         , List )  /* derived trace */
                          [function]

  rule JExecReceiptOf(SRC:Bytes, PG:List, CL:Bytes, VL:Int, S:Map,
                      C:ProtoCfgR3, PCAT:JCatalog, A:Bytes, H:Bytes, N:Int,
                      LH:Bytes, P:Map, E:Map, T:List)
    => jExecReceipt( JProgBytesJ(PG), CL, VL, S, E, P, T
                   , StateRootJ(S), StateRootJ(P)
                   , JTraceDigestJ(T), JFootprintDigestJ(T)
                   , JPayloadDigestJ(PG), SRC
                   , ProtoRootR3(C), JCatalogRootJ(PCAT)
                   , A, H, N, LH
                   , EvidenceIDJ( ProtoRootR3(C), JCatalogRootJ(PCAT)
                                , qcrChainIdOf(C), qcrForkOf(C)
                                , StateRootJ(S), JPayloadDigestJ(PG)
                                , SRC, StateRootJ(P), JTraceDigestJ(T)
                                , JFootprintDigestJ(T)
                                , JPolicyCtxDigestJ( ProtoRootR3(C)
                                                   , JCatalogRootJ(PCAT)
                                                   , qcrPolicyVOf(C) ) ) )

  // the dispatch: refused executions write the diagnostics and mint NOTHING
  // (unsupported-effect class — handoff §4.1)
  rule <k> jExecDispatch(_:Bytes, PG:List, _:Bytes, _:Int) => .K ... </k>
       <jstate> S:Map </jstate>
       <jrefuse> _:JRefuse
              => jrefusedUnsupported(jExecUnsupportedOpOf(ExecFragmentJ(S, PG)))
           </jrefuse>
    requires isExecUnsupportedJ(ExecFragmentJ(S:Map, PG:List))

  // the dispatch: field-bounds refusal class
  rule <k> jExecDispatch(_:Bytes, PG:List, _:Bytes, _:Int) => .K ... </k>
       <jstate> S:Map </jstate>
       <jrefuse> _:JRefuse
              => jrefusedBounds(jExecBoundsOpOf(ExecFragmentJ(S, PG))) </jrefuse>
    requires isExecBoundsJ(ExecFragmentJ(S:Map, PG:List))

  // the dispatch: unauthorized execution source (J-A08) — the declared
  // source is not the pinned execution-client identity
  rule <k> jExecDispatch(SRC:Bytes, PG:List, _:Bytes, _:Int) => .K ... </k>
       <jstate> S:Map </jstate>
       <jlineage> -1:Int |-> C:ProtoCfgR3 </jlineage>
       <jrefuse> _:JRefuse => jrefusedSource() </jrefuse>
    requires isExecOkJ(ExecFragmentJ(S:Map, PG:List))
         andBool notBool BytesEq(SRC:Bytes, qcrExecClientDOf(C:ProtoCfgR3))

  // ---------------------------------------------------------------------------
  // pGateEvalJ — the ONLY rule that creates a gate receipt.  The machine:
  //   (a) constructs the authority context AC_m FROM THE PINNED CONFIGURATION
  //       (the R3 discipline — the caller cannot name authority values);
  //   (b) supplies the position (slot counter + lineage anchor);
  //   (c) COMPUTES the verdict: VerifyLineageG(RG, AC_m, N, LH) — the frozen
  //       21-conjunct gate is the only producer of "valid-g";
  //   (d) REQUIRES the DERIVED-execution correspondence: an execution
  //       receipt minted by pExecJ for THIS candidate, position, and
  //       lineage head must exist and must agree with the presented record
  //       and candidate (J-EVIDENCE-STATE-CORRESPONDENCE at the mint);
  //   (e) binds the computed config root, the anchor, and the catalog root.
  //   Mutates NO chain state and consumes NO receipt (evaluation only).
  // ---------------------------------------------------------------------------
  rule <k> pGateEvalJ(B:JBlockJ, FC:ExecCtx, RG:LinRecG, CERT:AuthzCert,
                      ERC:Bytes, ERP:Bytes) => .K ... </k>
       <jnext> N:Int </jnext>
       <jhead> H:Bytes </jhead>
       <jlinhead> LH:Bytes </jlinhead>
       <janchor> A:Bytes </janchor>
       <jlineage> ( -1:Int |-> C:ProtoCfgR3 )
                  ( -3:Int |-> PCAT:JCatalog )
                  ( -2:Int |-> PS:Set )
                  ( -4:Int |-> SetItem(E:JExecReceipt) ES:Set )
                  L2:Map
               => ( -1:Int |-> C:ProtoCfgR3 )
                  ( -3:Int |-> PCAT:JCatalog )
                  ( -2:Int |-> SetItem(
                        jGateReceipt( B:JBlockJ, ERC:Bytes, ERP:Bytes
                                    , FC:ExecCtx, RG:LinRecG
                                    , CERT:AuthzCert
                                    , azCtx( FC:ExecCtx
                                           , ProtoAuthorizedSecCtxR3(
                                                 C:ProtoCfgR3
                                               , jbParentRootOf(B:JBlockJ) )
                                           , CERT:AuthzCert
                                           , qcrAuthPTOf(C:ProtoCfgR3)
                                           , qcrAuthGuestDOf(C:ProtoCfgR3)
                                           , qcrAuthCfgDOf(C:ProtoCfgR3) )
                                    , E:JExecReceipt
                                    , VerifyLineageG(
                                          RG:LinRecG
                                        , azCtx( FC:ExecCtx
                                               , ProtoAuthorizedSecCtxR3(
                                                     C:ProtoCfgR3
                                                   , jbParentRootOf(B:JBlockJ) )
                                               , CERT:AuthzCert
                                               , qcrAuthPTOf(C:ProtoCfgR3)
                                               , qcrAuthGuestDOf(C:ProtoCfgR3)
                                               , qcrAuthCfgDOf(C:ProtoCfgR3) )
                                        , N:Int, LH:Bytes )
                                    , H:Bytes, N:Int, LH:Bytes
                                    , C:ProtoCfgR3
                                    , ProtoRootR3(C:ProtoCfgR3)
                                    , A:Bytes
                                    , JCatalogRootJ(PCAT:JCatalog) ))
                                       PS:Set )
                  ( -4:Int |-> SetItem(E:JExecReceipt) ES:Set )
                  L2:Map </jlineage>
    requires GateInputMatchesBlockJ(FC:ExecCtx, RG:LinRecG, CERT:AuthzCert,
                                    B:JBlockJ)
         andBool GateAuthorityMatchesCfgJ(FC:ExecCtx, C:ProtoCfgR3)
         andBool BytesEq(jbParentCommitOf(B:JBlockJ), H:Bytes)
         andBool jbSlotOf(B:JBlockJ) ==Int N:Int
         andBool ExecReceiptMatchesBlockJ(E:JExecReceipt, B:JBlockJ)
         andBool ExecReceiptMatchesRecordJ(E:JExecReceipt, RG:LinRecG)
         andBool BytesEq(jerHeadOf(E:JExecReceipt), H:Bytes)
         andBool jerSlotOf(E:JExecReceipt) ==Int N:Int
         andBool BytesEq(jerLinHeadOf(E:JExecReceipt), LH:Bytes)
         andBool BytesEq(jerAnchorOf(E:JExecReceipt), A:Bytes)

  // the gate-receipt pool does not exist yet (first mint)
  rule <k> pGateEvalJ(B:JBlockJ, FC:ExecCtx, RG:LinRecG, CERT:AuthzCert,
                      ERC:Bytes, ERP:Bytes) => .K ... </k>
       <jnext> N:Int </jnext>
       <jhead> H:Bytes </jhead>
       <jlinhead> LH:Bytes </jlinhead>
       <janchor> A:Bytes </janchor>
       <jlineage> ( -1:Int |-> C:ProtoCfgR3 )
                  ( -3:Int |-> PCAT:JCatalog )
                  ( -4:Int |-> SetItem(E:JExecReceipt) ES:Set )
                  L2:Map
               => ( -1:Int |-> C:ProtoCfgR3 )
                  ( -3:Int |-> PCAT:JCatalog )
                  ( -2:Int |-> SetItem(
                        jGateReceipt( B:JBlockJ, ERC:Bytes, ERP:Bytes
                                    , FC:ExecCtx, RG:LinRecG
                                    , CERT:AuthzCert
                                    , azCtx( FC:ExecCtx
                                           , ProtoAuthorizedSecCtxR3(
                                                 C:ProtoCfgR3
                                               , jbParentRootOf(B:JBlockJ) )
                                           , CERT:AuthzCert
                                           , qcrAuthPTOf(C:ProtoCfgR3)
                                           , qcrAuthGuestDOf(C:ProtoCfgR3)
                                           , qcrAuthCfgDOf(C:ProtoCfgR3) )
                                    , E:JExecReceipt
                                    , VerifyLineageG(
                                          RG:LinRecG
                                        , azCtx( FC:ExecCtx
                                               , ProtoAuthorizedSecCtxR3(
                                                     C:ProtoCfgR3
                                                   , jbParentRootOf(B:JBlockJ) )
                                               , CERT:AuthzCert
                                               , qcrAuthPTOf(C:ProtoCfgR3)
                                               , qcrAuthGuestDOf(C:ProtoCfgR3)
                                               , qcrAuthCfgDOf(C:ProtoCfgR3) )
                                        , N:Int, LH:Bytes )
                                    , H:Bytes, N:Int, LH:Bytes
                                    , C:ProtoCfgR3
                                    , ProtoRootR3(C:ProtoCfgR3)
                                    , A:Bytes
                                    , JCatalogRootJ(PCAT:JCatalog) ))
                                       .Set )
                  ( -4:Int |-> SetItem(E:JExecReceipt) ES:Set )
                  L2:Map </jlineage>
    requires notBool ( -2:Int in_keys(L2:Map) )
         andBool GateInputMatchesBlockJ(FC:ExecCtx, RG:LinRecG, CERT:AuthzCert,
                                        B:JBlockJ)
         andBool GateAuthorityMatchesCfgJ(FC:ExecCtx, C:ProtoCfgR3)
         andBool BytesEq(jbParentCommitOf(B:JBlockJ), H:Bytes)
         andBool jbSlotOf(B:JBlockJ) ==Int N:Int
         andBool ExecReceiptMatchesBlockJ(E:JExecReceipt, B:JBlockJ)
         andBool ExecReceiptMatchesRecordJ(E:JExecReceipt, RG:LinRecG)
         andBool BytesEq(jerHeadOf(E:JExecReceipt), H:Bytes)
         andBool jerSlotOf(E:JExecReceipt) ==Int N:Int
         andBool BytesEq(jerLinHeadOf(E:JExecReceipt), LH:Bytes)
         andBool BytesEq(jerAnchorOf(E:JExecReceipt), A:Bytes)

  // ---------------------------------------------------------------------------
  // pCommitJ — the ONLY rule that extends the committed chain (handoff §7).
  //   Guard order = the R3 discipline: DECIDABLE conjuncts first (every
  //   structural rejection resolves concretely on the Haskell backend), then
  //   the COMPUTED policy result (footprint registration, bounded closure,
  //   SafeJ on the DERIVED post-state), then the hash-class conjuncts.
  //   On accept BOTH receipts are consumed exactly once (single-use), the
  //   lineage head advances to the accepted record's F-child, the protocol
  //   head advances to the J block commitment, and the abstract state moves
  //   to the DERIVED post-state.
  // ---------------------------------------------------------------------------
  rule <k> pCommitJ(B:JBlockJ, ERC:Bytes, ERP:Bytes, CV:Int) => .K ... </k>
       <janchor> A:Bytes </janchor>
       <jstate> _:Map => jerPostOf(jgExecOf(R:JGateReceipt)) </jstate>
       <jlineage> ( -1:Int |-> C:ProtoCfgR3 )
                  ( -3:Int |-> PCAT:JCatalog )
                  ( -2:Int |-> SetItem(R:JGateReceipt) RS:Set )
                  ( -4:Int |-> SetItem(jgExecOf(R:JGateReceipt)) ES:Set )
                  L3:Map
               => ( -1:Int |-> C:ProtoCfgR3 )
                  ( -3:Int |-> PCAT:JCatalog )
                  ( -2:Int |-> RS:Set )
                  ( -4:Int |-> ES:Set )
                  ( L3[jbSlotOf(B:JBlockJ) <- B:JBlockJ] )
               </jlineage>
       <jnext> N:Int => N +Int 1 </jnext>
       <jhead> H:Bytes => JBlockCommitJ(B:JBlockJ, C:ProtoCfgR3) </jhead>
       <jlinhead> LH:Bytes => JRecChildF(jgRGOf(R:JGateReceipt)) </jlinhead>
       <jvalid> V:Bool => V:Bool </jvalid>
    requires jgBlockOf(R:JGateReceipt) ==K B:JBlockJ          // receipt match
         andBool jgErcOf(R:JGateReceipt) ==K ERC:Bytes
         andBool jgErpOf(R:JGateReceipt) ==K ERP:Bytes
         andBool jgHeadOf(R:JGateReceipt) ==K H:Bytes          // head freshness
         andBool jgSlotOf(R:JGateReceipt) ==Int N:Int          // slot freshness
         andBool jgLinHeadOf(R:JGateReceipt) ==K LH:Bytes      // lineage freshness
         andBool CfgEqR3(jgCfgOf(R:JGateReceipt), C:ProtoCfgR3) // cfg identity
         andBool BytesEq(jgAnchorOf(R:JGateReceipt), A:Bytes)  // ANCHOR re-check
         andBool jgDecisionOf(R:JGateReceipt) ==Int pdecValidJ // DERIVED decision
         andBool jbDecisionOf(B:JBlockJ) ==Int pdecValidJ      // decision binding
         andBool ExecValidPJ(B:JBlockJ, ERC:Bytes, ERP:Bytes)  // execution binding
         andBool BytesEq(linAzCertDOf(jgRGOf(R:JGateReceipt)),
                         jbEvidenceIdOf(B:JBlockJ))            // evidence identity
         andBool GateInputMatchesBlockJ(jgFCOf(R:JGateReceipt),
                                        jgRGOf(R:JGateReceipt),
                                        jgCERTOf(R:JGateReceipt),
                                        B:JBlockJ)             // input binding
         andBool ExecReceiptMatchesBlockJ(jgExecOf(R:JGateReceipt),
                                          B:JBlockJ)           // derived-exec binding
         andBool ExecReceiptMatchesRecordJ(jgExecOf(R:JGateReceipt),
                                           jgRGOf(R:JGateReceipt))
         andBool BytesEq(jerHeadOf(jgExecOf(R:JGateReceipt)), H:Bytes)
         andBool jerSlotOf(jgExecOf(R:JGateReceipt)) ==Int N:Int
         andBool BytesEq(jerLinHeadOf(jgExecOf(R:JGateReceipt)), LH:Bytes)
         andBool BytesEq(jerAnchorOf(jgExecOf(R:JGateReceipt)), A:Bytes)
         andBool GateCtxAuthorizedJ(jgACOf(R:JGateReceipt), C:ProtoCfgR3,
                                    jbParentRootOf(B:JBlockJ)) // ctx authority
         andBool GateAuthorityMatchesCfgJ(jgFCOf(R:JGateReceipt),
                                          C:ProtoCfgR3)        // pinned authority
         andBool BytesEq(jbParentCommitOf(B:JBlockJ), H:Bytes) // parent commitment
         andBool jbSlotOf(B:JBlockJ) ==Int N:Int               // one block per slot
         andBool CV ==Int qcrPolicyVOf(C:ProtoCfgR3)           // config witness
         // ===== the COMPUTED J POLICY RESULT (never caller-supplied) =====
         andBool JFootprintRegistered(
                     JFootprintKeysOf(jerTraceOf(jgExecOf(R:JGateReceipt))),
                     jcResourcesOf(PCAT:JCatalog))             // registry closure
         andBool isJClosureOk(
                     AffectedClosureJ(
                         JFootprintKeysOf(jerTraceOf(jgExecOf(R:JGateReceipt))),
                         jcHypersOf(PCAT:JCatalog), JClosureFuelJ)) // bounded closure
         andBool SafeJ(PCAT:JCatalog,
                       jerPostOf(jgExecOf(R:JGateReceipt)))    // Safe_P on derived post
         // ===== hash-class conjuncts (last; symbolic on hs) =====
         andBool BytesEq(jgRootOf(R:JGateReceipt),
                         ProtoRootR3(C:ProtoCfgR3))            // ROOT re-check [hash]
         andBool BytesEq(jgCatRootOf(R:JGateReceipt),
                         JCatalogRootJ(PCAT:JCatalog))         // CATALOG re-check [hash]

  // REJECT (restore, [owise]): ANY failure — no pinned config/catalog, no
  // gate receipt, a receipt for a different candidate/head/lineage-head/
  // slot/config/anchor/root, a rejection or unknown COMPUTED verdict, an
  // execution mismatch, a gate-input mismatch, a derived-execution
  // mismatch, an unauthorized context, a pinned-authority mismatch, a
  // config-version substitution, an unregistered footprint key, closure
  // exhaustion, ANY failing invariant (local, hyperedge, or global), or a
  // root/catalog-root mismatch — leaves EVERY cell completely unchanged
  // (fail-closed; the receipts are NOT consumed).
  rule <k> pCommitJ(_:JBlockJ, _:Bytes, _:Bytes, _:Int) => .K ... </k>
       <jlineage> L:Map </jlineage>
       <jnext> N:Int </jnext>
       <jhead> H:Bytes </jhead>
       <jlinhead> LH:Bytes </jlinhead>
       <janchor> A:Bytes </janchor>
       <jstate> S:Map </jstate>
       <jrefuse> RF:JRefuse </jrefuse>
       <jvalid> V:Bool </jvalid>
    [owise]

  // the closure-result predicate + selector used by the guard
  syntax Bool ::= isJClosureOk ( JClosure ) [function, total]
  rule isJClosureOk(jClosureOk(_:List)) => true
  rule isJClosureOk(_:JClosure) => false [owise]

  syntax List ::= jClosureOkAffectedOf ( JClosure ) [function, total]
  rule jClosureOkAffectedOf(jClosureOk(A:List)) => A:List
  rule jClosureOkAffectedOf(_:JClosure) => .List [owise]

endmodule
