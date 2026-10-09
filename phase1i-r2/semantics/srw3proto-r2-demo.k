// =============================================================================
// SRW3 Phase 1I-R2 — K demonstration suite (srw3proto-r2-demo.k)
//
// The honest evidence fragments (the Oracle -> Lending -> Liquidator chain,
// the authority certificates, the security contexts) are reproduced VERBATIM
// from the frozen Phase 1G demonstration suite
// (phase1g/semantics/srw3authz-demo.k — same accounts 4097/4098/4099, same
// keys, same canonical values; the copy is required because that demo module
// declares its own configuration, which cannot coexist with <srw3protoR2>
// under K's one-<k>-cell rule).  The R2 candidate blocks are DERIVED from the
// fragments by the GateInputMatchesBlockR2 discipline: every candidate field
// is the same expression the binding predicate computes, so the binding
// equalities are syntactic identities (resolvable on the Haskell backend,
// where the hash expressions remain unevaluated Keccak256raw applications).
//
// Programs (partitioned; see run_demos.sh):
//   xhonest2 : init -> gate(0) -> accept(0) -> gate(1) -> accept(1)
//              the honest pipeline, two blocks (accept is the documented hs
//              boundary: the computed verdict stays an unevaluated
//              VerifyLineageG application; the concrete run is LLVM/Python)
//   xgateonly: init -> gate(0): the receipt is minted with the COMPUTED
//              verdict; NO chain state moves
//   xnoreceipt: accept with NO mint (missing evidence) -> clean reject
//   xreinit  : pInitR2 twice -> the re-initialization is refused
//   xcfgsub  : mint(0) then accept with config-version witness 2 -> reject
//   xslotskip: gate at slot 0 for a slot-1 candidate -> mint refuses;
//              accept then finds no receipt -> reject
//   xinj     : the R1 injection shape pGateEvalR2(..., "valid-g") — SEVEN
//              arguments — is ILL-FORMED in the R2 command language
//   xlegacy  : the legacy commands (pAccept / pGateEval / pAcceptR1 /
//              pInitR1) are ILL-FORMED in the R2 command language
// =============================================================================

requires "srw3proto-r2.k"

module SRW3PROTO-R2-DEMO
  imports SRW3PROTO-R2

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

  // ---- the R2 pinned configuration -------------------------------------------
  // Fields 1..8 correspond to the 1I ProtoCfg of the R1 demos (chainId 0x01,
  // policyV 1, the honest app-set/graph digests); fields 9..13 pin the gate
  // authority parameters (schedule CANCUN, spec 1, proof type 1, guest
  // digest, proof-config digest) — the handoff section 5.3 additions.
  syntax Bytes ::= "XPolicyD" [function, total]
  rule XPolicyD => LinHex("504f4c")
  syntax Bytes ::= "XClientCfgD" [function, total]
  rule XClientCfgD => ExecConfigDigest(ExecSchedCANCUN(), 1)
  syntax Bytes ::= "XExecClientD" [function, total]
  rule XExecClientD => AuthzExecClientId(XChain, ExecConfigDigest(ExecSchedCANCUN(), 1))
  syntax Bytes ::= "XFork" [function, total]
  rule XFork => LinHex("4631")
  syntax ProtoCfgR2 ::= "XCfgR2" [function, total]
  rule XCfgR2
    => protoCfgR2( XChain, 1, XPolicyD, XAppSetD, XGraphD
                 , XClientCfgD, XExecClientD, XFork
                 , ExecSchedCANCUN(), 1, 1, XGuestD, XProofCfgD )

  // ---- R2 candidate blocks — DERIVED from the evidence -----------------------
  // Every field is the same expression the binding predicate and the
  // commitment predicate compute (see the module header).
  syntax ProtoBlockR2 ::= "XB0" [function, total]
  rule XB0
    => protoBlockR2( ProtoRootR2(XCfgR2)                // parent commitment
                   , ExecPayloadDigest(XPld0)           // payload digest
                   , LinRoot                            // parent state root
                   , XSR0                               // post-state root
                   , linEffTraceDOf(XR0)                // effect-trace digest
                   , linAzCertDOf(XRG0)                 // evidence identity
                   , CtxDigestR2(ProtoAuthorizedSecCtxR2(XCfgR2, LinRoot))
                   , PolicyCommitmentR2(XCfgR2)         // policy commitment
                   , 1                                  // decision (valid)
                   , 0 )                                // slot
  syntax ProtoBlockR2 ::= "XB1" [function, total]
  rule XB1
    => protoBlockR2( BlockCommitR2(XB0, XCfgR2)
                   , ExecPayloadDigest(XPld1)
                   , XSR0
                   , XSR1
                   , linEffTraceDOf(XR1)
                   , linAzCertDOf(XRG1)
                   , CtxDigestR2(ProtoAuthorizedSecCtxR2(XCfgR2, XSR0))
                   , PolicyCommitmentR2(XCfgR2)
                   , 1
                   , 1 )
  // a slot-1 candidate presented at slot 0 (the position-substitution case)
  syntax ProtoBlockR2 ::= "XB0slot1" [function, total]
  rule XB0slot1
    => protoBlockR2( ProtoRootR2(XCfgR2), ExecPayloadDigest(XPld0), LinRoot
                   , XSR0, linEffTraceDOf(XR0), linAzCertDOf(XRG0)
                   , CtxDigestR2(ProtoAuthorizedSecCtxR2(XCfgR2, LinRoot))
                   , PolicyCommitmentR2(XCfgR2), 1, 1 )
  // a candidate with an ALTERED payload digest (the payload-substitution case)
  syntax ProtoBlockR2 ::= "XB0altPld" [function, total]
  rule XB0altPld
    => protoBlockR2( ProtoRootR2(XCfgR2), ExecPayloadDigest(XPld1), LinRoot
                   , XSR0, linEffTraceDOf(XR0), linAzCertDOf(XRG0)
                   , CtxDigestR2(ProtoAuthorizedSecCtxR2(XCfgR2, LinRoot))
                   , PolicyCommitmentR2(XCfgR2), 1, 0 )

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

  // ---- the R2 cross-layer byte certificate (the 1G xbytes discipline) -------
  syntax PCmdR2I ::= "xCertR2"
  rule <k> xCertR2
        => "cfgr2root="       +String Bytes2StringX(ProtoRootR2(XCfgR2))
           +String ",policycommitr2=" +String Bytes2StringX(PolicyCommitmentR2(XCfgR2))
           +String ",ctxdigest0="     +String Bytes2StringX(CtxDigestR2(ProtoAuthorizedSecCtxR2(XCfgR2, LinRoot)))
           +String ",blockcommit0="   +String Bytes2StringX(BlockCommitR2(XB0, XCfgR2))
           +String ",srw3root0="      +String Bytes2StringX(SRW3RootR2(XB0, XCfgR2))
           +String ",certid0="        +String Bytes2StringX(AzCertId(XCert0))
           +String ",certid1="        +String Bytes2StringX(AzCertId(XCert1))
           +String ",recchild0="      +String Bytes2StringX(R2RecChildF(XRG0))
           +String ",verdict0="       +String VerifyLineageG(XRG0,
                    azCtx(XCtx0, ProtoAuthorizedSecCtxR2(XCfgR2, LinRoot),
                          XCert0, pcrAuthPTOf(XCfgR2), pcrAuthGuestDOf(XCfgR2),
                          pcrAuthCfgDOf(XCfgR2)), 0, LinRoot)
           +String ",verdict1="       +String VerifyLineageG(XRG1,
                    azCtx(XCtx1, ProtoAuthorizedSecCtxR2(XCfgR2, XSR0),
                          XCert1, pcrAuthPTOf(XCfgR2), pcrAuthGuestDOf(XCfgR2),
                          pcrAuthCfgDOf(XCfgR2)), 1, R2RecChildF(XRG0)) ... </k>

endmodule
