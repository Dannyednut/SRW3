// =============================================================================
// SRW3 PHASE 1T — WORKSTREAM A CONTROLS: the false-goal and mutated-
//                    transition controls INSIDE the C12-assumption harness.
//                    (phase1t/proofs/n_t_wsa_controls.k)
//
// Purpose (mission §2): detect misleading closures of the conditional
// migration battery.  The C1.2 assumption rules below are the EXACT
// Phase 1S disclosed simplifications (label-preserving copies); the false
// goals below share the same harness (same definition, same requires, same
// assumption rules, same claim shape).  If a false goal CLOSES, the harness
// is unsound and the 1S conditional result is suspect — STOP AND INVESTIGATE.
//
// Every row here is a CONTROL: expected outcome is recorded next to it and
// any deviation is an alarm, never a theorem.
// Level III only; no consensus-integration claim.
// =============================================================================

requires "../../phase1s/semantics/rel-machine.k"

module T-WSA-CONTROLS
  imports SRW3N-REL-S

  // ---------------------------------------------------------------------------
  // THE SAME TWO DISCLOSED C1.2 ASSUMPTION RULES (copies of
  // n_s_migrate_c12.k lines 38-42; labels suffixed -1TCTRL so the two
  // batteries can never be confused in a log):
  // ---------------------------------------------------------------------------
  rule countToInt(P:PoolCount) >=Int 0 => true
    [simplification, label(1S-C12-SIMPL-ASSUMED-1TCTRL)]

  rule countToInt(P:PoolCount) +Int I:Int >=Int 0 => true requires I >=Int 0
    [simplification, label(1S-C12-SIMPL-ASSUMED-SHIFT-1TCTRL)]

  // ===========================================================================
  // 1T-WSA-CTRL-DEST-FALSE (MUST FAIL) — the destination-falsity control
  //   INSIDE the assumption harness: with the C1.2 rules active, an
  //   executable run from the genesis STILL does not always end at the
  //   genesis.  If this closes, the assumption rules are strong enough to
  //   prove falsehood — the harness is unsound.
  // ===========================================================================
  claim
    <srw3closureJ>
      <k> RUN:APProg => .K ... </k>
      <absjshadow> absGenesisQ => ?AX2:AStateQ </absjshadow>
      ...
    </srw3closureJ>
    requires absExecutableQ(RUN:APProg, absGenesisQ)
    ensures ?AX2:AStateQ ==K absGenesisQ
    [label(1T-WSA-CTRL-DEST-FALSE)]

  // ===========================================================================
  // 1T-WSA-CTRL-SAFETY-FALSE (MUST FAIL) — the goal-falsity control INSIDE
  //   the assumption harness: the strengthened universal with a FALSE
  //   extra conjunct (the end state's G pool is exactly zeroP).  The C1.2
  //   assumption says nothing about end-state pool shapes; if this closes,
  //   the conditional battery's closure is vacuous or unsound.
  // ===========================================================================
  claim
    <srw3closureJ>
      <k> RUN:APProg => .K ... </k>
      <absjshadow> AX:AStateQ => absStQ(?TG:Int, ?C:Bool, ?T:Bool, zeroP, ?E2:PoolCount, ?N2:Int, ?SF:Bool, ?D:ADiag) </absjshadow>
      ...
    </srw3closureJ>
    requires ABSInvQ(AX)
         andBool ABSInvE(eraseQ(AX))
         andBool tagCoherentQ(AX)
         andBool absExecutableQ(RUN:APProg, AX:AStateQ)
    ensures true
    [label(1T-WSA-CTRL-SAFETY-FALSE)]

endmodule
