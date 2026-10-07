// =============================================================================
// SRW3 Phase 1G — KEVM demo constants (srw3-authz-evm demos).
// Reuses the frozen Phase 1F demo constants (FAnchorHonest / FPayload /
// FDeclHonest / FTraceHonest — computed/verified by the 1F Python reference)
// and runs the AUTHORITY ADAPTER over the same real execution:
//   evm_authz_commit   : honest run + #w3GateG  -> valid-g -> COMMIT
//   evm_authz_selfauth : same run + #w3GateGBad (the self-authorizing
//                        certificate: the client claims LEVEL 0, CM-G3a)
//                        -> invalid-authlevel -> REJECT + RESTORE
//   evm_authz_tamper   : tampered presented trace -> caught by the FROZEN 1F
//                        chain first (invalid-effdecl) -> REJECT + RESTORE
// =============================================================================

requires "srw3-authz-evm.k"
requires "srw3-exec-evm-demos.k"

module SRW3-AUTHZ-EVM-DEMOS
  imports SRW3-AUTHZ-EVM
  imports SRW3-EXEC-EVM-DEMOS

  // ---- debug carrier (the 1F #w3GateFDbg precedent): the authority byte
  // certificate of the CURRENT run, for the Part-6 cross-layer comparison
  syntax EthereumSimulation ::= "#w3GateGDbg"
  syntax KItem ::= "#w3DbgGBytes" "(" String ")"
  rule <k> #w3GateGDbg
        => #w3DbgGBytes( Bytes2StringX2( AzCertId( #w3AzCertOf(
                                 #w3FRec(FPSDemo, FDeclHonest, #w3FCUR, 0
                                       , LinRoot, FPayload, FTraceHonest)
                               , FPayload
                               , #w3FParRoot(FPSDemo, FDeclHonest, #w3FCUR)
                               , LinRoot, #w3ExecTrace ) ) )
                         +String ",effd=" +String
                         Bytes2StringX2( ExecTraceDigest(#w3ExecTrace) )
                         +String ",presentd=" +String
                         Bytes2StringX2( ExecTraceDigest(FTraceHonest) )
                         +String ",parentr=" +String
                         Bytes2StringX2( #w3FParRoot(FPSDemo, FDeclHonest
                                                   , #w3FCUR) )
                         +String ",consensusid=" +String
                         Bytes2StringX2( AuthzConsensusId(#w3AzChainId) )
                         +String ",execclientid=" +String
                         Bytes2StringX2( AuthzExecClientId( #w3AzChainId
                                  , ExecConfigDigest(ExecSchedCANCUN()
                                                   , ExecSpecV1()) ) ) )
        ... </k>


  // hoist: the dbg command waits behind the state carrier (the gate-rule shape)
  rule <k> #w3State(SG:Map, LN:Map, N:Int, H:Int)
           ~> ( #w3GateGDbg REST:EthereumSimulation )
        => #w3GateGDbg ~> #w3State(SG, LN, N, H) ~> REST ... </k>

endmodule
