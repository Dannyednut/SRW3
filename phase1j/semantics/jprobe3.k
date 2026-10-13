requires "../proofs/j_fixtures.k"

module JPROBE3
  imports SRW3CLOSURE-J-FIXTURES

  syntax PCmdJI ::= "xprobe3"
  rule <k> xprobe3
        => "pld=" +String Bool2StringX(JPayloadDigestJ(XProg0) ==K jbPayloadDOf(XB0))
           ... </k>
endmodule