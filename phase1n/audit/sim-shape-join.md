# SRW3 Phase 1N — audit: the two-leg simulation join

The simulation correspondence is mechanized as TWO legs over a single
definition (SRW3N-ABS, one kompile):

* **Leg B (SIM-*)**: claims over the CONCRETE M4 configuration; each takes
  the machine's OWN guard as the hypothesis and pins the machine's OWN
  post-shape in the destination (syntactic matching; no hash evaluation).
* **Leg A (SIM-ALG-*)**: the counting algebra over the SAME shapes:
  simJ(post-shape) ==K absStructOf(absStepJ(simJ(pre-shape), cmd-class)).

The join: Leg B proves the concrete step produces the pinned shape; Leg A
proves the projections of those shapes satisfy the abstract step algebra.
The shapes are shared by construction (Leg A's patterns are the same
fragments as Leg B's destinations).  Recorded shape-file sha256s:

```
552032152392744df309cbce1349143715af86b93d9fbf952070ad313835748e d653f828caa8bffe411971df0d3a149b619c51156f5b293990fd22793f9eefc0 
```

Proved legs (this commit): Leg B = SIM-INIT-ACCEPT, SIM-INIT-REFUSE,
SIM-COMMIT-ACCEPT, SIM-GATE-REFUSE, SIM-COMMIT-REJECT,
SIM-EXEC-SOURCE-DISPATCH; Leg A = all 9 SIM-ALG-*.  The mint-shape legs
(SIM-EXEC-MINT, SIM-GATE-MINT) retain FAILED(rc=124) — the B5' cascade
expansion — with the counting correspondence carried by Leg A and the
concrete execution evidence by the frozen M2/M3 LLVM transcripts.

The B2 bypass: SIM-COMMIT-ACCEPT's destination states the block write in
the machine's OWN map-update form (`.Map[jbSlotOf(B) <- B]`) — the
destination-constraint idiom that blocked the 1L/1M commit claims (B2) is
bypassed by formulation, and the bypass is itself auditable (the
destination is the rule's own RHS with L3 := .Map).
