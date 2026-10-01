module SRW3-SYNTAX
  imports INT-SYNTAX
  imports STRING-SYNTAX
  imports BOOL-SYNTAX
  imports MAP-SYNTAX
  imports SET-SYNTAX
  imports LIST-SYNTAX

  syntax AppId
  syntax RootId
  syntax TransitionId
  syntax Event
  syntax Tau
  syntax Trace
  syntax RootSet
  syntax HyperGraph
  syntax ContractRegistry

  syntax AppId ::= String
  syntax RootId ::= String
  syntax TransitionId ::= String
  syntax Event ::= event(String, String, Int)
  syntax Tau ::= tau(AppId, TransitionId)
  syntax Trace ::= List{Event, ","}
  syntax RootSet ::= Set
  syntax HyperGraph ::= Set
  syntax ContractRegistry ::= Map

  syntax Bool ::= gateOk(Map, Map, List, Set, Set, Map) [function]
  syntax Bool ::= rootOk(Set, String, String) [function]

endmodule

module SRW3-CONFIG
  imports SRW3-SYNTAX

  configuration
    <srw3>
      <k> $PGM:Tau </k>
      <committed> .Map </committed>
      <shadow> .Map </shadow>
      <trace> .List </trace>
      <lineage> .List </lineage>
      <roots> .Set </roots>
      <contracts> .Map </contracts>
      <hypergraph> .Set </hypergraph>
      <gate> false </gate>
    </srw3>
endmodule

module SRW3-SEMANTICS
  imports SRW3-CONFIG
  imports INT
  imports BOOL
  imports MAP
  imports SET
  imports LIST

  // Abstract Phase-0 transition skeleton.
  // The concrete EVM execution is supplied by KEVM in the next binding step.
  rule <srw3>
         <k> tau(A, T) => .K </k>
         <committed> C => C </committed>
         <shadow> S => S </shadow>
         <trace> TR => TR </trace>
         <lineage> L => L </lineage>
         <roots> R </roots>
         <contracts> M </contracts>
         <hypergraph> H </hypergraph>
         <gate> _ => true </gate>
       </srw3>
       requires gateOk(C, S, TR, R, H, M)

  rule <srw3>
         <k> tau(A, T) => .K </k>
         <committed> C </committed>
         <shadow> S </shadow>
         <trace> TR </trace>
         <lineage> L </lineage>
         <roots> R </roots>
         <contracts> M </contracts>
         <hypergraph> H </hypergraph>
         <gate> _ => false </gate>
       </srw3>
       requires notBool gateOk(C, S, TR, R, H, M)

endmodule
