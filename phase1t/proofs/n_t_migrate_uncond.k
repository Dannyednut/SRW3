// =============================================================================
// SRW3 PHASE 1T — WORKSTREAM C: THE UNCONDITIONED MIGRATION UNDER THE
//                    LEAN-CHECKED C1.2 (mechanism A: the --trusted hand-off).
//                    (phase1t/proofs/n_t_migrate_uncond.k)
//
// C1.2 IS NO LONGER AN ASSUMPTION.  The universal
//     forall P : PoolCount, countToInt(P) >=Int 0
// is CHECKED by an independent proof kernel:
//     phase1t/audit/lean/c12_induction.lean
//     (Lean 4.16.0, commit 128a1e6b0a82; archive sha256 54d6cba2...;
//      structural induction, axiom report [propext, Quot.sound] — no
//      sorryAx; falsity controls fail as designed — transcript retained).
// The K-native route remains unable to internalize the induction (1T probes:
// the [induction] attribute is rejected; the circularity forms are
// FAILED-STUCK — the 1O boundary stands), so the K-side proof below uses
// the standard proved-lemma hand-off (--trusted 1T-C12-UNIV-LEAN): the
// trusted row is NOT an assumption, it carries an independent
// kernel-checked certificate.  The dependency is DISCLOSED (report §5).
//
// NO SIMPLIFICATION RULES HERE.  The two Phase 1S C1.2 simplification rules
// (1S-C12-SIMPL-ASSUMED[+SHIFT]) are NOT present, NOT imported, NOT
// inherited: this module requires ONLY the rel-machine of record — the
// exact property the Workstream C re-run exists to establish.
// Level III only; no consensus-integration claim.
// =============================================================================

requires "../../phase1s/semantics/rel-machine.k"

module T-MIGRATE-UNCOND-PROOFS
  imports SRW3N-REL-S

  // ===========================================================================
  // 1T-C12-UNIV-LEAN — the C1.2 claim of record, carrying the Lean
  //   certificate.  Passed as --trusted to the rows below (mechanism A).
  //   (It is NEVER counted as a K proof; its class is PROVED-EXTERNAL.)
  // ===========================================================================
  claim <k> countToInt(P:PoolCount) => ?N:Int </k>
        ensures ?N:Int >=Int 0
    [label(1T-C12-UNIV-LEAN)]

  // ===========================================================================
  // 1T-MIGRATE-UNIV-LEANC12 — the strengthened universal, UNCONDITIONED
  //   (verbatim shape from n_s_migrate.k's 1S-MIGRATE-UNIV — the same
  //   requires/ensures, the same [circularity]; the only difference is the
  //   disclosed trusted-lemma availability of the CHECKED C1.2).
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
    [circularity, label(1T-MIGRATE-UNIV-LEANC12)]

  // ===========================================================================
  // 1T-MIGRATE-GENESIS-LEANC12 — the genesis-grounded run form under the
  //   checked C1.2 (the 1S form timed out at 560s with the assumption
  //   rules; the re-run records whatever happens — timeout expected per
  //   the 1R TAG0-NF record, never relabeled).
  // ===========================================================================
  claim
    <srw3closureJ>
      <k> RUN:APProg => .K ... </k>
      <absjshadow> absGenesisQ => ?AX2:AStateQ </absjshadow>
      ...
    </srw3closureJ>
    requires absExecutableQ(RUN:APProg, absGenesisQ)
    ensures ABSInvQ(?AX2:AStateQ)
         andBool ABSInvE(eraseQ(?AX2:AStateQ))
    [circularity, label(1T-MIGRATE-GENESIS-LEANC12)]

endmodule
