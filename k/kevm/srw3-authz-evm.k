// =============================================================================
// SRW3 Phase 1G — THE AUTHORITY ADAPTER over REAL EVM execution (Tier G2)
//                          (k/kevm/srw3-authz-evm.k — ADDITIVE)
//
// The Phase 1F instrumented layer (srw3-exec-evm.k, frozen) is extended with
// the AUTHORITY ADAPTER (MODEL.md §10/§11):
//
//   * #w3GateG(ANCHOR, PAYLOAD, DECLARED, PRESENTED): the 1G gate over REAL
//     EVM storage. The full 1F chain (including the LEVEL-3 EXECUTION CHECK)
//     fires first; on top of valid-f, the ADAPTER constructs the
//     AuthorityCertificate FROM THE RUN — Mode A (rel=2): the source is the
//     authorized execution client for (chainId, config), the authority chain
//     carries the consensus root, and the certificate's effect digest binds
//     the EXECUTION-DERIVED trace. The authbind check then forces
//     presented-trace-digest == executed-trace-digest: at this layer the
//     presented evidence IS the executed evidence.
//
//   * #w3GateGBad(...): the SELF-AUTHORIZING variant (CM-G3a at the EVM
//     layer) — the adapter's certificate claims LEVEL 0 for the execution
//     client. Expected: invalid-authlevel -> REJECT + RESTORE.
//
//   * Model chain identity: #w3AzChainId = 0x00000001 (matches -cCHAINID=1;
//     the KEVM config plumbing is NOT modified — documented fragment
//     boundary). The SecurityContext is the run-local honest fragment
//     (policyV=1, the demo application set, lineage head = the threaded
//     carrier head HB).
//
// The anchor's provenance remains REQUIRES CLIENT/PROTOCOL SUPPORT in
// deployment; at this layer the certificate AUTHORIZES the anchor value
// (the A-E3 replacement of MODEL.md §10), and the adapter demonstrates the
// smallest authoritative integration point a client could expose
// (post-execution state root + execution evidence -> authority statement).
// =============================================================================

requires "srw3-exec-evm.k"
requires "srw3authz.k"

module SRW3-AUTHZ-EVM
  imports SRW3-EXEC-EVM
  imports SRW3AUTHZ

  // ---- model chain identity (fragment constant; see header) ------------------
  syntax Bytes ::= "#w3AzChainId" [function, total]
  rule #w3AzChainId => Int2Bytes(4, 1, BE)

  // the honest fragment SecurityContext constants (aligned with the abstract
  // demo: the observed application set {4097,4098,4099}, a 3-node graph)
  syntax Bytes ::= "#w3AzAppSetD" [function, total]
  rule #w3AzAppSetD
    => LinH( Int2Bytes(1, 143, BE) +Bytes I2B4(4097) +Bytes I2B4(4098)
             +Bytes I2B4(4099) )
  syntax Bytes ::= "#w3AzGraphD" [function, total]
  rule #w3AzGraphD => LinH(Int2Bytes(1, 144, BE) +Bytes I2B4(3))

  // ---- THE AUTHORITY ADAPTER (Mode A): the certificate FROM THE RUN ---------
  // The effect digest binds the EXECUTION-DERIVED trace (ET = #w3TraceOf).
  // The certificate takes the F record as an ARGUMENT (projections only) —
  // recomputing #w3FRec inside the cert OOM-killed the commit demo at the
  // 3 GB ceiling (recorded); this shape computes the F record once per use
  // site and threads it.
  syntax AuthzCert ::= "#w3AzCertOf" "(" LinRecF "," Bytes "," Bytes "," Bytes "," List ")" [function]
  rule #w3AzCertOf(FR:LinRecF, PL:Bytes, PR:Bytes, HB:Bytes, ET:List)
    => azCert( ExecPayloadDigest(PL)
             , PR
             , linExecIdOf(FR)
             , linStateRootOf(linRecFBase(FR))
             , ExecTraceDigest(ET)
             , 2
             , azSrc( domExecution
                    , AuthzExecClientId( #w3AzChainId
                                       , ExecConfigDigest( ExecSchedCANCUN()
                                                         , ExecSpecV1() ) )
                    , 1 )
             , ListItem( azStep(domConsensus
                              , AuthzConsensusId(#w3AzChainId), 0) )
             , 1
             , .Bytes )

  // the SELF-AUTHORIZING variant (CM-G3a): the client claims LEVEL 0
  syntax AuthzCert ::= "#w3AzCertSelfOf" "(" LinRecF "," Bytes "," Bytes "," Bytes "," List ")" [function]
  rule #w3AzCertSelfOf(FR:LinRecF, PL:Bytes, PR:Bytes, HB:Bytes, ET:List)
    => azCert( ExecPayloadDigest(PL)
             , PR
             , linExecIdOf(FR)
             , linStateRootOf(linRecFBase(FR))
             , ExecTraceDigest(ET)
             , 2
             , azSrc( domExecution
                    , AuthzExecClientId( #w3AzChainId
                                       , ExecConfigDigest( ExecSchedCANCUN()
                                                         , ExecSpecV1() ) )
                    , 0 )
             , .List
             , 1
             , .Bytes )

  // the G record + context over the PRESENTED trace (the certificate binds
  // the EXECUTED trace — authbind forces them equal)
  syntax LinRecG ::= "#w3GRecOf" "(" LinRecF "," Bytes "," Bytes "," Bytes ","
                       List ")" [function]
  rule #w3GRecOf(FR:LinRecF, PL:Bytes, PR:Bytes, HB:Bytes, ET:List)
    => linRecG( FR
              , AzCertId( #w3AzCertOf(FR, PL, PR, HB, ET) )
              , 1 )

  syntax AzCtx ::= "#w3GCtx" "(" Map "," Map "," Bytes "," Bytes "," Bytes ","
                     List "," List "," Bytes "," AuthzCert ")" [function]
  rule #w3GCtx(PS:Map, DECL:Map, HB:Bytes, PL:Bytes, PR:Bytes,
               PRESENTED:List, ET:List, ANCHOR:Bytes, CERT:AuthzCert)
    => azCtx( execCtx( authCtx( linCtxP(PS, DECL, #w3FCUR, ARegE, AAuthE)
                              , ANCHOR )
                     , PR, PL, ExecSchedCANCUN(), ExecSpecV1()
                     , #w3FCaller, 0
                     , PRESENTED
                     , #w3FWit(PS, DECL, #w3FCUR, PL, PR, PRESENTED) )
            , secCtx(1, #w3AzChainId, #w3AzAppSetD, #w3AzGraphD, HB)
            , CERT
            , 0, .Bytes, .Bytes )

  // ---- the G verdict (the 1F chain first, then the authority adapter) -------
  // MEMORY-CEILING FACTORIZATION (documented): the abstract VerifyLineageG
  // re-evaluates the F chain in every layer rule (the first-fail cascade);
  // over REAL EVM state that is 9^3 PE-chain evaluations and OOM-kills the
  // 3 GB sandbox. The KEVM harness therefore evaluates the F chain ONCE
  // (dispatch below) and then the SEVEN AUTHORITY LAYERS in isolation
  // (#w3AzVerdict — same verdict surface, the F half guaranteed by the
  // dispatch). The integrated VerifyLineageG remains the canonical form
  // (proved at the abstract layer; demos green there).
  syntax String ::= "#w3GVerdictK" "(" Map "," Map "," Int "," Bytes "," Bytes ","
                      List "," Bytes "," Bool ")" [function]

  // the frozen 1F chain diagnoses first (its verdicts unchanged)
  rule [[ #w3GVerdictK(PS:Map, DECL:Map, NB:Int, HB:Bytes, PL:Bytes,
                       PRESENTED:List, ANCHOR:Bytes, _USESELF:Bool)
          => #w3FVerdict(PS, DECL, NB, HB, PL, PRESENTED, #w3TraceOf(T, 0)
                       , ANCHOR) ]]
       <account> <acctID> TC:Int </acctID> <storage> T:Map </storage> ... </account>
    requires TC ==Int #w3Tracer
     andBool notBool #w3FVerdict(PS, DECL, NB, HB, PL, PRESENTED
                               , #w3TraceOf(T, 0), ANCHOR) ==String "valid-f"

  // the authority adapter (honest Mode A certificate); the F half is
  // satisfied by the dispatch, so the G verdict IS the authority verdict
  rule [[ #w3GVerdictK(PS:Map, DECL:Map, NB:Int, HB:Bytes, PL:Bytes,
                       PRESENTED:List, ANCHOR:Bytes, false)
          => #w3AzVerdict( #w3GRecOf( #w3FRec(PS, DECL, #w3FCUR, NB, HB, PL
                                            , PRESENTED)
                                    , PL, #w3FParRoot(PS, DECL, #w3FCUR)
                                    , HB, #w3TraceOf(T, 0) )
                         , #w3GCtx( PS, DECL, HB, PL
                                  , #w3FParRoot(PS, DECL, #w3FCUR)
                                  , PRESENTED, #w3TraceOf(T, 0), ANCHOR
                                  , #w3AzCertOf( #w3FRec(PS, DECL, #w3FCUR, NB
                                                       , HB, PL, PRESENTED)
                                               , PL
                                               , #w3FParRoot(PS, DECL, #w3FCUR)
                                               , HB, #w3TraceOf(T, 0) ) )
                         , NB, HB ) ]]
       <account> <acctID> TC:Int </acctID> <storage> T:Map </storage> ... </account>
    requires TC ==Int #w3Tracer
     andBool #w3FVerdict(PS, DECL, NB, HB, PL, PRESENTED, #w3TraceOf(T, 0)
                       , ANCHOR) ==String "valid-f"

  // the self-authorizing variant (CM-G3a)
  rule [[ #w3GVerdictK(PS:Map, DECL:Map, NB:Int, HB:Bytes, PL:Bytes,
                       PRESENTED:List, ANCHOR:Bytes, true)
          => #w3AzVerdict( #w3GRecOf( #w3FRec(PS, DECL, #w3FCUR, NB, HB, PL
                                            , PRESENTED)
                                    , PL, #w3FParRoot(PS, DECL, #w3FCUR)
                                    , HB, #w3TraceOf(T, 0) )
                         , #w3GCtx( PS, DECL, HB, PL
                                  , #w3FParRoot(PS, DECL, #w3FCUR)
                                  , PRESENTED, #w3TraceOf(T, 0), ANCHOR
                                  , #w3AzCertSelfOf( #w3FRec(PS, DECL, #w3FCUR
                                                           , NB, HB, PL
                                                           , PRESENTED)
                                                   , PL
                                                   , #w3FParRoot(PS, DECL, #w3FCUR)
                                                   , HB, #w3TraceOf(T, 0) ) )
                         , NB, HB ) ]]
       <account> <acctID> TC:Int </acctID> <storage> T:Map </storage> ... </account>
    requires TC ==Int #w3Tracer
     andBool #w3FVerdict(PS, DECL, NB, HB, PL, PRESENTED, #w3TraceOf(T, 0)
                       , ANCHOR) ==String "valid-f"

  // ---- the seven authority layers in isolation (the F half of the Gate_G
  // accept is guaranteed by the dispatch above; the verdict surface is the
  // L23..L30 cascade of srw3authz.k with the F premise removed) --------------
  syntax String ::= "#w3AzVerdict" "(" LinRecG "," AzCtx "," Int "," Bytes ")"
                   [function, total]

  rule #w3AzVerdict(RG:LinRecG, C:AzCtx, T:Int, HEAD:Bytes)
    => "invalid-authtype"
    requires notBool ( azRelOf(azCertOf(C)) ==Int 1
                       orBool azRelOf(azCertOf(C)) ==Int 2
                       orBool azRelOf(azCertOf(C)) ==Int 3 )

  rule #w3AzVerdict(RG:LinRecG, C:AzCtx, T:Int, HEAD:Bytes)
    => "invalid-authrel"
    requires ( azRelOf(azCertOf(C)) ==Int 1
               orBool azRelOf(azCertOf(C)) ==Int 2
               orBool azRelOf(azCertOf(C)) ==Int 3 )
             andBool notBool
                     AzDomEq( azSrcDomOf(azSrcOf(azCertOf(C)))
                            , AzRelDomain(azRelOf(azCertOf(C))) )

  rule #w3AzVerdict(RG:LinRecG, C:AzCtx, T:Int, HEAD:Bytes)
    => "invalid-authlevel"
    requires ( azRelOf(azCertOf(C)) ==Int 1
               orBool azRelOf(azCertOf(C)) ==Int 2
               orBool azRelOf(azCertOf(C)) ==Int 3 )
             andBool AzDomEq( azSrcDomOf(azSrcOf(azCertOf(C)))
                            , AzRelDomain(azRelOf(azCertOf(C))) )
             andBool notBool azSrcLevelOf(azSrcOf(azCertOf(C)))
                             ==Int AuthzDomLevel(azSrcDomOf(azSrcOf(azCertOf(C))))

  rule #w3AzVerdict(RG:LinRecG, C:AzCtx, T:Int, HEAD:Bytes)
    => "invalid-authcircle"
    requires ( azRelOf(azCertOf(C)) ==Int 1
               orBool azRelOf(azCertOf(C)) ==Int 2
               orBool azRelOf(azCertOf(C)) ==Int 3 )
             andBool AzDomEq( azSrcDomOf(azSrcOf(azCertOf(C)))
                            , AzRelDomain(azRelOf(azCertOf(C))) )
             andBool azSrcLevelOf(azSrcOf(azCertOf(C)))
                     ==Int AuthzDomLevel(azSrcDomOf(azSrcOf(azCertOf(C))))
             andBool notBool AzNonCircular( azCertOf(C), azFctxOf(C)
                                          , azSecOf(C), azAuthPTOf(C)
                                          , azAuthGuestDOf(C)
                                          , azAuthCfgDOf(C) )

  rule #w3AzVerdict(RG:LinRecG, C:AzCtx, T:Int, HEAD:Bytes)
    => "invalid-authsrc"
    requires ( azRelOf(azCertOf(C)) ==Int 1
               orBool azRelOf(azCertOf(C)) ==Int 2
               orBool azRelOf(azCertOf(C)) ==Int 3 )
             andBool AzDomEq( azSrcDomOf(azSrcOf(azCertOf(C)))
                            , AzRelDomain(azRelOf(azCertOf(C))) )
             andBool azSrcLevelOf(azSrcOf(azCertOf(C)))
                     ==Int AuthzDomLevel(azSrcDomOf(azSrcOf(azCertOf(C))))
             andBool AzNonCircular( azCertOf(C), azFctxOf(C), azSecOf(C)
                                  , azAuthPTOf(C), azAuthGuestDOf(C)
                                  , azAuthCfgDOf(C) )
             andBool notBool
                     AzSrcAuthorized( azSrcOf(azCertOf(C)), azFctxOf(C)
                                    , azSecOf(C), azAuthPTOf(C)
                                    , azAuthGuestDOf(C), azAuthCfgDOf(C) )

  rule #w3AzVerdict(RG:LinRecG, C:AzCtx, T:Int, HEAD:Bytes)
    => "invalid-authbind"
    requires ( azRelOf(azCertOf(C)) ==Int 1
               orBool azRelOf(azCertOf(C)) ==Int 2
               orBool azRelOf(azCertOf(C)) ==Int 3 )
             andBool AzDomEq( azSrcDomOf(azSrcOf(azCertOf(C)))
                            , AzRelDomain(azRelOf(azCertOf(C))) )
             andBool azSrcLevelOf(azSrcOf(azCertOf(C)))
                     ==Int AuthzDomLevel(azSrcDomOf(azSrcOf(azCertOf(C))))
             andBool AzNonCircular( azCertOf(C), azFctxOf(C), azSecOf(C)
                                  , azAuthPTOf(C), azAuthGuestDOf(C)
                                  , azAuthCfgDOf(C) )
             andBool AzSrcAuthorized( azSrcOf(azCertOf(C)), azFctxOf(C)
                                    , azSecOf(C), azAuthPTOf(C)
                                    , azAuthGuestDOf(C), azAuthCfgDOf(C) )
             andBool notBool AzCertBindOk( azCertOf(C), RG
                                         , azFctxOf(C), azSecOf(C) )

  rule #w3AzVerdict(RG:LinRecG, C:AzCtx, T:Int, HEAD:Bytes)
    => "invalid-policy"
    requires ( azRelOf(azCertOf(C)) ==Int 1
               orBool azRelOf(azCertOf(C)) ==Int 2
               orBool azRelOf(azCertOf(C)) ==Int 3 )
             andBool AzDomEq( azSrcDomOf(azSrcOf(azCertOf(C)))
                            , AzRelDomain(azRelOf(azCertOf(C))) )
             andBool azSrcLevelOf(azSrcOf(azCertOf(C)))
                     ==Int AuthzDomLevel(azSrcDomOf(azSrcOf(azCertOf(C))))
             andBool AzNonCircular( azCertOf(C), azFctxOf(C), azSecOf(C)
                                  , azAuthPTOf(C), azAuthGuestDOf(C)
                                  , azAuthCfgDOf(C) )
             andBool AzSrcAuthorized( azSrcOf(azCertOf(C)), azFctxOf(C)
                                    , azSecOf(C), azAuthPTOf(C)
                                    , azAuthGuestDOf(C), azAuthCfgDOf(C) )
             andBool AzCertBindOk( azCertOf(C), RG, azFctxOf(C), azSecOf(C) )
             andBool notBool azPolicyVOf(azCertOf(C))
                             ==Int secPolicyVOf(azSecOf(C))

  rule #w3AzVerdict(RG:LinRecG, C:AzCtx, T:Int, HEAD:Bytes)
    => "valid-g"
    requires ( azRelOf(azCertOf(C)) ==Int 1
               orBool azRelOf(azCertOf(C)) ==Int 2
               orBool azRelOf(azCertOf(C)) ==Int 3 )
             andBool AzDomEq( azSrcDomOf(azSrcOf(azCertOf(C)))
                            , AzRelDomain(azRelOf(azCertOf(C))) )
             andBool azSrcLevelOf(azSrcOf(azCertOf(C)))
                     ==Int AuthzDomLevel(azSrcDomOf(azSrcOf(azCertOf(C))))
             andBool AzNonCircular( azCertOf(C), azFctxOf(C), azSecOf(C)
                                  , azAuthPTOf(C), azAuthGuestDOf(C)
                                  , azAuthCfgDOf(C) )
             andBool AzSrcAuthorized( azSrcOf(azCertOf(C)), azFctxOf(C)
                                    , azSecOf(C), azAuthPTOf(C)
                                    , azAuthGuestDOf(C), azAuthCfgDOf(C) )
             andBool AzCertBindOk( azCertOf(C), RG, azFctxOf(C), azSecOf(C) )
             andBool azPolicyVOf(azCertOf(C)) ==Int secPolicyVOf(azSecOf(C))

  // ---- the demonstration carrier --------------------------------------------
  syntax KItem ::= "#w3GState" "(" recG:LinRecG "," root:Bytes
                               "," trace:List "," verdict:String ")"

  // ACCEPT (continuing — a 1D carrier exists): the FULL 1G verdict
  rule <k> #w3State(SG:Map, LN:Map, N:Int, H:Int)
           ~> #w3LinState(LIN:Map, NB:Int, HB:Bytes, PS:Map)
           ~> ( #w3GateG(ANCHOR:Bytes, PL:Bytes, DECL:Map, PRESENTED:List)
                REST:EthereumSimulation )
        => #w3State(#w3allStorages(), LN[N:Int <- w3lin(H:Int, N:Int, #w3read(w3Lending, 0))],
                    N +Int 1, N)
           ~> #w3LinState( LIN[NB:Int <- linRecOfE(linRecFBase(linRecGBase(
                                 #w3GRecOf( #w3FRec(PS, DECL, #w3FCUR, NB, HB, PL, PRESENTED), PL, #w3FParRoot(PS, DECL, #w3FCUR), HB, #w3ExecTrace ))))]
                         , NB +Int 1
                         , linChildOf(linRecOfE(linRecFBase(linRecGBase(
                                 #w3GRecOf( #w3FRec(PS, DECL, #w3FCUR, NB, HB, PL, PRESENTED), PL, #w3FParRoot(PS, DECL, #w3FCUR), HB, #w3ExecTrace )))))
                         , #w3allStorages() )
           ~> #w3GState( #w3GRecOf( #w3FRec(PS, DECL, #w3FCUR, NB, HB, PL, PRESENTED)
                           , PL, #w3FParRoot(PS, DECL, #w3FCUR)
                           , HB, #w3ExecTrace )
                       , linStateRootOf(linRecFBase(linRecGBase(
                             #w3GRecOf( #w3FRec(PS, DECL, #w3FCUR, NB, HB, PL, PRESENTED), PL, #w3FParRoot(PS, DECL, #w3FCUR), HB, #w3ExecTrace ))))
                       , #w3ExecTrace
                       , "valid-g" )
           ~> REST ... </k>
    requires #w3OblG()
     andBool #w3GVerdictK(PS, DECL, NB, HB, PL, PRESENTED, ANCHOR, false)
                                       ==String "valid-g"

  // REJECT (continuing): no lineage record; storages restored (the carrier
  // records WHY — commit/lineage atomicity preserved)
  rule <k> #w3State(SG:Map, LN:Map, N:Int, H:Int)
           ~> #w3LinState(LIN:Map, NB:Int, HB:Bytes, PS:Map)
           ~> ( #w3GateG(ANCHOR:Bytes, PL:Bytes, DECL:Map, PRESENTED:List)
                REST:EthereumSimulation )
        => #w3GState( #w3GRecOf( #w3FRec(PS, DECL, #w3FCUR, NB, HB, PL, PRESENTED)
                           , PL, #w3FParRoot(PS, DECL, #w3FCUR)
                           , HB, #w3ExecTrace )
                    , linStateRootOf(linRecFBase(linRecGBase(
                          #w3GRecOf( #w3FRec(PS, DECL, #w3FCUR, NB, HB, PL, PRESENTED), PL, #w3FParRoot(PS, DECL, #w3FCUR), HB, #w3ExecTrace ))))
                    , #w3ExecTrace
                    , #w3GVerdictK(PS, DECL, NB, HB, PL, PRESENTED, ANCHOR
                                 , false) )
           ~> #w3RestoreAll(SG)
           ~> #w3State(SG, LN, N, H)
           ~> #w3LinState(LIN, NB, HB, PS)
           ~> REST ... </k>
    requires #w3OblG()
     andBool notBool #w3GVerdictK(PS, DECL, NB, HB, PL, PRESENTED, ANCHOR, false)
                                       ==String "valid-g"

  // ACCEPT (fresh — first gate; no 1D carrier yet)
  rule <k> #w3State(SG:Map, LN:Map, N:Int, H:Int)
           ~> ( #w3GateG(ANCHOR:Bytes, PL:Bytes, DECL:Map, PRESENTED:List)
                REST:EthereumSimulation )
        => #w3State(#w3allStorages(), LN[N:Int <- w3lin(H:Int, N:Int, #w3read(w3Lending, 0))],
                    N +Int 1, N)
           ~> #w3LinState( .Map[N:Int <- linRecOfE(linRecFBase(linRecGBase(
                                 #w3GRecOf( #w3FRec(SG, DECL, #w3FCUR, N, LinRoot, PL, PRESENTED), PL, #w3FParRoot(SG, DECL, #w3FCUR), LinRoot, #w3ExecTrace ))))]
                         , N +Int 1
                         , linChildOf(linRecOfE(linRecFBase(linRecGBase(
                                 #w3GRecOf( #w3FRec(SG, DECL, #w3FCUR, N, LinRoot, PL, PRESENTED), PL, #w3FParRoot(SG, DECL, #w3FCUR), LinRoot, #w3ExecTrace )))))
                         , #w3allStorages() )
           ~> #w3GState( #w3GRecOf( #w3FRec(SG, DECL, #w3FCUR, N, LinRoot, PL, PRESENTED), PL, #w3FParRoot(SG, DECL, #w3FCUR), LinRoot, #w3ExecTrace )
                       , linStateRootOf(linRecFBase(linRecGBase(
                             #w3GRecOf( #w3FRec(SG, DECL, #w3FCUR, N, LinRoot, PL, PRESENTED), PL, #w3FParRoot(SG, DECL, #w3FCUR), LinRoot, #w3ExecTrace ))))
                       , #w3ExecTrace
                       , "valid-g" )
           ~> REST ... </k>
    requires #w3OblG()
     andBool #w3GVerdictK(SG, DECL, N, LinRoot, PL, PRESENTED, ANCHOR, false)
                                       ==String "valid-g"

  // REJECT (fresh)
  rule <k> #w3State(SG:Map, LN:Map, N:Int, H:Int)
           ~> ( #w3GateG(ANCHOR:Bytes, PL:Bytes, DECL:Map, PRESENTED:List)
                REST:EthereumSimulation )
        => #w3GState( #w3GRecOf( #w3FRec(SG, DECL, #w3FCUR, N, LinRoot, PL, PRESENTED), PL, #w3FParRoot(SG, DECL, #w3FCUR), LinRoot, #w3ExecTrace )
                    , linStateRootOf(linRecFBase(linRecGBase(
                          #w3GRecOf( #w3FRec(SG, DECL, #w3FCUR, N, LinRoot, PL, PRESENTED), PL, #w3FParRoot(SG, DECL, #w3FCUR), LinRoot, #w3ExecTrace ))))
                    , #w3ExecTrace
                    , #w3GVerdictK(SG, DECL, N, LinRoot, PL, PRESENTED, ANCHOR
                                 , false) )
           ~> #w3RestoreAll(SG)
           ~> #w3State(SG, LN, N, H)
           ~> REST ... </k>
    requires #w3OblG()
     andBool notBool #w3GVerdictK(SG, DECL, N, LinRoot, PL, PRESENTED, ANCHOR
                                , false) ==String "valid-g"

  // ---- the self-authorizing demonstration gate (CM-G3a) ---------------------
  syntax EthereumSimulation ::= "#w3GateG" "(" Bytes "," Bytes "," Map "," List ")"
  syntax EthereumSimulation ::= "#w3GateGBad" "(" Bytes "," Bytes "," Map ","
                                  List ")"

  rule <k> #w3State(SG:Map, LN:Map, N:Int, H:Int)
           ~> #w3LinState(LIN:Map, NB:Int, HB:Bytes, PS:Map)
           ~> ( #w3GateGBad(ANCHOR:Bytes, PL:Bytes, DECL:Map, PRESENTED:List)
                REST:EthereumSimulation )
        => #w3GState( #w3GRecOf( #w3FRec(PS, DECL, #w3FCUR, NB, HB, PL, PRESENTED)
                           , PL, #w3FParRoot(PS, DECL, #w3FCUR)
                           , HB, #w3ExecTrace )
                    , linStateRootOf(linRecFBase(linRecGBase(
                          #w3GRecOf( #w3FRec(PS, DECL, #w3FCUR, NB, HB, PL, PRESENTED), PL, #w3FParRoot(PS, DECL, #w3FCUR), HB, #w3ExecTrace ))))
                    , #w3ExecTrace
                    , #w3GVerdictK(PS, DECL, NB, HB, PL, PRESENTED, ANCHOR
                                 , true) )
           ~> #w3RestoreAll(SG)
           ~> #w3State(SG, LN, N, H)
           ~> #w3LinState(LIN, NB, HB, PS)
           ~> REST ... </k>
    requires #w3OblG()
     andBool notBool #w3GVerdictK(PS, DECL, NB, HB, PL, PRESENTED, ANCHOR, true)
                                       ==String "valid-g"

  rule <k> #w3State(SG:Map, LN:Map, N:Int, H:Int)
           ~> ( #w3GateGBad(ANCHOR:Bytes, PL:Bytes, DECL:Map, PRESENTED:List)
                REST:EthereumSimulation )
        => #w3GState( #w3GRecOf( #w3FRec(SG, DECL, #w3FCUR, N, LinRoot, PL, PRESENTED), PL, #w3FParRoot(SG, DECL, #w3FCUR), LinRoot, #w3ExecTrace )
                    , linStateRootOf(linRecFBase(linRecGBase(
                          #w3GRecOf( #w3FRec(SG, DECL, #w3FCUR, N, LinRoot, PL, PRESENTED), PL, #w3FParRoot(SG, DECL, #w3FCUR), LinRoot, #w3ExecTrace ))))
                    , #w3ExecTrace
                    , #w3GVerdictK(SG, DECL, N, LinRoot, PL, PRESENTED, ANCHOR
                                 , true) )
           ~> #w3RestoreAll(SG)
           ~> #w3State(SG, LN, N, H)
           ~> REST ... </k>
    requires #w3OblG()
     andBool notBool #w3GVerdictK(SG, DECL, N, LinRoot, PL, PRESENTED, ANCHOR
                                , true) ==String "valid-g"

endmodule
