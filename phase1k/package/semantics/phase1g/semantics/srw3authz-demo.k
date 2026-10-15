// =============================================================================
// SRW3 Phase 1G — K demonstration suite (phase1g/semantics/srw3authz-demo.k)
//
// The AUTHORITY case study at the abstract layer: the Oracle → Lending →
// Liquidator lineage as a three-record chain of LinRecG with per-record
// AuthorityCertificates, the two authority modes (rel=1 consensus-authorized,
// rel=2 re-execution/Mode A, rel=3 proof-checked/Mode B), the countermodels
// CM-G1..G10, and the access-list (BAL) analysis. Accounts mirror KEVM:
//   4097 = Oracle, 4098 = Lending, 4099 = Liquidator.
//
// Expected verdict strings (partitioned programs; the concatenated suite
// exceeds the 3 GB sandbox as ONE term — 1F precedent):
//   xpos0 : valid-g                          (R0, rel=1)
//   xchain: pos1=valid-g;pos2=valid-g;pos3=valid-g
//           (R1 rel=1 threaded; R2 rel=2 Mode A; R0 rel=3 Mode B)
//   xcm1  : g1=invalid-authcircle;g2=invalid-authsrc;g3a=invalid-authlevel;
//           g3b=invalid-authcircle
//   xcm2  : g4=invalid-authbind;g5=invalid-authbind;g6=invalid-authsrc;
//           g7=invalid-authbind
//   xcm3  : g8=invalid-policy;g9=invalid-authsrc;g9b=invalid-authbind;
//           g10=invalid-authtype;g11=invalid-authrel
//   xbal  : bal1=true;bal2=false;bal3=balFootprint=true,balWrites=true,
//           effbind=invalid-effbind;bal4a=true;bal4b=true;bal4diff=true
//   xbytes: cross-layer byte certificate source (cert canon, certId, childG,
//           proofPub, consensus/exec/proof/policy identities)
// =============================================================================

requires "srw3authz.k"

module SRW3AUTHZ-DEMO
  imports SRW3AUTHZ

  configuration <srw3authz>
                  <k> $PGM </k>
                  <gresult> "" </gresult>
                </srw3authz>

  syntax AzPgm ::= "xpos0" | "xchain" | "xcm1a" | "xcm1b" | "xcm2" | "xcm3" | "xbal" | "xbytes"

  // ---- shared verification context constants --------------------------------
  syntax Map ::= LinKV1 ( Int , Int , Int ) [function, total]
  rule LinKV1(A:Int, S:Int, V:Int) => A |-> (S |-> V)

  syntax Map ::= "XReg" [function, total]
  rule XReg => 5 |-> true  6 |-> true
  syntax Set ::= "XAuth" [function, total]
  rule XAuth => SetItem(LinAddrOf(LinDemoKey1)) SetItem(LinAddrOf(LinDemoKey2))
  syntax Bytes ::= "XCaller" [function, total]
  rule XCaller => LinAddrOf(LinDemoKey1)

  syntax Bytes ::= "XPld0" [function, total]
  rule XPld0 => LinHex("4f5241434c4531")
  syntax Bytes ::= "XPld1" [function, total]
  rule XPld1 => LinHex("424f52524f5731")
  syntax Bytes ::= "XPld2" [function, total]
  rule XPld2 => LinHex("4c495155494441544531")

  // ---- authority-side protocol constants (honest fragment values) -----------
  syntax Bytes ::= "XChain" [function, total]
  rule XChain => Int2Bytes(4, 1, BE)
  syntax Bytes ::= "XAppSetD" [function, total]
  rule XAppSetD
    => LinH( Int2Bytes(1, 143, BE) +Bytes I2B4(4097) +Bytes I2B4(4098)
             +Bytes I2B4(4099) )
  syntax Bytes ::= "XGraphD" [function, total]
  rule XGraphD => LinH(Int2Bytes(1, 144, BE) +Bytes I2B4(3))
  syntax Bytes ::= "XGuestD" [function, total]
  rule XGuestD => LinH(Int2Bytes(1, 145, BE) +Bytes I2B4(7))
  syntax Bytes ::= "XProofCfgD" [function, total]
  rule XProofCfgD => ExecConfigDigest(ExecSchedCANCUN(), 1)

  // ---- R0: oracle update -----------------------------------------------------
  syntax Map ::= "XQ0" [function, total]
  rule XQ0 => LinKV1(4097, 0, 0)
  syntax Map ::= "XE0" [function, total]
  rule XE0 => LinKV1(4097, 0, 100)
  syntax Map ::= "XP0" [function, total]
  rule XP0 => LinKV1(4097, 0, 100)
  syntax List ::= "XT0" [function, total]
  rule XT0 => ListItem( exEvt(2, 4097, 0, 100) )
  syntax LinRecF ::= "XR0" [function, total]
  rule XR0 => ExecBuildRecF(0, LinRoot, XQ0, XE0, XP0, LinDemoKey1, 5,
                            XT0, XPld0, ExecSchedCANCUN(), 1, XCaller, 0, LinRoot)
  syntax Bytes ::= "XSR0" [function, total]
  rule XSR0 => linStateRootOf(linRecFBase(XR0))
  syntax Bytes ::= "XCF0" [function, total]
  rule XCF0 => ExecChildF( linRecFBase(XR0), linExecIdOf(XR0)
                         , linEffTraceDOf(XR0), linExecWDOf(XR0)
                         , linExecCfgDOf(XR0) )
  syntax ExecCtx ::= "XCtx0" [function, total]
  rule XCtx0
    => execCtx( authCtx( linCtxP(XQ0, XE0, XP0, XReg, XAuth), XSR0 )
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

  // ---- R1: lending borrow ----------------------------------------------------
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

  // ---- R2: liquidation ---------------------------------------------------------
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

  // ---- the stale-read case (1F neg8; reused for CM-G9b) ----------------------
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

  // ---- the cross-slot reorder (1F neg3x; reused for CM-G9 order blindness) ---
  syntax List ::= "XT2x" [function, total]
  rule XT2x => ListItem( exEvt(1, 4098, 0, 100) )
              ListItem( exEvt(1, 4098, 1, 100) )
              ListItem( exEvt(1, 4097, 0, 100) )
              ListItem( exEvt(2, 4098, 1, 50) )
              ListItem( exEvt(2, 4099, 0, 100) )
              ListItem( exEvt(2, 4098, 1, 0) )

  // =============================================================================
  // The authority objects
  // =============================================================================

  // SecurityContexts (the lineage head threads: LinRoot -> XCF0 -> XCF1)
  syntax SecCtx ::= "XSec0" [function, total]
  rule XSec0 => secCtx(1, XChain, XAppSetD, XGraphD, LinRoot)
  syntax SecCtx ::= "XSec1" [function, total]
  rule XSec1 => secCtx(1, XChain, XAppSetD, XGraphD, XCF0)
  syntax SecCtx ::= "XSec2" [function, total]
  rule XSec2 => secCtx(1, XChain, XAppSetD, XGraphD, XCF1)

  // XCert0: rel=1 consensus-authorized (the Engine-API-modeled path)
  syntax AuthzCert ::= "XCert0" [function, total]
  rule XCert0
    => azCert( ExecPayloadDigest(XPld0), LinRoot, linExecIdOf(XR0), XSR0
             , linEffTraceDOf(XR0), 1
             , azSrc(domConsensus, AuthzConsensusId(XChain), 0)
             , .List, 1, .Bytes )

  // XCert1: rel=1, threaded onto R0's authoritative root
  syntax AuthzCert ::= "XCert1" [function, total]
  rule XCert1
    => azCert( ExecPayloadDigest(XPld1), XSR0, linExecIdOf(XR1), XSR1
             , linEffTraceDOf(XR1), 1
             , azSrc(domConsensus, AuthzConsensusId(XChain), 0)
             , .List, 1, .Bytes )

  // XCert2: rel=2 re-execution-derived (Mode A); the chain carries the
  // consensus root that authorizes the client
  syntax AuthzCert ::= "XCert2" [function, total]
  rule XCert2
    => azCert( ExecPayloadDigest(XPld2), XSR1, linExecIdOf(XR2), XSR2
             , linEffTraceDOf(XR2), 2
             , azSrc( domExecution
                    , AuthzExecClientId(XChain, ExecConfigDigest(ExecSchedCANCUN(), 1))
                    , 1 )
             , ListItem( azStep(domConsensus, AuthzConsensusId(XChain), 0) )
             , 1, .Bytes )

  // XCert3: rel=3 proof-checked (Mode B) over R0; proofPub binds the FULL
  // public-input surface (payload, parent, chain, fork, child, policy,
  // appSet, graph, lineageHead)
  syntax AuthzCert ::= "XCert3" [function, total]
  rule XCert3
    => azCert( ExecPayloadDigest(XPld0), LinRoot, linExecIdOf(XR0), XSR0
             , linEffTraceDOf(XR0), 3
             , azSrc(domProof, AuthzProofSysId(1, XGuestD, XProofCfgD), 1)
             , ListItem( azStep(domConsensus, AuthzConsensusId(XChain), 0) )
             , 1
             , AzProofPub( ExecPayloadDigest(XPld0), LinRoot, XChain
                         , ExecSchedCANCUN(), 1, XSR0, 1
                         , XAppSetD, XGraphD, LinRoot ) )

  // G records (honest: azCertD = AzCertId(cert), policyV pinned)
  syntax LinRecG ::= "XRG0" [function, total]
  rule XRG0 => linRecG(XR0, AzCertId(XCert0), 1)
  syntax LinRecG ::= "XRG1" [function, total]
  rule XRG1 => linRecG(XR1, AzCertId(XCert1), 1)
  syntax LinRecG ::= "XRG2" [function, total]
  rule XRG2 => linRecG(XR2, AzCertId(XCert2), 1)
  syntax LinRecG ::= "XRG3" [function, total]
  rule XRG3 => linRecG(XR0, AzCertId(XCert3), 1)

  // G contexts
  syntax AzCtx ::= "XAzCtx0" [function, total]
  rule XAzCtx0 => azCtx(XCtx0, XSec0, XCert0, 0, .Bytes, .Bytes)
  syntax AzCtx ::= "XAzCtx1" [function, total]
  rule XAzCtx1 => azCtx(XCtx1, XSec1, XCert1, 0, .Bytes, .Bytes)
  syntax AzCtx ::= "XAzCtx2" [function, total]
  rule XAzCtx2 => azCtx(XCtx2, XSec2, XCert2, 0, .Bytes, .Bytes)
  syntax AzCtx ::= "XAzCtx3" [function, total]
  rule XAzCtx3 => azCtx(XCtx0, XSec0, XCert3, 1, XGuestD, XProofCfgD)

  // =============================================================================
  // Countermodels
  // =============================================================================

  // g1 (CM-G1): self-authorizing anchor — the chain's consensus step cites an
  // UNAUTHORIZED id (a guessed self-id; the honest consensus id is replaced).
  // Every chain step must carry an AUTHORIZED identity, so this fails at
  // authcircle.
  syntax AuthzCert ::= "XG1Cert" [function, total]
  rule XG1Cert
    => azCert( ExecPayloadDigest(XPld0), LinRoot, linExecIdOf(XR0), XSR0
             , linEffTraceDOf(XR0), 1
             , azSrc(domConsensus, AuthzConsensusId(XChain), 0)
             , ListItem( azStep(domConsensus, AzCertId(XCert1), 0) )
             , 1, .Bytes )
  syntax LinRecG ::= "XG1Rec" [function, total]
  rule XG1Rec => linRecG(XR0, AzCertId(XG1Cert), 1)
  syntax AzCtx ::= "XG1Ctx" [function, total]
  rule XG1Ctx => azCtx(XCtx0, XSec0, XG1Cert, 0, .Bytes, .Bytes)

  // g2 (CM-G2): the source id is a CERTIFICATE-derived id (XCert1's id) —
  // never a protocol identity; constructible (no fixpoint needed).
  syntax AuthzCert ::= "XG2Cert" [function, total]
  rule XG2Cert
    => azCert( ExecPayloadDigest(XPld0), LinRoot, linExecIdOf(XR0), XSR0
             , linEffTraceDOf(XR0), 1
             , azSrc(domConsensus, AzCertId(XCert1), 0)
             , .List, 1, .Bytes )
  syntax LinRecG ::= "XG2Rec" [function, total]
  rule XG2Rec => linRecG(XR0, AzCertId(XG2Cert), 1)
  syntax AzCtx ::= "XG2Ctx" [function, total]
  rule XG2Ctx => azCtx(XCtx0, XSec0, XG2Cert, 0, .Bytes, .Bytes)

  // g3a (CM-G3a): the client claims level 0
  syntax AuthzCert ::= "XG3aCert" [function, total]
  rule XG3aCert
    => azCert( ExecPayloadDigest(XPld2), XSR1, linExecIdOf(XR2), XSR2
             , linEffTraceDOf(XR2), 2
             , azSrc( domExecution
                    , AuthzExecClientId(XChain, ExecConfigDigest(ExecSchedCANCUN(), 1))
                    , 0 )
             , .List, 1, .Bytes )
  syntax LinRecG ::= "XG3aRec" [function, total]
  rule XG3aRec => linRecG(XR2, AzCertId(XG3aCert), 1)
  syntax AzCtx ::= "XG3aCtx" [function, total]
  rule XG3aCtx => azCtx(XCtx2, XSec2, XG3aCert, 0, .Bytes, .Bytes)

  // g3b (CM-G3b): client output treated as unquestionable — a client-sourced
  // rel=2 cert with NO consensus chain (empty chain at src level 1)
  syntax AuthzCert ::= "XG3bCert" [function, total]
  rule XG3bCert
    => azCert( ExecPayloadDigest(XPld2), XSR1, linExecIdOf(XR2), XSR2
             , linEffTraceDOf(XR2), 2
             , azSrc( domExecution
                    , AuthzExecClientId(XChain, ExecConfigDigest(ExecSchedCANCUN(), 1))
                    , 1 )
             , .List, 1, .Bytes )
  syntax LinRecG ::= "XG3bRec" [function, total]
  rule XG3bRec => linRecG(XR2, AzCertId(XG3bCert), 1)
  syntax AzCtx ::= "XG3bCtx" [function, total]
  rule XG3bCtx => azCtx(XCtx2, XSec2, XG3bCert, 0, .Bytes, .Bytes)

  // g4 (CM-G4): payload substitution — the cert binds XPld1's digest
  syntax AuthzCert ::= "XG4Cert" [function, total]
  rule XG4Cert
    => azCert( ExecPayloadDigest(XPld1), LinRoot, linExecIdOf(XR0), XSR0
             , linEffTraceDOf(XR0), 1
             , azSrc(domConsensus, AuthzConsensusId(XChain), 0)
             , .List, 1, .Bytes )
  syntax LinRecG ::= "XG4Rec" [function, total]
  rule XG4Rec => linRecG(XR0, AzCertId(XG4Cert), 1)
  syntax AzCtx ::= "XG4Ctx" [function, total]
  rule XG4Ctx => azCtx(XCtx0, XSec0, XG4Cert, 0, .Bytes, .Bytes)

  // g5 (CM-G5): parent-root substitution — the cert binds XSR1 as parent
  syntax AuthzCert ::= "XG5Cert" [function, total]
  rule XG5Cert
    => azCert( ExecPayloadDigest(XPld0), XSR1, linExecIdOf(XR0), XSR0
             , linEffTraceDOf(XR0), 1
             , azSrc(domConsensus, AuthzConsensusId(XChain), 0)
             , .List, 1, .Bytes )
  syntax LinRecG ::= "XG5Rec" [function, total]
  rule XG5Rec => linRecG(XR0, AzCertId(XG5Cert), 1)
  syntax AzCtx ::= "XG5Ctx" [function, total]
  rule XG5Ctx => azCtx(XCtx0, XSec0, XG5Cert, 0, .Bytes, .Bytes)

  // g6 (CM-G6): fork/config substitution — the source is the client
  // authorized under fork spec 2, evaluated under fork spec 1
  syntax AuthzCert ::= "XG6Cert" [function, total]
  rule XG6Cert
    => azCert( ExecPayloadDigest(XPld2), XSR1, linExecIdOf(XR2), XSR2
             , linEffTraceDOf(XR2), 2
             , azSrc( domExecution
                    , AuthzExecClientId(XChain, ExecConfigDigest(ExecSchedCANCUN(), 2))
                    , 1 )
             , ListItem( azStep(domConsensus, AuthzConsensusId(XChain), 0) )
             , 1, .Bytes )
  syntax LinRecG ::= "XG6Rec" [function, total]
  rule XG6Rec => linRecG(XR2, AzCertId(XG6Cert), 1)
  syntax AzCtx ::= "XG6Ctx" [function, total]
  rule XG6Ctx => azCtx(XCtx2, XSec2, XG6Cert, 0, .Bytes, .Bytes)

  // g7 (CM-G7): child-root substitution — the cert binds XSR1 as child
  syntax AuthzCert ::= "XG7Cert" [function, total]
  rule XG7Cert
    => azCert( ExecPayloadDigest(XPld0), LinRoot, linExecIdOf(XR0), XSR1
             , linEffTraceDOf(XR0), 1
             , azSrc(domConsensus, AuthzConsensusId(XChain), 0)
             , .List, 1, .Bytes )
  syntax LinRecG ::= "XG7Rec" [function, total]
  rule XG7Rec => linRecG(XR0, AzCertId(XG7Cert), 1)
  syntax AzCtx ::= "XG7Ctx" [function, total]
  rule XG7Ctx => azCtx(XCtx0, XSec0, XG7Cert, 0, .Bytes, .Bytes)

  // g8 (CM-G8): policy substitution — cert policyV=2 vs SecCtx policyV=1
  syntax AuthzCert ::= "XG8Cert" [function, total]
  rule XG8Cert
    => azCert( ExecPayloadDigest(XPld0), LinRoot, linExecIdOf(XR0), XSR0
             , linEffTraceDOf(XR0), 1
             , azSrc(domConsensus, AuthzConsensusId(XChain), 0)
             , .List, 2, .Bytes )
  syntax LinRecG ::= "XG8Rec" [function, total]
  rule XG8Rec => linRecG(XR0, AzCertId(XG8Cert), 1)
  syntax AzCtx ::= "XG8Ctx" [function, total]
  rule XG8Ctx => azCtx(XCtx0, XSec0, XG8Cert, 0, .Bytes, .Bytes)

  // g9 (CM-G10): proof-authority substitution — the source is the proof
  // system of TYPE 2 (unauthorized; the context pins type 1)
  syntax AuthzCert ::= "XG9Cert" [function, total]
  rule XG9Cert
    => azCert( ExecPayloadDigest(XPld0), LinRoot, linExecIdOf(XR0), XSR0
             , linEffTraceDOf(XR0), 3
             , azSrc(domProof, AuthzProofSysId(2, XGuestD, XProofCfgD), 1)
             , ListItem( azStep(domConsensus, AuthzConsensusId(XChain), 0) )
             , 1
             , AzProofPub( ExecPayloadDigest(XPld0), LinRoot, XChain
                         , ExecSchedCANCUN(), 1, XSR0, 1
                         , XAppSetD, XGraphD, LinRoot ) )
  syntax LinRecG ::= "XG9Rec" [function, total]
  rule XG9Rec => linRecG(XR0, AzCertId(XG9Cert), 1)
  syntax AzCtx ::= "XG9Ctx" [function, total]
  rule XG9Ctx => azCtx(XCtx0, XSec0, XG9Cert, 1, XGuestD, XProofCfgD)

  // g9b (CM-G10 variant): authorized proof source but the proofPub does not
  // recompute (empty) — invalid-authbind
  syntax AuthzCert ::= "XG9bCert" [function, total]
  rule XG9bCert
    => azCert( ExecPayloadDigest(XPld0), LinRoot, linExecIdOf(XR0), XSR0
             , linEffTraceDOf(XR0), 3
             , azSrc(domProof, AuthzProofSysId(1, XGuestD, XProofCfgD), 1)
             , ListItem( azStep(domConsensus, AuthzConsensusId(XChain), 0) )
             , 1, .Bytes )
  syntax LinRecG ::= "XG9bRec" [function, total]
  rule XG9bRec => linRecG(XR0, AzCertId(XG9bCert), 1)
  syntax AzCtx ::= "XG9bCtx" [function, total]
  rule XG9bCtx => azCtx(XCtx0, XSec0, XG9bCert, 1, XGuestD, XProofCfgD)

  // g10: unknown authority relation (rel=4)
  syntax AuthzCert ::= "XG10Cert" [function, total]
  rule XG10Cert
    => azCert( ExecPayloadDigest(XPld0), LinRoot, linExecIdOf(XR0), XSR0
             , linEffTraceDOf(XR0), 4
             , azSrc(domConsensus, AuthzConsensusId(XChain), 0)
             , .List, 1, .Bytes )
  syntax LinRecG ::= "XG10Rec" [function, total]
  rule XG10Rec => linRecG(XR0, AzCertId(XG10Cert), 1)
  syntax AzCtx ::= "XG10Ctx" [function, total]
  rule XG10Ctx => azCtx(XCtx0, XSec0, XG10Cert, 0, .Bytes, .Bytes)

  // g11: rel ↔ domain mismatch (rel=2 but the source claims consensus)
  syntax AuthzCert ::= "XG11Cert" [function, total]
  rule XG11Cert
    => azCert( ExecPayloadDigest(XPld2), XSR1, linExecIdOf(XR2), XSR2
             , linEffTraceDOf(XR2), 2
             , azSrc(domConsensus, AuthzConsensusId(XChain), 0)
             , .List, 1, .Bytes )
  syntax LinRecG ::= "XG11Rec" [function, total]
  rule XG11Rec => linRecG(XR2, AzCertId(XG11Cert), 1)
  syntax AzCtx ::= "XG11Ctx" [function, total]
  rule XG11Ctx => azCtx(XCtx2, XSec2, XG11Cert, 0, .Bytes, .Bytes)

  // =============================================================================
  // Access-list (BAL) cases (MODEL.md §12)
  // =============================================================================

  // bal1: the honest R0 trace's BAL — footprint and post-values bind
  syntax List ::= "XBAL1" [function, total]
  rule XBAL1 => ListItem( balEntry(4097, 0, true, 100) )

  // bal2: CM-G9a — the omitted location (empty BAL vs touched (4097,0))
  syntax List ::= "XBAL2" [function, total]
  rule XBAL2 => .List

  // bal3: CM-G9b — the stale-read attack's BAL: correct footprint, correct
  // post-execution values, and yet the ordered-trace evidence REJECTS
  syntax List ::= "XBAL3" [function, total]
  rule XBAL3 => ListItem( balEntry(4097, 0, true, 100) )
               ListItem( balEntry(4098, 0, true, 100) )
               ListItem( balEntry(4098, 1, true, 0) )
               ListItem( balEntry(4099, 0, true, 100) )

  // bal4: CM-G9 order blindness — XT2 and XT2x share the footprint and the
  // post-values; the trace digests DIFFER (the BAL cannot see order)

  // =============================================================================
  // The suite
  // =============================================================================

  syntax String ::= XGVerdict ( LinRecG , AzCtx , Int , Bytes ) [function, total]
  rule XGVerdict(RG:LinRecG, C:AzCtx, T:Int, H:Bytes)
    => VerifyLineageG(RG, C, T, H)

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
  rule XHexDigit(I:Int) => "?" requires I >Int 15 orBool I <Int 0

  rule <k> xpos0 => .K ... </k>
       <gresult> "" => XGVerdict(XRG0, XAzCtx0, 0, LinRoot) </gresult>

  rule <k> xchain => .K ... </k>
       <gresult> "" => "pos1=" +String XGVerdict(XRG1, XAzCtx1, 1, XCF0)
                    +String ";pos2=" +String XGVerdict(XRG2, XAzCtx2, 2, XCF1)
                    +String ";pos3=" +String XGVerdict(XRG3, XAzCtx3, 0, LinRoot)
                    +String ";certd0=" +String Bytes2StringX(AzCertId(XCert0))
                    +String ";childg0=" +String Bytes2StringX(AzChildG(XR0, AzCertId(XCert0), 1))
       </gresult>

  rule <k> xcm1a => .K ... </k>
       <gresult> "" => "g1="  +String XGVerdict(XG1Rec, XG1Ctx, 0, LinRoot)
                    +String ";g2="  +String XGVerdict(XG2Rec, XG2Ctx, 0, LinRoot)
       </gresult>

  rule <k> xcm1b => .K ... </k>
       <gresult> "" => "g3a=" +String XGVerdict(XG3aRec, XG3aCtx, 2, XCF1)
                    +String ";g3b=" +String XGVerdict(XG3bRec, XG3bCtx, 2, XCF1)
       </gresult>

  rule <k> xcm2 => .K ... </k>
       <gresult> "" => "g4="  +String XGVerdict(XG4Rec, XG4Ctx, 0, LinRoot)
                    +String ";g5="  +String XGVerdict(XG5Rec, XG5Ctx, 0, LinRoot)
                    +String ";g6="  +String XGVerdict(XG6Rec, XG6Ctx, 2, XCF1)
                    +String ";g7="  +String XGVerdict(XG7Rec, XG7Ctx, 0, LinRoot)
       </gresult>

  rule <k> xcm3 => .K ... </k>
       <gresult> "" => "g8="   +String XGVerdict(XG8Rec, XG8Ctx, 0, LinRoot)
                    +String ";g9="   +String XGVerdict(XG9Rec, XG9Ctx, 0, LinRoot)
                    +String ";g9b="  +String XGVerdict(XG9bRec, XG9bCtx, 0, LinRoot)
                    +String ";g10="  +String XGVerdict(XG10Rec, XG10Ctx, 0, LinRoot)
                    +String ";g11="  +String XGVerdict(XG11Rec, XG11Ctx, 2, XCF1)
       </gresult>

  rule <k> xbal => .K ... </k>
       <gresult> "" => "bal1=" +String Bool2StringX( BalFootprintOk(XBAL1, XT0)
                                             andBool BalWritesOk(XBAL1, XT0, XQ0) )
                    +String ";bal2=" +String Bool2StringX(BalFootprintOk(XBAL2, XT0))
                    +String ";bal3=balFootprint="
                    +String Bool2StringX(BalFootprintOk(XBAL3, XT2false))
                    +String ",balWrites="
                    +String Bool2StringX(BalWritesOk(XBAL3, XT2false, XQ2))
                    +String ",effbind=" +String XVerdictF8(XNeg8Rec, XNeg8Ctx)
                    +String ";bal4a=" +String Bool2StringX(BalFootprintOk(XBAL3, XT2))
                    +String ";bal4b=" +String Bool2StringX(BalFootprintOk(XBAL3, XT2x))
                    +String ";bal4diff=" +String Bool2StringX(
                          notBool BytesEq( ExecTraceDigest(XT2)
                                         , ExecTraceDigest(XT2x) ) )
       </gresult>

  // the 1F verdict of the stale-read case (computed over the F projection)
  syntax String ::= XVerdictF8 ( LinRecF , ExecCtx ) [function, total]
  rule XVerdictF8(RF:LinRecF, C:ExecCtx)
    => VerifyLineageF(RF, C, 2, XCF1)

  rule <k> xbytes => .K ... </k>
       <gresult> "" => "certbody0=" +String Bytes2StringX(AzCertBody(XCert0))
                    +String ",certid0=" +String Bytes2StringX(AzCertId(XCert0))
                    +String ",consensusid=" +String Bytes2StringX(AuthzConsensusId(XChain))
                    +String ",execclientid=" +String Bytes2StringX(
                          AuthzExecClientId(XChain, ExecConfigDigest(ExecSchedCANCUN(), 1)) )
                    +String ",proofsysid=" +String Bytes2StringX(
                          AuthzProofSysId(1, XGuestD, XProofCfgD) )
                    +String ",policyauthid=" +String Bytes2StringX(AuthzPolicyAuthId(1))
                    +String ",proofpub3=" +String Bytes2StringX(azProofPubOf(XCert3))
                    +String ",childg0=" +String Bytes2StringX(AzChildG(XR0, AzCertId(XCert0), 1))
                    +String ",canoncoreg0=" +String Bytes2StringX(AzCanonCoreG(XR0, AzCertId(XCert0), 1))
                    +String ",bal3canon=" +String Bytes2StringX(BalCanon(XBAL3))
       </gresult>

endmodule
