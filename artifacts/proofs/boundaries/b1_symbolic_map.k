// B1 — Boundary 1 minimal reproduction (Phase 1A, Part V.1):
// recursive function evaluation over symbolic constructor-free Maps.
//
// Haskell-backend issue recorded in Phase 0-D: recursive lookups/folds over
// symbolic constructor-free Maps do not reduce sufficiently for the proof
// packaging; goals keep unevaluated function applications as residuals.
//
// B1-SYM  : the Map is pinned by an ==Map premise (the reduction question is
//           whether the backend propagates the pin into the recursion).
// B1-FREE : fully symbolic constructor-free Map (the canonical stuck shape;
//           no backend can evaluate an unbounded fold — the residual IS the
//           expected scientific result).
module B1-MAP
  imports DOMAINS

  syntax Int ::= "sum" "(" m:Map ")" [function, total]

  rule sum(.Map) => 0
  rule sum(K:Int |-> V:Int M:Map) => V +Int sum(M) [owise]

endmodule

module B1-CLAIMS
  imports B1-MAP

  claim // B1-SYM: pinned-shape symbolic Map — does the backend propagate the
        // ==Map pin into the recursive fold? (concrete answer: 10+20=30)
    <k> sum(M:Map) ==Int 30 => true </k>
    requires M ==K (1 |-> 10 2 |-> 20)
    [label(B1-SYM)]

  claim // B1-FREE: constructor-free symbolic Map (expected residual class:
        // the fold application stays unevaluated in the goal)
    <k> sum(M:Map) ==Int S:Int => true </k>
    [label(B1-FREE)]

endmodule
