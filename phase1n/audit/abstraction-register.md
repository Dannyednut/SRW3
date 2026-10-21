# SRW3 Phase 1N — the abstraction register (the declared boundaries)

**Status:** the register of record for the 1N simulation architecture.
Level III only; no consensus-integration claim.

## A1. What the abstract machine ABSTRACTS AWAY

| Concrete (M3) component | Abstract (AM3) counterpart | Where the content lives |
|---|---|---|
| Hash-class values (R3 root, anchor, receipt digests, block commitments) | ABSENT from `AState` | The SIM shape claims carry every hash-class equality as the concrete machine's OWN guard hypothesis; no hash equality is ever evaluated abstractly (B5 structurally avoided) |
| The init guard (root match + catalog WF + digest bindings + `SafeJ(P,.Map)`) | the `aInitJ(aOkT/aOkF)` bit | `SIM-INIT-ACCEPT` (PROVED) takes the full concrete guard as the witness; `SIM-INIT-REFUSE` covers the failure class |
| The exec/gate/commit guard outcomes | the per-class constructor bits | `SIM-EXEC-*`/`SIM-GATE-*`/`SIM-COMMIT-ACCEPT` take the concrete guards verbatim; `SIM-NEG-*` prove the mis-presentation is unreachable |
| `SafeJ(P, S)` over `<jstate>` | the `safe` bookkeeping bit | SET only by the abstract init (whose concrete guard COMPUTED SafeJ on the genesis) and carried by the accept-commit (whose concrete guard COMPUTED SafeJ on the derived post-state, presented as the second bit). SafeJ is NEVER assumed in its own induction step (the 1L discipline). `absStructOf` clears the bit in the simulation algebra — the algebra states the STRUCTURAL agreement only |
| Unsupported vs bounds exec refusals | the single `adExecRefuse` class | the diagnostic CLASSES are the abstraction; the concrete diagnostics are machine-derived |
| The committed-block CONTENT in `<jlineage>` slots | absent (only counts/slot arithmetic) | the block-level content is the concrete machine's own; the slot/pool arithmetic is the algebra's subject |
| The receipt pool CONTENT | the cardinalities `cntG`/`cntE` | `SIM-ALG-*` (9/9 PROVED) mechanize the counting arithmetic over symbolic pools |

## A2. What the abstraction does NOT cover (the honest gaps)

1. **The safe bit is bookkeeping, not a SafeJ re-statement.**  The abstract
   theorem proves the bookkeeping never enables an unsafe commit; that a
   concrete commit's derived post-state ACTUALLY satisfies `SafeJ` is the
   concrete guard's own computation (hypothesis-level, concretely decidable
   on LLVM/Python, stuck-symbolic on hs — the 1L circularity class,
   unchanged).  The transfer `absSafe(s) -> SafeJ(P, concrete-state)` is
   therefore NOT a mechanized theorem; it is the declared conformance
   obligation discharged per-execution by the concrete guard.
2. **The symbolic-command dispatch boundary.**  `absStepJ` cannot dispatch
   on a symbolic command (K function equations match by pattern); the
   universal composition over fully-symbolic programs does not close in one
   kprove claim (`ABS-UNIV-STEP`/`-TAIL`/`ABS-PREFIX-SAFE` residuals of
   record).  The mechanized composition evidence: the branch-complete
   preservation family (every class x bits x branch over ALL field values)
   + the concrete-pipeline composition theorems (`ABS-RUN-*`, real
   multi-step unfolding) + the exhaustive Python sweep.
3. **The B5' search-grind on the mint classes.**  `SIM-EXEC-MINT` and
   `SIM-GATE-MINT` retain `FAILED(rc=124)`: the concrete mint rewrite
   eagerly expands the evaluator cascade inside the receipt (the 1M B5'
   boundary, now witnessed for the simulation claims).  Their counting
   correspondence IS mechanized (`SIM-ALG-EXEC-MINT`/`-GATE-MINT`), and the
   accept class PROVED (`SIM-COMMIT-ACCEPT`) via the machine's own
   map-update destination form (the B2 idiom bypassed — see
   audit/sim-shape-join.md).
