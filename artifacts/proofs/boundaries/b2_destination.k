// B2 — Boundary 2 minimal reproduction (Phase 1A, Part V.2):
// Kore destination-variable linkage when CHANGED cells are omitted from the
// claim destination (Phase-0 discovery: residuals like ?YB remain when the
// implication check cannot link the destination; explicit ?-existential
// destination cells over ALL changing cells close the claim).
module B2-DEST
  imports INT
  imports LIST

  syntax KItem ::= step()
  configuration <b2> <k> $PGM:K </k> <st> 0 </st> <log> .List </log> </b2>

  rule <k> step() => .K </k>
       <st> N:Int => N +Int 1 </st>
       <log> L:List => L ListItem(N:Int) </log>

endmodule

module B2-CLAIMS
  imports B2-DEST

  claim // B2-OMIT: destination mentions ONLY <k> — the changing cells are
        // omitted. EXPECTED (Haskell): stuck residual with dangling ?-vars.
    <k> step() => .K </k>
    [label(B2-OMIT)]

  claim // B2-EXPL: explicit existential destination cells over ALL changing
        // cells. EXPECTED (Haskell): closes.
    <k> step() => .K </k>
    <st> N:Int => ?N2:Int </st>
    <log> L:List => ?L2:List </log>
    [label(B2-EXPL)]

endmodule
