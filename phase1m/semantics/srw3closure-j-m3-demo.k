// =============================================================================
// SRW3 PHASE 1M — M3 DEMONSTRATION MODULE (VERSIONED COPY; make_m3.py)
//                    (phase1m/semantics/srw3closure-j-m1-demo.k)
//
// This file is the FROZEN Phase 1J demo module
// (phase1j/semantics/srw3closure-j-demo.k, sha256 d68b3a3bfbb1a974d8fdb2506bea187b6a00ba72c82c05135868dfc78786a299) with EXACTLY TWO
// mechanical edits (scripts/make_m2.py):
//   1. requires "srw3closure-j-m1.k"  (the M1 repaired machine — the
//      L-FINDING-1 semantic repair; scripts/make_m2.py),
//   2. module SRW3CLOSURE-J-DEMO renamed SRW3CLOSURE-J-M1-DEMO, and the
//      matching import inside the demo module (imports SRW3CLOSURE-J-M1).
// EVERY FIXTURE, DIGEST, AND THE CERTIFICATE COMMAND ARE BYTE-IDENTICAL to
// the frozen demo module (the diff is verified by the script's roundtrip).
// The fixtures are inert [function,total] definitions; the only machine
// command is the certificate printer, which no proof invokes.  The T11-M3
// krun transcript is executed over THIS module (LLVM, the total evaluator
// inside M1 — no krypto hook needed), against the SAME anchor and the SAME
// program as the frozen T11 — the corrected diagnostic behavior is the M1
// machine's.
// =============================================================================

// =============================================================================
// SRW3 Phase 1J — K demonstration suite (srw3closure-j-demo.k)
//
// The honest evidence fragments (the oracle -> lending chain, the authority
// certificates, the security contexts) follow the FROZEN Phase 1G/R3
// demonstration discipline (same accounts 4097/4098/4099, same keys, same
// canonical values).  THE DERIVED DISCIPLINE is new in 1J: the trace, the
// effective delta, the post-state, and every identity digest are DEFINED AS
// THE SAME EXPRESSIONS the machine's fragment interpreter computes, so the
// correspondence equalities (J-EVIDENCE-STATE-CORRESPONDENCE) are syntactic
// identities on the Haskell backend and CONCRETE byte equalities on the LLVM
// backend (real Keccak-256 via the krypto shim).
//
// THE FIXTURE CATALOG (a 3-APPLICATION HYPEREDGE COUNTERMODEL, handoff §5.3):
//   apps:       4097 "oracle" / 4098 "lending" / 4099 "vault"
//   resources:  k1 = 4097.slot0 (price)   owner 4097
//               k2 = 4098.slot0 (debt)    owner 4098
//               k3 = 4099.slot0 (reserve) owner 4099
//               k4 = 4098.slot1 (param)   owner 4098
//   hyperedges: he1 = {k1, k2, k3}  — THE 3-APP SOLVENCY HYPEREDGE
//               he2 = {k2, k4}      — a 2-app pairwise edge
//   locals:     l1: 0 <= k1 <= 1000;  l2: 0 <= k2 <= 500
//               l3: 0 <= k3 <= 500;   l4: 0 <= k4 <= 100
//   hyper invariants: h1: k2 + k3 <= 600 (the solvency binding, over he1)
//                     h2: k2 + k4 <= 550 (over he2)
//   globals:    g1: k1 + k2 + k3 <= 1100
//
// THE UNSAFE COMPOSITION (J-UNSAFE-COMPOSITION-COUNTERMODEL): write k2:=400
// and k3:=300.  EVERY LOCAL check passes (400<=500, 300<=500), the pairwise
// edge invariant passes (h2: 400+100=500<=550 — with k4 at its post value),
// but the 3-APP HYPEREDGE INVARIANT FAILS (h1: 400+300=700 > 600).  With
// he1 present the commit REJECTS; with he1 omitted the catalog bytes no
// longer hash to the configured graph digest, so the pin REFUSES
// (J-REJECTS-MISSING-HYPEREDGE — both directions of handoff §5.3).
//
// THE ANCHOR: <janchor> is filled by the krun configuration variable
// $SRW3JANCHOR (the authenticated external protocol input — the R3
// discipline).  The demo scripts pass -cSRW3JANCHOR="Ch(<hex>)" with the
// REAL Keccak root of XCfgJ computed by the Python mirror (cross-layer
// agreement: the K init check evaluates ProtoRootR3(XCfgJ) with the real
// keccak shim and must equal the Python-computed anchor byte-for-byte).
// =============================================================================

requires "srw3closure-j-m3.k"

module SRW3CLOSURE-J-M3-DEMO
  imports SRW3CLOSURE-J-M3

  // ---- shared verification-context constants (verbatim 1G-demo discipline) --
  syntax Map ::= LinKV1D ( Int , Int , Int ) [function, total]
  rule LinKV1D(A:Int, S:Int, V:Int) => A |-> (S |-> V)

  syntax Map ::= "XReg" [function, total]
  rule XReg => 5 |-> true  6 |-> true
  syntax Set ::= "XAuth" [function, total]
  rule XAuth => SetItem(LinAddrOf(LinDemoKey1)) SetItem(LinAddrOf(LinDemoKey2))
  syntax Bytes ::= "XCaller" [function, total]
  rule XCaller => LinAddrOf(LinDemoKey1)

  // ---- authority-side protocol constants (honest fragment values) -----------
  syntax Bytes ::= "XChain" [function, total]
  rule XChain => Int2Bytes(4, 1, BE)
  syntax Bytes ::= "XGuestD" [function, total]
  rule XGuestD => LinH(Int2Bytes(1, 145, BE) +Bytes I2B4(7))
  syntax Bytes ::= "XProofCfgD" [function, total]
  rule XProofCfgD => ExecConfigDigest(ExecSchedCANCUN(), 1)
  syntax Bytes ::= "XClientCfgD" [function, total]
  rule XClientCfgD => ExecConfigDigest(ExecSchedCANCUN(), 1)
  syntax Bytes ::= "XExecClientD" [function, total]
  rule XExecClientD => AuthzExecClientId(XChain, ExecConfigDigest(ExecSchedCANCUN(), 1))
  syntax Bytes ::= "XFork" [function, total]
  rule XFork => LinHex("4631")

  // =============================================================================
  // §1. THE FIXTURE CATALOG — contents, not digests
  // =============================================================================

  syntax Int ::= "JRK1" [function, total]   // 4097.slot0 (price)
  rule JRK1 => A2Key(4097, 0)
  syntax Int ::= "JRK2" [function, total]   // 4098.slot0 (debt)
  rule JRK2 => A2Key(4098, 0)
  syntax Int ::= "JRK3" [function, total]   // 4099.slot0 (reserve)
  rule JRK3 => A2Key(4099, 0)
  syntax Int ::= "JRK4" [function, total]   // 4098.slot1 (param)
  rule JRK4 => A2Key(4098, 1)

  syntax JCatalog ::= "XCatJ" [function, total]
  rule XCatJ
    => jCatalog( 1
               , ListItem(jApp(4097, LinHex("6f7261636c65")))     // "oracle"
                 ListItem(jApp(4098, LinHex("6c656e64696e67")))   // "lending"
                 ListItem(jApp(4099, LinHex("7661756c74")))       // "vault"
               , ListItem(jRes(JRK1, 4097)) ListItem(jRes(JRK2, 4098))
                 ListItem(jRes(JRK3, 4099)) ListItem(jRes(JRK4, 4098))
               , ListItem(jHyper(1, ListItem(JRK1) ListItem(JRK2) ListItem(JRK3)))
                 ListItem(jHyper(2, ListItem(JRK2) ListItem(JRK4)))
               , ListItem(jInvLocal(1, JRK1, 0, 1000))
                 ListItem(jInvLocal(2, JRK2, 0, 500))
                 ListItem(jInvLocal(3, JRK3, 0, 500))
                 ListItem(jInvLocal(4, JRK4, 0, 100))
               , ListItem(jInvSum(11, 1, ListItem(JRK2) ListItem(JRK3), 600))
                 ListItem(jInvSum(12, 2, ListItem(JRK2) ListItem(JRK4), 550))
               , ListItem(jInvSum(21, 0,
                    ListItem(JRK1) ListItem(JRK2) ListItem(JRK3), 1100)) )

  // THE MISSING-HYPEREDGE CATALOG: he1 (the 3-app solvency hyperedge)
  // omitted — the graph digest no longer matches the configured one.
  syntax JCatalog ::= "XCatJNoHe1" [function, total]
  rule XCatJNoHe1
    => jCatalog( 1
               , ListItem(jApp(4097, LinHex("6f7261636c65")))
                 ListItem(jApp(4098, LinHex("6c656e64696e67")))
                 ListItem(jApp(4099, LinHex("7661756c74")))
               , ListItem(jRes(JRK1, 4097)) ListItem(jRes(JRK2, 4098))
                 ListItem(jRes(JRK3, 4099)) ListItem(jRes(JRK4, 4098))
               , ListItem(jHyper(2, ListItem(JRK2) ListItem(JRK4)))
               , ListItem(jInvLocal(1, JRK1, 0, 1000))
                 ListItem(jInvLocal(2, JRK2, 0, 500))
                 ListItem(jInvLocal(3, JRK3, 0, 500))
                 ListItem(jInvLocal(4, JRK4, 0, 100))
               , ListItem(jInvSum(12, 2, ListItem(JRK2) ListItem(JRK4), 550))
               , ListItem(jInvSum(21, 0,
                    ListItem(JRK1) ListItem(JRK2) ListItem(JRK3), 1100)) )

  // a MALFORMED catalog: resource k3 owned by the UNREGISTERED app 4100
  syntax JCatalog ::= "XCatJBadOwner" [function, total]
  rule XCatJBadOwner
    => jCatalog( 1
               , ListItem(jApp(4097, LinHex("6f7261636c65")))
                 ListItem(jApp(4098, LinHex("6c656e64696e67")))
                 ListItem(jApp(4099, LinHex("7661756c74")))
               , ListItem(jRes(JRK1, 4097)) ListItem(jRes(JRK2, 4098))
                 ListItem(jRes(JRK3, 4100)) ListItem(jRes(JRK4, 4098))
               , ListItem(jHyper(1, ListItem(JRK1) ListItem(JRK2) ListItem(JRK3)))
                 ListItem(jHyper(2, ListItem(JRK2) ListItem(JRK4)))
               , ListItem(jInvLocal(1, JRK1, 0, 1000))
                 ListItem(jInvLocal(2, JRK2, 0, 500))
                 ListItem(jInvLocal(3, JRK3, 0, 500))
                 ListItem(jInvLocal(4, JRK4, 0, 100))
               , ListItem(jInvSum(11, 1, ListItem(JRK2) ListItem(JRK3), 600))
                 ListItem(jInvSum(12, 2, ListItem(JRK2) ListItem(JRK4), 550))
               , ListItem(jInvSum(21, 0,
                    ListItem(JRK1) ListItem(JRK2) ListItem(JRK3), 1100)) )

  // a MALFORMED catalog: a DUPLICATE resource key (k2 twice)
  syntax JCatalog ::= "XCatJDupRes" [function, total]
  rule XCatJDupRes
    => jCatalog( 1
               , ListItem(jApp(4097, LinHex("6f7261636c65")))
                 ListItem(jApp(4098, LinHex("6c656e64696e67")))
                 ListItem(jApp(4099, LinHex("7661756c74")))
               , ListItem(jRes(JRK1, 4097)) ListItem(jRes(JRK2, 4098))
                 ListItem(jRes(JRK2, 4098)) ListItem(jRes(JRK3, 4099))
                 ListItem(jRes(JRK4, 4098))
               , ListItem(jHyper(1, ListItem(JRK1) ListItem(JRK2) ListItem(JRK3)))
                 ListItem(jHyper(2, ListItem(JRK2) ListItem(JRK4)))
               , ListItem(jInvLocal(1, JRK1, 0, 1000))
                 ListItem(jInvLocal(2, JRK2, 0, 500))
                 ListItem(jInvLocal(3, JRK3, 0, 500))
                 ListItem(jInvLocal(4, JRK4, 0, 100))
               , ListItem(jInvSum(11, 1, ListItem(JRK2) ListItem(JRK3), 600))
                 ListItem(jInvSum(12, 2, ListItem(JRK2) ListItem(JRK4), 550))
               , ListItem(jInvSum(21, 0,
                    ListItem(JRK1) ListItem(JRK2) ListItem(JRK3), 1100)) )

  // =============================================================================
  // §2. THE PINNED CONFIGURATION — the 13 R3 fields with the catalog
  //     sub-digests as fields 3/4/5 (the catalog is authenticated by the SAME
  //     R3 root anchor; J-CATALOG-ROOT-BINDING)
  // =============================================================================

  syntax ProtoCfgR3 ::= "XCfgJ" [function, total]
  rule XCfgJ
    => protoCfgR3( XChain, 1, JPolicyRootJ(XCatJ), JAppSetRootJ(XCatJ)
                 , JGraphRootJ(XCatJ), XClientCfgD, XExecClientD, XFork
                 , ExecSchedCANCUN(), 1, 1, XGuestD, XProofCfgD )

  // the config for the MISSING-HYPEREDGE catalog (a DIFFERENT root — never
  // authorized by the demo anchor)
  syntax ProtoCfgR3 ::= "XCfgJNoHe1" [function, total]
  rule XCfgJNoHe1
    => protoCfgR3( XChain, 1, JPolicyRootJ(XCatJNoHe1), JAppSetRootJ(XCatJNoHe1)
                 , JGraphRootJ(XCatJNoHe1), XClientCfgD, XExecClientD, XFork
                 , ExecSchedCANCUN(), 1, 1, XGuestD, XProofCfgD )

  // =============================================================================
  // §3. THE HONEST FRAGMENT PROGRAMS + DERIVED EXECUTIONS
  //     (block 0: oracle price update; block 1: lending borrow)
  // =============================================================================

  syntax List ::= "XProg0" [function, total]
  rule XProg0 => ListItem(jWrite(4097, 0, 100))
  syntax List ::= "XProg1" [function, total]
  rule XProg1 => ListItem(jWrite(4098, 0, 100)) ListItem(jWrite(4098, 1, 100))

  // THE UNSAFE COMPOSITION (locals pass, pairwise passes, 3-app fails):
  // k2 := 400 and k3 := 300 — over the post-block-1 state.
  syntax List ::= "XProgUnsafe" [function, total]
  rule XProgUnsafe
    => ListItem(jWrite(4098, 0, 400)) ListItem(jWrite(4099, 0, 300))
  // a GLOBAL failure: k1 := 900, k2 := 200 — every local and hyperedge
  // check passes, the global invariant fails (900+200 = 1100 <= 1100 ok;
  // make it 950+200=1150 > 1100 to fail)
  syntax List ::= "XProgGlobal" [function, total]
  rule XProgGlobal
    => ListItem(jWrite(4097, 0, 950)) ListItem(jWrite(4098, 0, 200))

  // the DERIVED executions (the same expressions the machine evaluates)
  syntax Map ::= "XPre0" [function, total]
  rule XPre0 => .Map
  syntax Map ::= "XEff0D" [function, total]
  rule XEff0D => jExecOkEffOf(ExecFragmentJ(XPre0, XProg0))
  syntax Map ::= "XPost0D" [function, total]
  rule XPost0D => jExecOkPostOf(ExecFragmentJ(XPre0, XProg0))
  syntax List ::= "XTrace0D" [function, total]
  rule XTrace0D => jExecOkTraceOf(ExecFragmentJ(XPre0, XProg0))

  syntax Map ::= "XPre1" [function, total]
  rule XPre1 => XPost0D
  syntax Map ::= "XEff1D" [function, total]
  rule XEff1D => jExecOkEffOf(ExecFragmentJ(XPre1, XProg1))
  syntax Map ::= "XPost1D" [function, total]
  rule XPost1D => jExecOkPostOf(ExecFragmentJ(XPre1, XProg1))
  syntax List ::= "XTrace1D" [function, total]
  rule XTrace1D => jExecOkTraceOf(ExecFragmentJ(XPre1, XProg1))

  // the unsafe composition derives from the post-block-1 state
  syntax Map ::= "XEffUD" [function, total]
  rule XEffUD => jExecOkEffOf(ExecFragmentJ(XPost1D, XProgUnsafe))
  syntax Map ::= "XPostUD" [function, total]
  rule XPostUD => jExecOkPostOf(ExecFragmentJ(XPost1D, XProgUnsafe))
  syntax List ::= "XTraceUD" [function, total]
  rule XTraceUD => jExecOkTraceOf(ExecFragmentJ(XPost1D, XProgUnsafe))

  // ---- the frozen 1F/1G evidence records BUILT FROM THE DERIVED ARTIFACTS ---
  // (the records' Q/E/P/trace ARE the derived maps — the correspondence is
  //  structural; J-TRACE-ORIGIN / J-EVIDENCE-STATE-CORRESPONDENCE)
  syntax Bytes ::= "XPld0J" [function, total]
  rule XPld0J => JProgBytesJ(XProg0)
  syntax Bytes ::= "XPld1J" [function, total]
  rule XPld1J => JProgBytesJ(XProg1)

  syntax LinRecF ::= "XR0" [function, total]
  rule XR0 => ExecBuildRecF(0, LinRoot, XPre0, XEff0D, XPost0D, LinDemoKey1, 5,
                            XTrace0D, XPld0J, ExecSchedCANCUN(), 1, XCaller, 0,
                            LinRoot)
  syntax Bytes ::= "XSR0" [function, total]
  rule XSR0 => linStateRootOf(linRecFBase(XR0))
  syntax ExecCtx ::= "XCtx0" [function, total]
  rule XCtx0
    => execCtx( authCtx( linCtxP(XPre0, XEff0D, XPost0D, XReg, XAuth), XSR0 )
              , LinRoot, XPld0J, ExecSchedCANCUN(), 1, XCaller, 0
              , XTrace0D
              , execWit( 1, LinRoot
                       , ExecExecId( LinRoot, ExecPayloadDigest(XPld0J)
                                   , ExecConfigDigest(ExecSchedCANCUN(), 1)
                                   , ExecEnvDigest(XCaller, 0) )
                       , ExecPayloadDigest(XPld0J)
                       , LinH(LinCanonKV(XEff0D))
                       , ExecTraceDigest(XTrace0D)
                       , XSR0
                       , ExecConfigDigest(ExecSchedCANCUN(), 1) ) )

  syntax LinRecF ::= "XR1" [function, total]
  rule XR1 => ExecBuildRecF(1, ExecChildF( linRecFBase(XR0), linExecIdOf(XR0)
                                         , linEffTraceDOf(XR0)
                                         , linExecWDOf(XR0)
                                         , linExecCfgDOf(XR0) ),
                            XPre1, XEff1D, XPost1D, LinDemoKey1, 5,
                            XTrace1D, XPld1J, ExecSchedCANCUN(), 1, XCaller, 0,
                            XSR0)
  syntax Bytes ::= "XSR1" [function, total]
  rule XSR1 => linStateRootOf(linRecFBase(XR1))
  syntax ExecCtx ::= "XCtx1" [function, total]
  rule XCtx1
    => execCtx( authCtx( linCtxP(XPre1, XEff1D, XPost1D, XReg, XAuth), XSR1 )
              , XSR0, XPld1J, ExecSchedCANCUN(), 1, XCaller, 0
              , XTrace1D
              , execWit( 1, XSR0
                       , ExecExecId( XSR0, ExecPayloadDigest(XPld1J)
                                   , ExecConfigDigest(ExecSchedCANCUN(), 1)
                                   , ExecEnvDigest(XCaller, 0) )
                       , ExecPayloadDigest(XPld1J)
                       , LinH(LinCanonKV(XEff1D))
                       , ExecTraceDigest(XTrace1D)
                       , XSR1
                       , ExecConfigDigest(ExecSchedCANCUN(), 1) ) )

  // ---- authority objects (verbatim 1G-demo discipline) -----------------------
  syntax AuthzCert ::= "XCert0" [function, total]
  rule XCert0
    => azCert( ExecPayloadDigest(XPld0J), LinRoot, linExecIdOf(XR0), XSR0
             , linEffTraceDOf(XR0), 1
             , azSrc(domConsensus, AuthzConsensusId(XChain), 0)
             , .List, 1, .Bytes )
  syntax AuthzCert ::= "XCert1" [function, total]
  rule XCert1
    => azCert( ExecPayloadDigest(XPld1J), XSR0, linExecIdOf(XR1), XSR1
             , linEffTraceDOf(XR1), 1
             , azSrc(domConsensus, AuthzConsensusId(XChain), 0)
             , .List, 1, .Bytes )
  syntax LinRecG ::= "XRG0" [function, total]
  rule XRG0 => linRecG(XR0, AzCertId(XCert0), 1)
  syntax LinRecG ::= "XRG1" [function, total]
  rule XRG1 => linRecG(XR1, AzCertId(XCert1), 1)

  // ---- the J candidate blocks — DERIVED from the executions ------------------
  syntax JBlockJ ::= "XB0" [function, total]
  rule XB0
    => jBlockJ( ProtoRootR3(XCfgJ)                 // parent commitment
              , JPayloadDigestJ(XProg0)            // payload digest
              , LinRoot                            // parent root (the frozen
                                                   // 1F exec-context identity)
              , StateRootJ(XPost0D)                // post J state root
              , ExecTraceDigest(XTrace0D)          // ordered trace digest
              , JFootprintDigestJ(XTrace0D)        // footprint digest
              , AzCertId(XCert0)                   // evidence identity
              , JCatalogRootJ(XCatJ)               // catalog root
              , ProtoRootR3(XCfgJ)                 // config root
              , XExecClientD                       // execution source
              , 1                                  // decision (valid)
              , 0 )                                // slot
  syntax JBlockJ ::= "XB1" [function, total]
  rule XB1
    => jBlockJ( JBlockCommitJ(XB0, XCfgJ)
              , JPayloadDigestJ(XProg1)
              , XSR0                               // parent root (1F identity)
              , StateRootJ(XPost1D)
              , ExecTraceDigest(XTrace1D)
              , JFootprintDigestJ(XTrace1D)
              , AzCertId(XCert1)
              , JCatalogRootJ(XCatJ)
              , ProtoRootR3(XCfgJ)
              , XExecClientD
              , 1
              , 1 )
  // THE UNSAFE candidate (slot 2; h1 would fail)
  syntax JBlockJ ::= "XBUnsafe" [function, total]
  rule XBUnsafe
    => jBlockJ( JBlockCommitJ(XB1, XCfgJ)
              , JPayloadDigestJ(XProgUnsafe)
              , XSR1                               // parent root (1F identity)
              , StateRootJ(XPostUD)
              , ExecTraceDigest(XTraceUD)
              , JFootprintDigestJ(XTraceUD)
              , AzCertId(XCertU)
              , JCatalogRootJ(XCatJ)
              , ProtoRootR3(XCfgJ)
              , XExecClientD
              , 1
              , 2 )
  // the unsafe run's record/cert (slot 2; threads onto R1)
  syntax LinRecF ::= "XRU" [function, total]
  rule XRU => ExecBuildRecF(2, ExecChildF( linRecFBase(XR1), linExecIdOf(XR1)
                                         , linEffTraceDOf(XR1)
                                         , linExecWDOf(XR1)
                                         , linExecCfgDOf(XR1) ),
                            XPost1D, XEffUD, XPostUD, LinDemoKey1, 5,
                            XTraceUD, JProgBytesJ(XProgUnsafe),
                            ExecSchedCANCUN(), 1, XCaller, 0, XSR1)
  syntax Bytes ::= "XSRU" [function, total]
  rule XSRU => linStateRootOf(linRecFBase(XRU))
  syntax ExecCtx ::= "XCtxU" [function, total]
  rule XCtxU
    => execCtx( authCtx( linCtxP(XPost1D, XEffUD, XPostUD, XReg, XAuth), XSRU )
              , XSR1, JProgBytesJ(XProgUnsafe), ExecSchedCANCUN(), 1, XCaller, 0
              , XTraceUD
              , execWit( 1, XSR1
                       , ExecExecId( XSR1, ExecPayloadDigest(JProgBytesJ(XProgUnsafe))
                                   , ExecConfigDigest(ExecSchedCANCUN(), 1)
                                   , ExecEnvDigest(XCaller, 0) )
                       , ExecPayloadDigest(JProgBytesJ(XProgUnsafe))
                       , LinH(LinCanonKV(XEffUD))
                       , ExecTraceDigest(XTraceUD)
                       , XSRU
                       , ExecConfigDigest(ExecSchedCANCUN(), 1) ) )
  syntax AuthzCert ::= "XCertU" [function, total]
  rule XCertU
    => azCert( ExecPayloadDigest(JProgBytesJ(XProgUnsafe)), XSR1
             , linExecIdOf(XRU), XSRU
             , linEffTraceDOf(XRU), 1
             , azSrc(domConsensus, AuthzConsensusId(XChain), 0)
             , .List, 1, .Bytes )
  syntax LinRecG ::= "XRGU" [function, total]
  rule XRGU => linRecG(XRU, AzCertId(XCertU), 1)

  // ---- the global-attack derived artifacts (J-A14/A15 class) ---------------
  syntax List ::= "XProgG" [function, total]
  rule XProgG => ListItem(jWrite(4097, 0, 950)) ListItem(jWrite(4098, 0, 200))
  syntax Map ::= "XEffG" [function, total]
  rule XEffG => jExecOkEffOf(ExecFragmentJ(XPost1D, XProgG))
  syntax Map ::= "XPostG" [function, total]
  rule XPostG => jExecOkPostOf(ExecFragmentJ(XPost1D, XProgG))
  syntax List ::= "XTraceG" [function, total]
  rule XTraceG => jExecOkTraceOf(ExecFragmentJ(XPost1D, XProgG))

  // ---- the GLOBAL-ATTACK run's record/cert (threads onto R1; J-A14/A15) -----
  syntax LinRecF ::= "XRGlobF" [function, total]
  rule XRGlobF
    => ExecBuildRecF(2, ExecChildF( linRecFBase(XR1), linExecIdOf(XR1)
                                  , linEffTraceDOf(XR1), linExecWDOf(XR1)
                                  , linExecCfgDOf(XR1) ),
                     XPost1D, XEffG, XPostG, LinDemoKey1, 5,
                     XTraceG, JProgBytesJ(XProgGlobal),
                     ExecSchedCANCUN(), 1, XCaller, 0, XSR1)
  syntax Bytes ::= "XSRGlob" [function, total]
  rule XSRGlob => linStateRootOf(linRecFBase(XRGlobF))
  syntax ExecCtx ::= "XCtxG" [function, total]
  rule XCtxG
    => execCtx( authCtx( linCtxP(XPost1D, XEffG, XPostG, XReg, XAuth), XSRGlob )
              , XSR1, JProgBytesJ(XProgGlobal), ExecSchedCANCUN(), 1, XCaller, 0
              , XTraceG
              , execWit( 1, XSR1
                       , ExecExecId( XSR1
                                   , ExecPayloadDigest(JProgBytesJ(XProgGlobal))
                                   , ExecConfigDigest(ExecSchedCANCUN(), 1)
                                   , ExecEnvDigest(XCaller, 0) )
                       , ExecPayloadDigest(JProgBytesJ(XProgGlobal))
                       , LinH(LinCanonKV(XEffG))
                       , ExecTraceDigest(XTraceG)
                       , XSRGlob
                       , ExecConfigDigest(ExecSchedCANCUN(), 1) ) )
  syntax AuthzCert ::= "XCertG" [function, total]
  rule XCertG
    => azCert( ExecPayloadDigest(JProgBytesJ(XProgGlobal)), XSR1
             , linExecIdOf(XRGlobF), XSRGlob
             , linEffTraceDOf(XRGlobF), 1
             , azSrc(domConsensus, AuthzConsensusId(XChain), 0)
             , .List, 1, .Bytes )
  syntax LinRecG ::= "XRGG" [function, total]
  rule XRGG => linRecG(XRGlobF, AzCertId(XCertG), 1)
  syntax JBlockJ ::= "XBG" [function, total]
  rule XBG
    => jBlockJ( JBlockCommitJ(XB1, XCfgJ)
              , JPayloadDigestJ(XProgGlobal)
              , XSR1
              , StateRootJ(XPostG)
              , ExecTraceDigest(XTraceG)
              , JFootprintDigestJ(XTraceG)
              , AzCertId(XCertG)
              , JCatalogRootJ(XCatJ)
              , ProtoRootR3(XCfgJ)
              , XExecClientD
              , 1
              , 2 )

  // =============================================================================
  // §4. Cross-layer byte certificate helpers (the 1G-demo discipline, verbatim)
  // =============================================================================

  syntax String ::= Bool2StringX ( Bool ) [function, total]
  rule Bool2StringX(true)  => "true"
  rule Bool2StringX(false) => "false"

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

  // =============================================================================
  // §5. THE J CROSS-LAYER BYTE CERTIFICATE — the K half of the conformance
  //     vectors (catalog canon + sub-roots + state roots + trace/footprint
  //     digests + evidence identity + the computed verdicts)
  // =============================================================================
  syntax PCmdJI ::= "xCertJ"
  rule <k> xCertJ
        => "catjcanonlen="      +String Int2String(lengthBytes(JCatalogCanonJ(XCatJ)))
           +String ",catjcanon="    +String Bytes2StringX(JCatalogCanonJ(XCatJ))
           +String ",catjroot="     +String Bytes2StringX(JCatalogRootJ(XCatJ))
           +String ",jappsetroot="  +String Bytes2StringX(JAppSetRootJ(XCatJ))
           +String ",jgraphroot="   +String Bytes2StringX(JGraphRootJ(XCatJ))
           +String "," +String "jpolicyroot=" +String Bytes2StringX(JPolicyRootJ(XCatJ))
           +String ",cfgjcanonlen=" +String Int2String(lengthBytes(ProtoCfgCanonR3(XCfgJ)))
           +String ",cfgjroot="     +String Bytes2StringX(ProtoRootR3(XCfgJ))
           +String ",stateroot0="   +String Bytes2StringX(StateRootJ(XPre0))
           +String ",stateroot0p="  +String Bytes2StringX(StateRootJ(XPost0D))
           +String ",tracedigest0=" +String Bytes2StringX(ExecTraceDigest(XTrace0D))
           +String ",footdigest0="  +String Bytes2StringX(JFootprintDigestJ(XTrace0D))
           +String ",payloaddigest0=" +String Bytes2StringX(JPayloadDigestJ(XProg0))
           +String ",policyctx0="   +String Bytes2StringX(
                 JPolicyCtxDigestJ(ProtoRootR3(XCfgJ), JCatalogRootJ(XCatJ), 1))
           +String ",evidenceid0="  +String Bytes2StringX( EvidenceIDJ(
                 ProtoRootR3(XCfgJ), JCatalogRootJ(XCatJ), qcrChainIdOf(XCfgJ),
                 qcrForkOf(XCfgJ), StateRootJ(XPre0), JPayloadDigestJ(XProg0),
                 XExecClientD, StateRootJ(XPost0D), ExecTraceDigest(XTrace0D),
                 JFootprintDigestJ(XTrace0D),
                 JPolicyCtxDigestJ(ProtoRootR3(XCfgJ), JCatalogRootJ(XCatJ), 1)) )
           +String ",blockcommit0=" +String Bytes2StringX(JBlockCommitJ(XB0, XCfgJ))
           +String ",certid0="      +String Bytes2StringX(AzCertId(XCert0))
           +String ",recchild0="    +String Bytes2StringX(JRecChildF(XRG0))
           +String ",verdict0="     +String VerifyLineageG(XRG0,
                    azCtx(XCtx0, ProtoAuthorizedSecCtxR3(XCfgJ, LinRoot),
                          XCert0, qcrAuthPTOf(XCfgJ), qcrAuthGuestDOf(XCfgJ),
                          qcrAuthCfgDOf(XCfgJ)), 0, LinRoot)
           +String ",verdict1="     +String VerifyLineageG(XRG1,
                    azCtx(XCtx1, ProtoAuthorizedSecCtxR3(XCfgJ, XSR0),
                          XCert1, qcrAuthPTOf(XCfgJ), qcrAuthGuestDOf(XCfgJ),
                          qcrAuthCfgDOf(XCfgJ)), 1, JRecChildF(XRG0))
           +String ",safe0="        +String Bool2StringX(SafeJ(XCatJ, XPost0D))
           +String ",safeunsafe="   +String Bool2StringX(SafeJ(XCatJ, XPostUD))
           +String ",closure0="     +String Bool2StringX(isJClosureOk(
                 AffectedClosureJ(JFootprintKeysOf(XTrace0D), jcHypersOf(XCatJ),
                                  JClosureFuelJ)))
           +String ",footkeys0="    +String Bytes2StringX(
                 JFootprintCanonJ(JFootprintKeysOf(XTrace0D)))
           +String ",graphrootnohe1=" +String Bytes2StringX(JGraphRootJ(XCatJNoHe1))
           +String ",stateroot1="   +String Bytes2StringX(StateRootJ(XPost1D))
           +String ",verdictu="     +String VerifyLineageG(XRGU,
                    azCtx(XCtxU, ProtoAuthorizedSecCtxR3(XCfgJ, XSR1),
                          XCertU, qcrAuthPTOf(XCfgJ), qcrAuthGuestDOf(XCfgJ),
                          qcrAuthCfgDOf(XCfgJ)), 2, JRecChildF(XRG1)) ... </k>

endmodule
