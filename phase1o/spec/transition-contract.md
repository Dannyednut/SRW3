# SRW3 Phase 1O — the transition contract (mandate §5)

**Status:** the contract of record for permitted transitions, required
invariants, and refusal conditions over the abstract machine (AM3 / R),
with the concrete M3 counterpart classes. Level III only.

## 1. The command classes (the complete partition)

Twelve ground command shapes over four constructors (the bits are the
DECLARED abstraction boundary: each bit stands for the corresponding
concrete guard class's outcome, agreed by the SIM claims — the concrete
rule's own `requires` is the witness):

| Class | Command shape(s) | Precondition (machine's own) | Effect | Committing? |
|---|---|---|---|---|
| init-accept | `aInitJ(aOkT)` | state unpinned (both flags false) | pins both flags; zeroes the counters; sets the safety bookkeeping (the concrete guard COMPUTED `SafeJ(P,.Map)`) | no |
| init-refuse | `aInitJ(aOkF)` | any | nothing (the concrete `[owise]` writes no diagnostic) | no |
| exec-mint | `aExecJ(aOkT, aSrcAuth)` | both pins | exec-receipt pool +1 | no |
| exec-source-refuse | `aExecJ(aOkT, aSrcOther)` | both pins | diagnostic ← `adSource` ONLY | no |
| exec-refuse | `aExecJ(aOkF, _)` (2 shapes) | both pins | diagnostic ← `adExecRefuse` ONLY | no |
| exec-stall | `aExecJ(_, _)` on an UNPINNED state | — | NO rule exists (M3: stuck; AM3: function-level identity; R: the `[owise]` complement — consumed, nothing written) | no |
| gate-mint | `aGateJ(aOkT)` | both pins ∧ exec-pool ≥ 1 | gate-receipt pool +1 | no |
| gate-refuse | `aGateJ(aOkF)` | any | diagnostic ← `adGate` ONLY (the M3 Workstream-C explicit refusal) | no |
| commit-accept | `aCommitJ(aOkT, aOkT)` | both pins ∧ gate-pool ≥ 1 ∧ exec-pool ≥ 1 | both pools −1; slot +1; bookkeeping carried (the concrete guard COMPUTED `SafeJ` on the derived post) | **YES — the only one** |
| commit-reject | `aCommitJ(_, _)` (3 other shapes) | any | NOTHING (the concrete reject writes no diagnostic, consumes nothing) | no |

The partition is exhaustive by construction over the twelve shapes (the
R variant's twelve rules + the `[owise]` complement; the AM3 variant's
four rules + the `[owise]` per class), and non-overlapping (the negative
controls `ABS-NEG-REFUSE-ON-MINT`, and at the concrete level the MC
non-overlap control of 1M).

## 2. The required invariants (what every accepted transition must preserve)

\(Safe_F\) = `ABSInv` (see foundational-model.md §4):
1. either the state is exactly pre-init (both flags false, all counters
   zero — the diagnostic class unconstrained), or
2. the state is initialized: both flags true, both pool counters ≥ 0,
   and the safety bookkeeping held.

Plus the DISCIPLINE invariants the classes enforce (each mechanized
where marked):
* refusals write ONLY the diagnostic class (`ABS-STEP-*` exact-successor
  claims; concrete: the 1M MD partition);
* the reject class changes nothing;
* the stall class writes nothing and consumes nothing at M3 (stuck);
  at the R variant it is the disclosed non-committing stutter;
* only commit-accept advances the slot (`ABS-STEP-*`);
* mixed-pin states are outside the invariant entirely
  (`ABS-INV-EXCL-I/II`).

## 3. Refusal and rejection conditions (what MUST be refused)

A state/command pair MUST NOT commit when ANY of:
1. either receipt pool is empty or the slots mismatch (the concrete
   guard's pool conjuncts — `SIM-NEG-COMMIT-ON-STALE-SLOT` proves the
   stale-slot destination unreachable class-wise);
2. the accept guard's outcome bit is `aOkF`;
3. the COMPUTED `SafeJ` on the derived post-state fails (the second
   bit `aOkF`) — the load-bearing guard whose removal the weak-machine
   control punishes (1N Python S4: 48 invariant-breaking accepts; 1O
   K-level: `1O-NEG-WEAK-UNIV-R` FAILS as required);
4. the source is not the authorized executor
   (`SIM-NEG-MINT-ON-FORBIDDEN-SOURCE` class-wise; the abstract
   `adSource` class);
5. the command is out of the fragment's bounds or unsupported
   (`adExecRefuse`);
6. the gate preconditions fail (the explicit `adGate` refusal);
7. the configuration/catalog binding fails (init-refuse).

Missing evidence (a hash-class mismatch) manifests as 7 at the concrete
layer, under assumption A-EV.

## 4. The specialization relation (permitted variation under F)

\(A \preceq_F A'\) — application \(A'\) specializes \(A\) — is defined as:
\(A'\) presents commands from the SAME twelve-shape language with the
SAME guard semantics, in any finite order, from any state in the reachable
fragment; the guard outcomes are the concrete guards' own computed
outcomes (not presenter-chosen). Formally the specialization carries NO
power over: the class partition, the guard semantics, \(Safe_F\), the
commitment predicate, or the anchor. **This is a definitional
specialization relation, not a monotonicity theorem**: the mandate's
warning is honored — the fruit-tree intuition is NOT claimed as a
monotonicity result, and the model contains no operator by which an
application could even express a change to \(F\) (the P4
by-construction position; foundational-model.md §6).

What a specialization CANNOT do (each enforced by a classified artifact):
* cannot make an unsafe commit accepted (the bits are guard outcomes;
  the weak-presentation control fails: `ABS-NEG-UNSAFE-ACCEPT`,
  `1O-NEG-WEAK-UNIV-R`);
* cannot slip a transition outside the twelve classes (the partition is
  exhaustive; the R complement consumes without effect and is
  priority-inert for ground commands);
* cannot redefine refusal as commitment (the classes' effect columns are
  fixed definitions).

## 5. The composition rule (how the classes compose)

The run fold `absRunF` composes the classes step-by-step; the machine
runner (R variant) executes them at the rewrite level. Concrete-pipeline
composition is mechanized (`ABS-RUN-HONEST-PIPELINE[-SHAPE]`,
`ABS-RUN-REFUSAL-CHAIN` — 1N; `1O-RUN-HONEST-R`,
`1O-RUN-INIT-EXEC-R` — 1O, on the R machine). The universal composition
over symbolic programs is the open obligation (the §6 boundary — see the
final report §7/§8; the residuals of record are retained).
