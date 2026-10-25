// =============================================================================
// SRW3 PHASE 1S — THE MIGRATION BATTERY (mission §6)
//                    (phase1s/proofs/n_s_migrate.k)
//
// THE MIGRATION THEOREM OF RECORD — the Phase 1R universal invariant-
// preservation theorem (1R-UNIV-COMPOSED-QS, the constructor-count model's
// universal) MIGRATED to the integer model's actual safety predicate:
//
//   the strengthened universal over the SAME runner:
//     ABSInvQ(AX) ∧ ABSInvE(eraseQ(AX)) ∧ tagCoherentQ(AX)
//       ∧ absExecutableQ(RUN, AX)
//     →  ABSInvQ(end) ∧ ABSInvE(eraseQ(end))
//
// The ensured integer conjunct is the 1P invariant MEANING of record
// (ABSInvE — the C4 subject, including the tag-1 nonnegativity conjuncts).
// The proof MUST use: the initial correspondence (1S-INIT-CORR-*), the
// per-class transition correspondence (1S-CORR-*), the count nonnegativity
// (C1.2 — THE COMMIT-ACCEPT SPOT), the exact update correspondences
// (C1.3/C1.4), and the integer safety predicate itself (ABSInvE).
//
// FIVE-STATE SEPARATION (mission §6; see report §7): this battery's
// closures establish state 2 ONLY (the 1P integer-model universal over the
// in-repo image, under the disclosed C1.2 disposition where applicable).
// States 3/4/5 (full representation equivalence, concrete-implementation
// correspondence, actual protocol-commitment-boundary safety) are NOT
// established by any claim here and never stated.
//
// Whatever the raw results, they are recorded and never relabeled.
// Level III only; no consensus-integration claim.
// =============================================================================

requires "../semantics/rel-machine.k"

module S-MIGRATE-PROOFS
  imports SRW3N-REL-S

  // ===========================================================================
  // 1S-MIGRATE-UNIV — the strengthened universal, UNCONDITIONED (the
  //   attempt of record). Expected residual: the commit-accept cell —
  //   re-establishing ABSInvE(eraseQ(absStepQ(AX, commit-accept))) needs
  //   countToInt(G0) >=Int 0 where the carried hypothesis gives only
  //   countToInt(G0) +Int 1 >=Int 0 — the exact C1.2 spot (the strip
  //   class). Whatever happens — residual or timeout — is recorded.
  // ===========================================================================
  claim
    <srw3closureJ>
      <k> RUN:APProg => .K ... </k>
      <absjshadow> AX:AStateQ => ?AX2:AStateQ </absjshadow>
      ...
    </srw3closureJ>
    requires ABSInvQ(AX)
         andBool ABSInvE(eraseQ(AX))
         andBool tagCoherentQ(AX)
         andBool absExecutableQ(RUN:APProg, AX:AStateQ)
    ensures ABSInvQ(?AX2:AStateQ)
         andBool ABSInvE(eraseQ(?AX2:AStateQ))
    [circularity, label(1S-MIGRATE-UNIV)]

  // ===========================================================================
  // (THE C12ASSUMED VARIANTS LIVE IN n_s_migrate_c12.k — the disclosed C1.2
  //  simplification must not be visible to the unconditional attempt of
  //  record above. The first trusted-cell-claim form of the axiom could not
  //  discharge pure conditions: its residual was IDENTICAL to the
  //  unconditional one — retained:
  //  transcripts/k/kprove_1S-MIGRATE-UNIV-C12ASSUMED.log.)
  // ===========================================================================

  // ===========================================================================
  // 1S-MIGRATE-DEST-NEG (MUST FAIL) and its CONCRETE sharpening: an
  //   executable run from the genesis does NOT always end at the genesis.
  //   The symbolic form TIMES OUT (the checker unrolls the executable-
  //   predicate fold; recorded as TIMEOUT-NOT-A-PROOF); the CONCRETE form
  //   (the honest pipeline: init then exec) closes by real rewriting and
  //   fails as designed — the falsity witness of record.
  // ===========================================================================
  claim
    <srw3closureJ>
      <k> RUN:APProg => .K ... </k>
      <absjshadow> absGenesisQ => ?AX2:AStateQ </absjshadow>
      ...
    </srw3closureJ>
    requires absExecutableQ(RUN:APProg, absGenesisQ)
    ensures ?AX2:AStateQ ==K absGenesisQ
    [label(1S-MIGRATE-DEST-NEG)]

  claim
    <srw3closureJ>
      <k> aConsJ(aInitJ(aOkT:AOk), aConsJ(aExecJ(aOkT:AOk, aSrcAuth:ASrc), aRunNilJ)) => .K ... </k>
      <absjshadow> absGenesisQ => ?AX2:AStateQ </absjshadow>
      ...
    </srw3closureJ>
    ensures ?AX2:AStateQ ==K absGenesisQ
    [label(1S-MIGRATE-DEST-NEG-CONCRETE)]

  claim <k> absStepQ(absGenesisQ, aInitJ(aOkT)) => absGenesisQ </k>
    [label(1S-MIGRATE-DEST-NEG-STEP)]

  // ===========================================================================
  // 1S-SEP-INCOHERENT-NOT-RELATED — the five-state-separation witness
  //   (MUST FAIL): the incoherent tag-7 state is NOT StateRel-related to
  //   its fieldwise mirror (the range conjunct (e0) refuses it). The
  //   correspondence is a COHERENT-FRAGMENT relation, never a total
  //   isomorphism — one of the reasons the results are not a
  //   bisimulation and not "full representation equivalence".
  // ===========================================================================
  claim <k> StateRel(absStQ(7, true, true, zeroP, zeroP, 0, false, adNone),
                     absStQE(true, true, 0, 0, 0, false, adNone)) => true </k>
    [label(1S-SEP-INCOHERENT-NOT-RELATED)]

endmodule
