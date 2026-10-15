// =============================================================================
// SRW3 Phase 1I-R3 — K demonstration suite (srw3proto-r3-demo.k)
//
// The honest evidence fragments (the Oracle -> Lending chain, the authority
// certificates, the security contexts) are reproduced VERBATIM from the
// frozen Phase 1G demonstration suite (phase1g/semantics/srw3authz-demo.k —
// same accounts 4097/4098/4099, same keys, same canonical values; the same
// discipline the R2 demo module documents).  The R3 candidate blocks are
// DERIVED from the fragments by the GateInputMatchesBlockR3 discipline:
// every candidate field is the same expression the binding predicate
// computes, so the binding equalities are syntactic identities (resolvable
// on the Haskell backend, where the hash expressions remain unevaluated
// Keccak256raw applications; CONCRETE on the LLVM backend via the krypto
// shim — real Ethereum Keccak-256).
//
// THE R3 ANCHOR: <r3anchor> is filled by the krun configuration variable
// $SRW3R3ANCHOR (the authenticated external protocol input — handoff §4 B).
// The demo scripts pass -cSRW3R3ANCHOR="LinHex(...)" with the REAL Keccak
// root of XCfgR3 computed by the Python mirror (cross-layer agreement:
// the K init check evaluates ProtoRootR3(XCfgR3) with the real keccak shim
// and must equal the Python-computed anchor byte-for-byte).
//
// Programs (partitioned; see run_demos_r3.sh):
//   xhonest2 : init -> gate(0) -> accept(0) -> gate(1) -> accept(1)
//              the honest pipeline, two blocks under the SAME full config
//              root (handoff §7 two-block row; the hs accept is the
//              documented boundary — the concrete run is LLVM/Python)
//   xgateonly: init -> gate(0): the receipt is minted with the COMPUTED
//              verdict + the computed R3 root + the anchor; NO chain moves
//   xnoreceipt: accept with NO mint (missing evidence) -> clean reject
//   xreinit  : pInitR3 twice -> the re-initialization is refused
//   xrootmut : init with a SCHEDULE-MUTATED config (field 9) under the
//              authorized root of the honest config -> REFUSED (the
//              R2-alias class, now closed: the computed root differs)
//   xanchorx : init with the honest config on a machine whose anchor is a
//              DIFFERENT protocol root -> REFUSED
//   xcfgsub  : mint(0) then accept with config-version witness 2 -> reject
//   xslotskip: gate at slot 0 for a slot-1 candidate -> mint refuses;
//              accept then finds no receipt -> reject
//   xinj     : the R1 injection shape pGateEvalR3(..., "valid-g") — SEVEN
//              arguments — is ILL-FORMED in the R3 command language
//   xlegacy  : the legacy commands (pAccept / pGateEval / pAcceptR1 /
//              pInitR1 / pInitR2 / pGateEvalR2 / pAcceptR2) are ILL-FORMED
//              in the R3 command language
// =============================================================================

requires "srw3proto-r3.k"

module SRW3PROTO-R3-DEMO
  imports SRW3PROTO-R3

  // ---- shared verification-context constants (verbatim 1G-demo discipline) --
  syntax Map ::= LinKV1D ( Int , Int , Int ) [function, total]
  rule LinKV1D(A:Int, S:Int, V:Int) => A |-> (S |-> V)

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
  rule XQ0 => LinKV1D(4097, 0, 0)
  syntax Map ::= "XE0" [function, total]
  rule XE0 => LinKV1D(4097, 0, 100)
  syntax Map ::= "XP0" [function, total]
  rule XP0 => LinKV1D(4097, 0, 100)
  syntax List ::= "XT0" [function, total]
  rule XT0 => ListItem( exEvt(2, 4097, 0, 100) )
  syntax LinRecF ::= "XR0" [function, total]
  rule XR0 => ExecBuildRecF(0, LinRoot, XQ0, XE0, XP0, LinDemoKey1, 5,
                            XT0, XPld0, ExecSchedCANCUN(), 1, XCaller, 0, LinRoot)
  syntax Bytes ::= "XSR0" [function, total]
  rule XSR0 => linStateRootOf(linRecFBase(XR0))
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

  // ---- R1: lending borrow (threads onto R0) ----------------------------------
  syntax Map ::= "XQ1" [function, total]
  rule XQ1 => LinSetKV(LinSetKV(LinKV1D(4097, 0, 100), 4098, 0, 0), 4098, 1, 0)
  syntax Map ::= "XE1" [function, total]
  rule XE1 => LinSetKV(LinKV1D(4098, 0, 100), 4098, 1, 100)
  syntax Map ::= "XP1" [function, total]
  rule XP1 => LinSetKV(LinSetKV(LinKV1D(4097, 0, 100), 4098, 0, 100), 4098, 1, 100)
  syntax List ::= "XT1" [function, total]
  rule XT1 => ListItem( exEvt(1, 4097, 0, 100) )
             ListItem( exEvt(2, 4098, 0, 100) )
             ListItem( exEvt(2, 4098, 1, 100) )
  syntax LinRecF ::= "XR1" [function, total]
  rule XR1 => ExecBuildRecF(1, ExecChildF( linRecFBase(XR0), linExecIdOf(XR0)
                                         , linEffTraceDOf(XR0)
                                         , linExecWDOf(XR0)
                                         , linExecCfgDOf(XR0) ),
                            XQ1, XE1, XP1, LinDemoKey1, 5,
                            XT1, XPld1, ExecSchedCANCUN(), 1, XCaller, 0, XSR0)
  syntax Bytes ::= "XSR1" [function, total]
  rule XSR1 => linStateRootOf(linRecFBase(XR1))
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

  // ---- authority objects (verbatim 1G-demo discipline) -----------------------
  syntax AuthzCert ::= "XCert0" [function, total]
  rule XCert0
    => azCert( ExecPayloadDigest(XPld0), LinRoot, linExecIdOf(XR0), XSR0
             , linEffTraceDOf(XR0), 1
             , azSrc(domConsensus, AuthzConsensusId(XChain), 0)
             , .List, 1, .Bytes )
  syntax AuthzCert ::= "XCert1" [function, total]
  rule XCert1
    => azCert( ExecPayloadDigest(XPld1), XSR0, linExecIdOf(XR1), XSR1
             , linEffTraceDOf(XR1), 1
             , azSrc(domConsensus, AuthzConsensusId(XChain), 0)
             , .List, 1, .Bytes )
  syntax LinRecG ::= "XRG0" [function, total]
  rule XRG0 => linRecG(XR0, AzCertId(XCert0), 1)
  syntax LinRecG ::= "XRG1" [function, total]
  rule XRG1 => linRecG(XR1, AzCertId(XCert1), 1)

  // ---- the R3 pinned configuration (mirrors the R2 demo XCfgR2) --------------
  // The SAME 13 fields the R2 demo pinned — now ALL committed by the root.
  syntax Bytes ::= "XPolicyD" [function, total]
  rule XPolicyD => LinHex("504f4c")
  syntax Bytes ::= "XClientCfgD" [function, total]
  rule XClientCfgD => ExecConfigDigest(ExecSchedCANCUN(), 1)
  syntax Bytes ::= "XExecClientD" [function, total]
  rule XExecClientD => AuthzExecClientId(XChain, ExecConfigDigest(ExecSchedCANCUN(), 1))
  syntax Bytes ::= "XFork" [function, total]
  rule XFork => LinHex("4631")
  syntax ProtoCfgR3 ::= "XCfgR3" [function, total]
  rule XCfgR3
    => protoCfgR3( XChain, 1, XPolicyD, XAppSetD, XGraphD
                 , XClientCfgD, XExecClientD, XFork
                 , ExecSchedCANCUN(), 1, 1, XGuestD, XProofCfgD )

  // the schedule-mutated configuration (field 9; the R2-alias class)
  syntax ProtoCfgR3 ::= "XCfgR3SchedB" [function, total]
  rule XCfgR3SchedB
    => protoCfgR3( XChain, 1, XPolicyD, XAppSetD, XGraphD
                 , XClientCfgD, XExecClientD, XFork
                 , LinHex("5343484544554c452d42")          // "SCHEDULE-B"
                 , 1, 1, XGuestD, XProofCfgD )

  // ---- R3 candidate blocks — DERIVED from the evidence -----------------------
  syntax ProtoBlockR3 ::= "XB0" [function, total]
  rule XB0
    => protoBlockR3( ProtoRootR3(XCfgR3)                // parent commitment
                   , ExecPayloadDigest(XPld0)           // payload digest
                   , LinRoot                            // parent state root
                   , XSR0                               // post-state root
                   , linEffTraceDOf(XR0)                // effect-trace digest
                   , linAzCertDOf(XRG0)                 // evidence identity
                   , CtxDigestR3(ProtoAuthorizedSecCtxR3(XCfgR3, LinRoot))
                   , PolicyCommitmentR3(XCfgR3)         // policy commitment
                   , 1                                  // decision (valid)
                   , 0 )                                // slot
  syntax ProtoBlockR3 ::= "XB1" [function, total]
  rule XB1
    => protoBlockR3( BlockCommitR3(XB0, XCfgR3)
                   , ExecPayloadDigest(XPld1)
                   , XSR0
                   , XSR1
                   , linEffTraceDOf(XR1)
                   , linAzCertDOf(XRG1)
                   , CtxDigestR3(ProtoAuthorizedSecCtxR3(XCfgR3, XSR0))
                   , PolicyCommitmentR3(XCfgR3)
                   , 1
                   , 1 )
  // a slot-1 candidate presented at slot 0 (the position-substitution case)
  syntax ProtoBlockR3 ::= "XB0slot1" [function, total]
  rule XB0slot1
    => protoBlockR3( ProtoRootR3(XCfgR3), ExecPayloadDigest(XPld0), LinRoot
                   , XSR0, linEffTraceDOf(XR0), linAzCertDOf(XRG0)
                   , CtxDigestR3(ProtoAuthorizedSecCtxR3(XCfgR3, LinRoot))
                   , PolicyCommitmentR3(XCfgR3), 1, 1 )

  // =============================================================================
  // Cross-layer byte certificate helpers (the 1G-demo discipline, verbatim)
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

  // ---- the R3 cross-layer byte certificate (the 1G xbytes discipline) -------
  // INCLUDES the complete 13-field canonical preimage and its real-Keccak
  // root — the K-side half of the cross-language conformance vector.
  syntax PCmdR3I ::= "xCertR3"
  rule <k> xCertR3
        => "cfgr3canonlen="     +String Int2String(lengthBytes(ProtoCfgCanonR3(XCfgR3)))
           +String ",cfgr3canon="  +String Bytes2StringX(ProtoCfgCanonR3(XCfgR3))
           +String ",cfgr3root="       +String Bytes2StringX(ProtoRootR3(XCfgR3))
           +String ",cfgr3canonlenS="  +String Int2String(lengthBytes(ProtoCfgCanonR3(XCfgR3SchedB)))
           +String ",cfgr3rootS="      +String Bytes2StringX(ProtoRootR3(XCfgR3SchedB))
           +String ",policycommitr3=" +String Bytes2StringX(PolicyCommitmentR3(XCfgR3))
           +String ",ctxdigest0="     +String Bytes2StringX(CtxDigestR3(ProtoAuthorizedSecCtxR3(XCfgR3, LinRoot)))
           +String ",blockcommit0="   +String Bytes2StringX(BlockCommitR3(XB0, XCfgR3))
           +String ",srw3root0="      +String Bytes2StringX(SRW3RootR3(XB0, XCfgR3))
           +String ",certid0="        +String Bytes2StringX(AzCertId(XCert0))
           +String ",certid1="        +String Bytes2StringX(AzCertId(XCert1))
           +String ",recchild0="      +String Bytes2StringX(R3RecChildF(XRG0))
           +String ",verdict0="       +String VerifyLineageG(XRG0,
                    azCtx(XCtx0, ProtoAuthorizedSecCtxR3(XCfgR3, LinRoot),
                          XCert0, qcrAuthPTOf(XCfgR3), qcrAuthGuestDOf(XCfgR3),
                          qcrAuthCfgDOf(XCfgR3)), 0, LinRoot)
           +String ",verdict1="       +String VerifyLineageG(XRG1,
                    azCtx(XCtx1, ProtoAuthorizedSecCtxR3(XCfgR3, XSR0),
                          XCert1, qcrAuthPTOf(XCfgR3), qcrAuthGuestDOf(XCfgR3),
                          qcrAuthCfgDOf(XCfgR3)), 1, R3RecChildF(XRG0)) ... </k>

endmodule
