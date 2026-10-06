// =============================================================================
// SRW3 Phase 1F — K demonstration suite (phase1f/semantics/srw3exec-demo.k)
//
// Level-3 case study at the abstract layer: the Oracle → Lending → Liquidator
// lineage as a three-record chain of LinRecF with execution-identity and
// parent-root threading. Accounts mirror the KEVM layer:
//   4097 = Oracle, 4098 = Lending, 4099 = Liquidator.
//
// Scenario:
//   R0 oracle update     tid=0: T0=[Write(4097,0,100)]          parent=LinRoot
//   R1 lending borrow    tid=1: T1=[Read(4097,0,100),
//                                   Write(4098,0,100),
//                                   Write(4098,1,100)]        parent=R0
//   R2 liquidation       tid=2: T2=[Read(4098,0,100), Read(4098,1,100),
//                                   Read(4097,0,100), Write(4099,0,100),
//                                   Write(4098,1,50), Write(4098,1,0)]
//                                                        parent=R1
//   (the R2 trace carries an intermediate same-slot write corrected by the
//    final write — last-write-wins makes the final map (4098,1):=0)
//
//   pos0/pos1/pos2  honest chain ............................ "valid-f"
//   f8a/f8b         equal final state, divergent traces (R2 vs R2alt with
//                   a trailing redundant read): BOTH accepted, digests
//                   DIFFER — the model never infers trace from state ....
//                                        "valid-f" both; f8diff=true
//   neg1 (F1) hidden write in the trace, declared effects unchanged
//                                                 ... "invalid-effdecl"
//        (the LEVEL-3 core check: declared != Writes(trace))
//   neg2 (F2) read suppressed from the presented trace while the
//             record's digest covers it ................... "invalid-efftrace"
//   neg3 (F4) same-slot write order swapped AND the value changed, fully
//             re-presented (declared/post re-forged coherently) — the
//             HONEST ANCHOR rejects at Level 2 first ... "invalid-anchor"
//   neg3x(F4) cross-slot write order swapped (same final map, same declared
//             effects, re-bound trace): accepted BY DESIGN — cross-slot
//             order is not security-relevant in the fragment; the trace
//             digest still binds it (neg3xdiff=true) ......... "valid-f"
//   neg4 (F5) execution replayed against a STALE parent root  "invalid-execid"
//   neg5 (F6) fork-spec replaced (spec 2 vs 1) ....... "invalid-execconfig"
//   neg6 (F7) witness bound to a foreign trace digest ........ "invalid-witness"
//   neg7     fragment bounds refuse (app = 2^32) ...... "invalid-execbounds"
//   neg8 (F2 residual) FALSE READ OBSERVATION (the oracle-staleness class):
//             every digest re-bound coherently, all legacy+L2 green — the
//             replay catches the observation ......... "invalid-effbind"
//
// Expected verdict strings (partitioned programs; the concatenated form
// exceeds the 3 GB sandbox as ONE term):
//   xpos0 : valid-f
//   xchain: pos1=valid-f;pos2=valid-f
//   xf8   : f8a=valid-f;f8b=valid-f;f8diff=true
//   xnegs : neg1=invalid-effdecl;neg2=invalid-efftrace;neg3=invalid-anchor;
//           neg3x=valid-f;neg3xdiff=true;neg4=invalid-execid;
//           neg5=invalid-execconfig;neg6=invalid-witness;
//           neg7=invalid-execbounds;neg8=invalid-effbind
//   xbytes: cross-layer byte certificate source
// =============================================================================

requires "srw3exec.k"

module SRW3EXEC-DEMO
  imports SRW3EXEC

  configuration <srw3exec>
                  <k> $PGM </k>
                  <xresult> "" </xresult>
                </srw3exec>

  syntax ExecPgm ::= "execsuite" | "xpos0" | "xchain" | "xnegs" | "xnegs2" | "xbytes" | "xf8"

  // ---- shared verification context constants --------------------------------
  syntax Map ::= "XReg" [function, total]
  rule XReg => 5 |-> true  6 |-> true
  syntax Set ::= "XAuth" [function, total]
  rule XAuth => SetItem(LinAddrOf(LinDemoKey1)) SetItem(LinAddrOf(LinDemoKey2))
  syntax Bytes ::= "XCaller" [function, total]
  rule XCaller => LinAddrOf(LinDemoKey1)

  // payloads (valid hex): ORACLE1 / BORROW1 / LIQUIDATE1
  syntax Bytes ::= "XPld0" [function, total]
  rule XPld0 => LinHex("4f5241434c4531")
  syntax Bytes ::= "XPld1" [function, total]
  rule XPld1 => LinHex("424f52524f5731")
  syntax Bytes ::= "XPld2" [function, total]
  rule XPld2 => LinHex("4c495155494441544531")

  // ---- R0: oracle update -----------------------------------------------------
  syntax Map ::= "XQ0" [function, total]
  rule XQ0 => LinKV1(4097, 0, 0)
  syntax Map ::= "XE0" [function, total]
  rule XE0 => LinKV1(4097, 0, 100)
  syntax Map ::= "XP0" [function, total]
  rule XP0 => LinKV1(4097, 0, 100)     // independent post (slot-by-slot)
  syntax List ::= "XT0" [function, total]
  rule XT0 => ListItem( exEvt(2, 4097, 0, 100) )
  syntax LinRecF ::= "XR0" [function, total]
  rule XR0 => ExecBuildRecF(0, LinRoot, XQ0, XE0, XP0, LinDemoKey1, 5,
                            XT0, XPld0, ExecSchedCANCUN(), 1, XCaller, 0, LinRoot)
  syntax Bytes ::= "XSR0" [function, total]   // R0's anchored state root
  rule XSR0 => linStateRootOf(linRecFBase(XR0))
  syntax Bytes ::= "XCF0" [function, total]   // R0's extended child commitment
  rule XCF0 => ExecChildF( linRecFBase(XR0), linExecIdOf(XR0)
                         , linEffTraceDOf(XR0), linExecWDOf(XR0)
                         , linExecCfgDOf(XR0) )
  syntax ExecCtx ::= "XCtx0" [function, total]
  rule XCtx0
    => execCtx( authCtx( linCtxP(XQ0, XE0, XP0, XReg, XAuth)
                       , XSR0 )
              , LinRoot, XPld0, ExecSchedCANCUN(), 1, XCaller, 0
              , XT0
              , execWit( 1, LinRoot
                       , ExecExecId( LinRoot, ExecPayloadDigest(XPld0)
                                   , ExecConfigDigest(ExecSchedCANCUN(), 1)
                                   , ExecEnvDigest(XCaller, 0) )
                       , ExecPayloadDigest(XPld0)
                       , LinH(LinCanonKV(XE0))
                       , ExecTraceDigest(XT0)
                       , XSR0
                       , ExecConfigDigest(ExecSchedCANCUN(), 1) ) )

  // ---- R1: lending borrow (reads the oracle price) ---------------------------
  syntax Map ::= "XQ1" [function, total]
  rule XQ1 => LinSetKV(LinSetKV(LinKV1(4097, 0, 100), 4098, 0, 0), 4098, 1, 0)
  syntax Map ::= "XE1" [function, total]
  rule XE1 => LinSetKV(LinKV1(4098, 0, 100), 4098, 1, 100)
  syntax Map ::= "XP1" [function, total]
  rule XP1 => LinSetKV(LinSetKV(LinKV1(4097, 0, 100), 4098, 0, 100), 4098, 1, 100)
  syntax List ::= "XT1" [function, total]
  rule XT1 => ListItem( exEvt(1, 4097, 0, 100) )
             ListItem( exEvt(2, 4098, 0, 100) )
             ListItem( exEvt(2, 4098, 1, 100) )
  syntax LinRecF ::= "XR1" [function, total]
  rule XR1 => ExecBuildRecF(1, XCF0, XQ1, XE1, XP1, LinDemoKey1, 5,
                            XT1, XPld1, ExecSchedCANCUN(), 1, XCaller, 0, XSR0)
  syntax Bytes ::= "XSR1" [function, total]
  rule XSR1 => linStateRootOf(linRecFBase(XR1))
  syntax Bytes ::= "XCF1" [function, total]
  rule XCF1 => ExecChildF( linRecFBase(XR1), linExecIdOf(XR1)
                         , linEffTraceDOf(XR1), linExecWDOf(XR1)
                         , linExecCfgDOf(XR1) )
  syntax ExecCtx ::= "XCtx1" [function, total]
  rule XCtx1
    => execCtx( authCtx( linCtxP(XQ1, XE1, XP1, XReg, XAuth), XSR1 )
              , XSR0, XPld1, ExecSchedCANCUN(), 1, XCaller, 0
              , XT1
              , execWit( 1, XSR0
                       , ExecExecId( XSR0, ExecPayloadDigest(XPld1)
                                   , ExecConfigDigest(ExecSchedCANCUN(), 1)
                                   , ExecEnvDigest(XCaller, 0) )
                       , ExecPayloadDigest(XPld1)
                       , LinH(LinCanonKV(XE1))
                       , ExecTraceDigest(XT1)
                       , XSR1
                       , ExecConfigDigest(ExecSchedCANCUN(), 1) ) )

  // ---- R2: liquidation (reads lending + oracle, writes liquidator, corrects
  //      the lending collateral slot through an intermediate write) -----------
  syntax Map ::= "XQ2" [function, total]
  rule XQ2 => LinSetKV(XP1, 4099, 0, 0)
  syntax Map ::= "XE2" [function, total]
  rule XE2 => LinSetKV(LinKV1(4099, 0, 100), 4098, 1, 0)
  syntax Map ::= "XP2" [function, total]
  rule XP2 => LinSetKV(LinSetKV(LinSetKV(LinKV1(4097, 0, 100), 4098, 0, 100),
                                4098, 1, 0), 4099, 0, 100)
  syntax List ::= "XT2" [function, total]
  rule XT2 => ListItem( exEvt(1, 4098, 0, 100) )
             ListItem( exEvt(1, 4098, 1, 100) )
             ListItem( exEvt(1, 4097, 0, 100) )
             ListItem( exEvt(2, 4099, 0, 100) )
             ListItem( exEvt(2, 4098, 1, 50) )
             ListItem( exEvt(2, 4098, 1, 0) )
  syntax LinRecF ::= "XR2" [function, total]
  rule XR2 => ExecBuildRecF(2, XCF1, XQ2, XE2, XP2, LinDemoKey1, 5,
                            XT2, XPld2, ExecSchedCANCUN(), 1, XCaller, 0, XSR1)
  syntax Bytes ::= "XSR2" [function, total]
  rule XSR2 => linStateRootOf(linRecFBase(XR2))
  syntax ExecCtx ::= "XCtx2" [function, total]
  rule XCtx2
    => execCtx( authCtx( linCtxP(XQ2, XE2, XP2, XReg, XAuth), XSR2 )
              , XSR1, XPld2, ExecSchedCANCUN(), 1, XCaller, 0
              , XT2
              , execWit( 1, XSR1
                       , ExecExecId( XSR1, ExecPayloadDigest(XPld2)
                                   , ExecConfigDigest(ExecSchedCANCUN(), 1)
                                   , ExecEnvDigest(XCaller, 0) )
                       , ExecPayloadDigest(XPld2)
                       , LinH(LinCanonKV(XE2))
                       , ExecTraceDigest(XT2)
                       , XSR2
                       , ExecConfigDigest(ExecSchedCANCUN(), 1) ) )

  // ---- f8: equal final state, divergent trace (trailing redundant read) -----
  syntax List ::= "XT2alt" [function, total]
  rule XT2alt => XT2 ListItem( exEvt(1, 4097, 0, 100) )
  syntax LinRecF ::= "XR2alt" [function, total]
  rule XR2alt => ExecBuildRecF(2, XCF1, XQ2, XE2, XP2, LinDemoKey1, 5,
                               XT2alt, XPld2, ExecSchedCANCUN(), 1, XCaller, 0, XSR1)
  syntax ExecCtx ::= "XCtx2alt" [function, total]
  rule XCtx2alt
    => execCtx( authCtx( linCtxP(XQ2, XE2, XP2, XReg, XAuth), XSR2 )
              , XSR1, XPld2, ExecSchedCANCUN(), 1, XCaller, 0
              , XT2alt
              , execWit( 1, XSR1
                       , ExecExecId( XSR1, ExecPayloadDigest(XPld2)
                                   , ExecConfigDigest(ExecSchedCANCUN(), 1)
                                   , ExecEnvDigest(XCaller, 0) )
                       , ExecPayloadDigest(XPld2)
                       , LinH(LinCanonKV(XE2))
                       , ExecTraceDigest(XT2alt)
                       , XSR2
                       , ExecConfigDigest(ExecSchedCANCUN(), 1) ) )

  // ---- negatives --------------------------------------------------------------
  // neg1 (F1): hidden write (4098,9):=999 present in the trace, declared
  // effects NOT updated — rejected by the LEVEL-3 CORE check (invalid-effdecl)
  syntax List ::= "XT1hidden" [function, total]
  rule XT1hidden => XT1 ListItem( exEvt(2, 4098, 9, 999) )
  syntax LinRecF ::= "XNeg1Rec" [function, total]
  rule XNeg1Rec
    => ExecBuildRecF(1, XCF0, XQ1, XE1, XP1, LinDemoKey1, 5,
                     XT1hidden, XPld1, ExecSchedCANCUN(), 1, XCaller, 0, XSR0)
  syntax ExecCtx ::= "XNeg1Ctx" [function, total]
  rule XNeg1Ctx
    => execCtx( authCtx( linCtxP(XQ1, XE1, XP1, XReg, XAuth), XSR1 )
              , XSR0, XPld1, ExecSchedCANCUN(), 1, XCaller, 0
              , XT1hidden
              , execWit( 1, XSR0
                       , ExecExecId( XSR0, ExecPayloadDigest(XPld1)
                                   , ExecConfigDigest(ExecSchedCANCUN(), 1)
                                   , ExecEnvDigest(XCaller, 0) )
                       , ExecPayloadDigest(XPld1)
                       , LinH(LinCanonKV(XE1))
                       , ExecTraceDigest(XT1hidden)
                       , XSR1
                       , ExecConfigDigest(ExecSchedCANCUN(), 1) ) )

  // neg2 (F2): the read is suppressed from the presented trace; the record's
  // digest still covers the FULL trace (honest build with XT1)
  syntax List ::= "XT1minus" [function, total]
  rule XT1minus => ListItem( exEvt(2, 4098, 0, 100) )
                   ListItem( exEvt(2, 4098, 1, 100) )
  syntax ExecCtx ::= "XNeg2Ctx" [function, total]
  rule XNeg2Ctx
    => execCtx( authCtx( linCtxP(XQ1, XE1, XP1, XReg, XAuth), XSR1 )
              , XSR0, XPld1, ExecSchedCANCUN(), 1, XCaller, 0
              , XT1minus
              , execWit( 1, XSR0
                       , ExecExecId( XSR0, ExecPayloadDigest(XPld1)
                                   , ExecConfigDigest(ExecSchedCANCUN(), 1)
                                   , ExecEnvDigest(XCaller, 0) )
                       , ExecPayloadDigest(XPld1)
                       , LinH(LinCanonKV(XE1))
                       , ExecTraceDigest(XT1)
                       , XSR1
                       , ExecConfigDigest(ExecSchedCANCUN(), 1) ) )

  // neg3 (F4): same-slot write order swapped AND the final value changed;
  // the whole presentation is re-forged coherently (declared E2s, post P2s,
  // trace re-bound, record re-signed) — the HONEST ANCHOR rejects at L2.
  syntax List ::= "XT2swap" [function, total]
  rule XT2swap => ListItem( exEvt(1, 4098, 0, 100) )
                  ListItem( exEvt(1, 4098, 1, 100) )
                  ListItem( exEvt(1, 4097, 0, 100) )
                  ListItem( exEvt(2, 4099, 0, 100) )
                  ListItem( exEvt(2, 4098, 1, 0) )
                  ListItem( exEvt(2, 4098, 1, 50) )
  syntax Map ::= "XE2s" [function, total]
  rule XE2s => LinSetKV(LinKV1(4099, 0, 100), 4098, 1, 50)
  syntax Map ::= "XP2s" [function, total]
  rule XP2s => LinSetKV(LinSetKV(LinSetKV(LinKV1(4097, 0, 100), 4098, 0, 100),
                                 4098, 1, 50), 4099, 0, 100)
  syntax LinRecF ::= "XNeg3Rec" [function, total]
  rule XNeg3Rec
    => ExecBuildRecF(2, XCF1, XQ2, XE2s, XP2s, LinDemoKey1, 5,
                     XT2swap, XPld2, ExecSchedCANCUN(), 1, XCaller, 0, XSR1)
  syntax ExecCtx ::= "XNeg3Ctx" [function, total]
  rule XNeg3Ctx
    => execCtx( authCtx( linCtxP(XQ2, XE2s, XP2s, XReg, XAuth), XSR2 )
              , XSR1, XPld2, ExecSchedCANCUN(), 1, XCaller, 0
              , XT2swap
              , execWit( 1, XSR1
                       , ExecExecId( XSR1, ExecPayloadDigest(XPld2)
                                   , ExecConfigDigest(ExecSchedCANCUN(), 1)
                                   , ExecEnvDigest(XCaller, 0) )
                       , ExecPayloadDigest(XPld2)
                       , LinH(LinCanonKV(XE2s))
                       , ExecTraceDigest(XT2swap)
                       , linStateRootOf(linRecFBase(XNeg3Rec))
                       , ExecConfigDigest(ExecSchedCANCUN(), 1) ) )

  // neg3x (F4 cross-slot): order swapped, SAME final map, same declared
  // effects — accepted by design; the trace digest binds the order.
  syntax List ::= "XT2x" [function, total]
  rule XT2x => ListItem( exEvt(1, 4098, 0, 100) )
              ListItem( exEvt(1, 4098, 1, 100) )
              ListItem( exEvt(1, 4097, 0, 100) )
              ListItem( exEvt(2, 4098, 1, 50) )
              ListItem( exEvt(2, 4099, 0, 100) )
              ListItem( exEvt(2, 4098, 1, 0) )
  syntax LinRecF ::= "XNeg3xRec" [function, total]
  rule XNeg3xRec
    => ExecBuildRecF(2, XCF1, XQ2, XE2, XP2, LinDemoKey1, 5,
                     XT2x, XPld2, ExecSchedCANCUN(), 1, XCaller, 0, XSR1)
  syntax ExecCtx ::= "XNeg3xCtx" [function, total]
  rule XNeg3xCtx
    => execCtx( authCtx( linCtxP(XQ2, XE2, XP2, XReg, XAuth), XSR2 )
              , XSR1, XPld2, ExecSchedCANCUN(), 1, XCaller, 0
              , XT2x
              , execWit( 1, XSR1
                       , ExecExecId( XSR1, ExecPayloadDigest(XPld2)
                                   , ExecConfigDigest(ExecSchedCANCUN(), 1)
                                   , ExecEnvDigest(XCaller, 0) )
                       , ExecPayloadDigest(XPld2)
                       , LinH(LinCanonKV(XE2))
                       , ExecTraceDigest(XT2x)
                       , XSR2
                       , ExecConfigDigest(ExecSchedCANCUN(), 1) ) )

  // neg8 (F2 residual): FALSE READ OBSERVATION — the oracle-staleness class.
  // Every digest re-bound coherently; legacy + Level-2 green; the replay
  // validates observations and rejects.
  syntax List ::= "XT2false" [function, total]
  rule XT2false => ListItem( exEvt(1, 4098, 0, 100) )
                   ListItem( exEvt(1, 4098, 1, 100) )
                   ListItem( exEvt(1, 4097, 0, 7) )
                   ListItem( exEvt(2, 4099, 0, 100) )
                   ListItem( exEvt(2, 4098, 1, 50) )
                   ListItem( exEvt(2, 4098, 1, 0) )
  syntax LinRecF ::= "XNeg8Rec" [function, total]
  rule XNeg8Rec
    => ExecBuildRecF(2, XCF1, XQ2, XE2, XP2, LinDemoKey1, 5,
                     XT2false, XPld2, ExecSchedCANCUN(), 1, XCaller, 0, XSR1)
  syntax ExecCtx ::= "XNeg8Ctx" [function, total]
  rule XNeg8Ctx
    => execCtx( authCtx( linCtxP(XQ2, XE2, XP2, XReg, XAuth), XSR2 )
              , XSR1, XPld2, ExecSchedCANCUN(), 1, XCaller, 0
              , XT2false
              , execWit( 1, XSR1
                       , ExecExecId( XSR1, ExecPayloadDigest(XPld2)
                                   , ExecConfigDigest(ExecSchedCANCUN(), 1)
                                   , ExecEnvDigest(XCaller, 0) )
                       , ExecPayloadDigest(XPld2)
                       , LinH(LinCanonKV(XE2))
                       , ExecTraceDigest(XT2false)
                       , XSR2
                       , ExecConfigDigest(ExecSchedCANCUN(), 1) ) )

  // neg4 (F5): the SAME liquidation replayed against a STALE parent root
  // (R0's root instead of R1's) — legacy chain intact, identity recomputation
  // is what rejects.
  syntax LinRecF ::= "XNeg4Rec" [function, total]
  rule XNeg4Rec
    => ExecBuildRecF(2, XCF1, XQ2, XE2, XP2, LinDemoKey1, 5,
                     XT2, XPld2, ExecSchedCANCUN(), 1, XCaller, 0, XSR0)
  syntax ExecCtx ::= "XNeg4Ctx" [function, total]
  rule XNeg4Ctx
    => execCtx( authCtx( linCtxP(XQ2, XE2, XP2, XReg, XAuth), XSR2 )
              , XSR1, XPld2, ExecSchedCANCUN(), 1, XCaller, 0
              , XT2
              , execWit( 1, XSR0
                       , ExecExecId( XSR0, ExecPayloadDigest(XPld2)
                                   , ExecConfigDigest(ExecSchedCANCUN(), 1)
                                   , ExecEnvDigest(XCaller, 0) )
                       , ExecPayloadDigest(XPld2)
                       , LinH(LinCanonKV(XE2))
                       , ExecTraceDigest(XT2)
                       , XSR2
                       , ExecConfigDigest(ExecSchedCANCUN(), 1) ) )

  // neg5 (F6): fork-spec replacement — record bound to spec 2, context spec 1
  syntax LinRecF ::= "XNeg5Rec" [function, total]
  rule XNeg5Rec
    => ExecBuildRecF(2, XCF1, XQ2, XE2, XP2, LinDemoKey1, 5,
                     XT2, XPld2, ExecSchedCANCUN(), 2, XCaller, 0, XSR1)
  syntax ExecCtx ::= "XNeg5Ctx" [function, total]
  rule XNeg5Ctx
    => execCtx( authCtx( linCtxP(XQ2, XE2, XP2, XReg, XAuth), XSR2 )
              , XSR1, XPld2, ExecSchedCANCUN(), 1, XCaller, 0
              , XT2
              , execWit( 1, XSR1
                       , ExecExecId( XSR1, ExecPayloadDigest(XPld2)
                                   , ExecConfigDigest(ExecSchedCANCUN(), 2)
                                   , ExecEnvDigest(XCaller, 0) )
                       , ExecPayloadDigest(XPld2)
                       , LinH(LinCanonKV(XE2))
                       , ExecTraceDigest(XT2)
                       , XSR2
                       , ExecConfigDigest(ExecSchedCANCUN(), 2) ) )

  // neg6 (F7): witness bound to a FOREIGN trace digest (R1's), record honest
  syntax ExecCtx ::= "XNeg6Ctx" [function, total]
  rule XNeg6Ctx
    => execCtx( authCtx( linCtxP(XQ2, XE2, XP2, XReg, XAuth), XSR2 )
              , XSR1, XPld2, ExecSchedCANCUN(), 1, XCaller, 0
              , XT2
              , execWit( 1, XSR1
                       , ExecExecId( XSR1, ExecPayloadDigest(XPld2)
                                   , ExecConfigDigest(ExecSchedCANCUN(), 1)
                                   , ExecEnvDigest(XCaller, 0) )
                       , ExecPayloadDigest(XPld2)
                       , LinH(LinCanonKV(XE2))
                       , ExecTraceDigest(XT1)
                       , XSR2
                       , ExecConfigDigest(ExecSchedCANCUN(), 1) ) )

  // neg7: fragment bounds refuse — event with app = 2^32
  syntax List ::= "XTbounds" [function, total]
  rule XTbounds => ListItem( exEvt(2, 4294967296, 0, 1) )
  syntax Map ::= "XQb" [function, total]
  rule XQb => LinKV1(4097, 0, 0)
  syntax Map ::= "XEb" [function, total]
  rule XEb => LinKV1(4097, 0, 1)
  syntax Map ::= "XPb" [function, total]
  rule XPb => LinKV1(4097, 0, 1)
  syntax LinRecF ::= "XNeg7Rec" [function, total]
  rule XNeg7Rec
    => ExecBuildRecF(0, LinRoot, XQb, XEb, XPb, LinDemoKey1, 5,
                     XTbounds, XPld0, ExecSchedCANCUN(), 1, XCaller, 0, LinRoot)
  syntax ExecCtx ::= "XNeg7Ctx" [function, total]
  rule XNeg7Ctx
    => execCtx( authCtx( linCtxP(XQb, XEb, XPb, XReg, XAuth),
                         AuthRootOf(AuthUnion3(AuthKeysOfMap(XQb)
                                              ,AuthKeysOfMap(XEb)
                                              ,AuthKeysOfMap(XPb)), XPb) )
              , LinRoot, XPld0, ExecSchedCANCUN(), 1, XCaller, 0
              , XTbounds
              , execWit( 1, LinRoot
                       , ExecExecId( LinRoot, ExecPayloadDigest(XPld0)
                                   , ExecConfigDigest(ExecSchedCANCUN(), 1)
                                   , ExecEnvDigest(XCaller, 0) )
                       , ExecPayloadDigest(XPld0)
                       , LinH(LinCanonKV(XEb))
                       , ExecTraceDigest(XTbounds)
                       , AuthRootOf(AuthUnion3(AuthKeysOfMap(XQb)
                                              ,AuthKeysOfMap(XEb)
                                              ,AuthKeysOfMap(XPb)), XPb)
                       , ExecConfigDigest(ExecSchedCANCUN(), 1) ) )

  // ---- the suite ---------------------------------------------------------------
  syntax String ::= XVerdict ( LinRecF , ExecCtx , Int , Bytes ) [function, total]
  rule XVerdict(RF:LinRecF, C:ExecCtx, T:Int, H:Bytes)
    => VerifyLineageF(RF, C, T, H)

  syntax String ::= Bool2StringX ( Bool ) [function, total]
  rule Bool2StringX(true)  => "true"
  rule Bool2StringX(false) => "false"

  syntax Map ::= LinKV1 ( Int , Int , Int ) [function, total]
  rule LinKV1(A:Int, S:Int, V:Int) => A |-> (S |-> V)

  syntax String ::= "XGATE" [function, total]
  rule XGATE
    =>  "pos0="  +String XVerdict(XR0, XCtx0, 0, LinRoot)
    +String ";pos1="  +String XVerdict(XR1, XCtx1, 1, XCF0)
    +String ";pos2="  +String XVerdict(XR2, XCtx2, 2, XCF1)
    +String ";f8a="   +String XVerdict(XR2, XCtx2, 2, XCF1)
    +String ";f8b="   +String XVerdict(XR2alt, XCtx2alt, 2, XCF1)
    +String ";f8diff=" +String Bool2StringX(
                          notBool BytesEq( linEffTraceDOf(XR2)
                                         , linEffTraceDOf(XR2alt) ) )
    +String ";neg1="  +String XVerdict(XNeg1Rec, XNeg1Ctx, 1, XCF0)
    +String ";neg2="  +String XVerdict(XR1, XNeg2Ctx, 1, XCF0)
    +String ";neg3="  +String XVerdict(XNeg3Rec, XNeg3Ctx, 2, XCF1)
    +String ";neg3x=" +String XVerdict(XNeg3xRec, XNeg3xCtx, 2, XCF1)
    +String ";neg3xdiff=" +String Bool2StringX(
                          notBool BytesEq( linEffTraceDOf(XR2)
                                         , linEffTraceDOf(XNeg3xRec) ) )
    +String ";neg4="  +String XVerdict(XNeg4Rec, XNeg4Ctx, 2, XCF1)
    +String ";neg5="  +String XVerdict(XNeg5Rec, XNeg5Ctx, 2, XCF1)
    +String ";neg6="  +String XVerdict(XR2, XNeg6Ctx, 2, XCF1)
    +String ";neg7="  +String XVerdict(XNeg7Rec, XNeg7Ctx, 0, LinRoot)
    +String ";neg8="  +String XVerdict(XNeg8Rec, XNeg8Ctx, 2, XCF1)
    // cross-layer byte checks (vs Python and KEVM; hex)
    +String "|bytes:trace0=" +String Bytes2StringX(ExecCanonTrace(XT0))
    +String ",payloadd0="    +String Bytes2StringX(ExecPayloadDigest(XPld0))
    +String ",envd="         +String Bytes2StringX(ExecEnvDigest(XCaller, 0))
    +String ",configd="      +String Bytes2StringX(ExecConfigDigest(ExecSchedCANCUN(), 1))
    +String ",execid0="      +String Bytes2StringX(linExecIdOf(XR0))
    +String ",traced0="      +String Bytes2StringX(linEffTraceDOf(XR0))
    +String ",witd0="        +String Bytes2StringX(linExecWDOf(XR0))
    +String ",stateroot0="   +String Bytes2StringX(XSR0)
    +String ",childf0="      +String Bytes2StringX(XCF0)
    +String ",stateroot1="   +String Bytes2StringX(XSR1)
    +String ",childf1="      +String Bytes2StringX(XCF1)
    +String ",execid1="      +String Bytes2StringX(linExecIdOf(XR1))
    +String ",traced1="      +String Bytes2StringX(linEffTraceDOf(XR1))

  syntax String ::= Bytes2StringX ( Bytes ) [function, total]
  rule Bytes2StringX(B:Bytes)
    => Bytes2StringXAux(B, 0, lengthBytes(B))
  syntax String ::= Bytes2StringXAux ( Bytes , Int , Int ) [function, total]
  rule Bytes2StringXAux(B:Bytes, I:Int, N:Int)
    => XHex1(Bytes2Int(substrBytes(B, I, I +Int 1), BE, Unsigned)) +String Bytes2StringXAux(B, I +Int 1, N)
    requires I <Int N
  rule Bytes2StringXAux(_B:Bytes, I:Int, N:Int) => "" requires I >=Int N

  syntax String ::= XHex1 ( Int ) [function, total]
  rule XHex1(I:Int) => XHexDigit(I /Int 16) +String XHexDigit(I modInt 16)
  syntax String ::= XHexDigit ( Int ) [function, total]
  rule XHexDigit(0)  => "0"   rule XHexDigit(1)  => "1"
  rule XHexDigit(2)  => "2"   rule XHexDigit(3)  => "3"
  rule XHexDigit(4)  => "4"   rule XHexDigit(5)  => "5"
  rule XHexDigit(6)  => "6"   rule XHexDigit(7)  => "7"
  rule XHexDigit(8)  => "8"   rule XHexDigit(9)  => "9"
  rule XHexDigit(10) => "a"   rule XHexDigit(11) => "b"
  rule XHexDigit(12) => "c"   rule XHexDigit(13) => "d"
  rule XHexDigit(14) => "e"   rule XHexDigit(15) => "f"
  rule XHexDigit(I:Int) => "?" requires I >Int 15 orBool I <Int 0

  rule <k> execsuite => .K ... </k>
       <xresult> "" => XGATE </xresult>

  rule <k> xpos0 => .K ... </k>
       <xresult> "" => XVerdict(XR0, XCtx0, 0, LinRoot) </xresult>

  rule <k> xchain => .K ... </k>
       <xresult> "" => "pos1=" +String XVerdict(XR1, XCtx1, 1, XCF0)
                        +String ";pos2=" +String XVerdict(XR2, XCtx2, 2, XCF1) </xresult>

  rule <k> xnegs => .K ... </k>
       <xresult> "" => "neg1="  +String XVerdict(XNeg1Rec, XNeg1Ctx, 1, XCF0)
                    +String ";neg2="  +String XVerdict(XR1, XNeg2Ctx, 1, XCF0)
                    +String ";neg3="  +String XVerdict(XNeg3Rec, XNeg3Ctx, 2, XCF1)
                    +String ";neg4="  +String XVerdict(XNeg4Rec, XNeg4Ctx, 2, XCF1)
                    +String ";neg5="  +String XVerdict(XNeg5Rec, XNeg5Ctx, 2, XCF1)
                    +String ";neg6="  +String XVerdict(XR2, XNeg6Ctx, 2, XCF1)
                    +String ";neg7="  +String XVerdict(XNeg7Rec, XNeg7Ctx, 0, LinRoot) </xresult>
  rule <k> xnegs2 => .K ... </k>
       <xresult> "" => "neg3x=" +String XVerdict(XNeg3xRec, XNeg3xCtx, 2, XCF1)
                    +String ";neg3xdiff=" +String Bool2StringX(
                          notBool BytesEq( linEffTraceDOf(XR2)
                                         , linEffTraceDOf(XNeg3xRec) ) )
                    +String ";neg8="  +String XVerdict(XNeg8Rec, XNeg8Ctx, 2, XCF1) </xresult>

  rule <k> xf8 => .K ... </k>
       <xresult> "" => "f8a=" +String XVerdict(XR2, XCtx2, 2, XCF1)
                  +String ";f8b=" +String XVerdict(XR2alt, XCtx2alt, 2, XCF1)
                  +String ";f8diff=" +String Bool2StringX(
                        notBool BytesEq( linEffTraceDOf(XR2)
                                       , linEffTraceDOf(XR2alt) ) ) </xresult>

  rule <k> xbytes => .K ... </k>
       <xresult> "" => "trace0=" +String Bytes2StringX(ExecCanonTrace(XT0))
                  +String ",execid0=" +String Bytes2StringX(linExecIdOf(XR0))
                  +String ",childf0=" +String Bytes2StringX(XCF0) </xresult>

endmodule
