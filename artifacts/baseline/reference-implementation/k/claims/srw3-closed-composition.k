module SRW3-CLOSED-COMPOSITION
  imports SRW3-SEMANTICS

  // Abstract claim target. The executable finite proof oracle lives in Python;
  // this module is the K target for the same semantic statement.
  //
  // Closed_P(A) && InitSafe_P(A) && GateComplete_P(A) && ContractSound_P(A)
  // ==> ReachCommitted(A) subset Safe(P)

endmodule
