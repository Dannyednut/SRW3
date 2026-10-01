# SRW3 Phase 0-D — Mechanization Implementation v1.0

This repository is the first executable implementation of the SRW3 formal core.

It contains two synchronized layers:

1. **Executable reference semantics (Python)** — fully runnable in this environment. This is the research oracle for the finite-state fragment and the countermodels.
2. **K/KEVM mechanization scaffold** — K modules organized to overlay SRW3 semantics on KEVM. K itself is not installed in the current execution environment, so K compilation is an explicit external validation step rather than being claimed here.

## Research target

The core property is:

```text
SecurityClosed_P(A)
∧ InitialSafe_P(A)
∧ GateComplete_P(A)
∧ ContractSound_P(A)
⇒ ReachCommitted(A) ⊆ Safe(P)
```

The finite reference model intentionally supports only state/transition/lineage safety properties. Hyperproperties and general liveness are out of scope for Phase 0.

## Python reference model

```bash
python -m unittest discover -s tests -v
```

The tests include:

- closed-composition safety theorem on finite state spaces;
- countermodel for local invariants that miss a global interaction invariant;
- resource-aliasing countermodel;
- authority-aggregation countermodel;
- temporal-order countermodel;
- hidden-effect completeness failure;
- three-way interaction invariant;
- locality theorem for genuinely uncoupled applications;
- security-contract refinement monotonicity on the finite fragment.

## K/KEVM

The current official KEVM repository pins K `v7.1.337` in its Nix flake (June 2026). The official K installation documentation recommends `kup`, packages, or Docker for installation. See the project-level `Makefile` targets:

```bash
make check-k
make kompile
make k-tests
```

The current environment does not have `kompile`, `krun`, or `kprove`, so these targets intentionally report that the K toolchain is missing rather than pretending compilation succeeded.

## Design rule

A model abstraction may over-approximate security-relevant effects, but it must not under-approximate them:

```text
TrueSecurityEffects_P(A) ⊆ AbstractEffects_P(A)
```

The countermodel suite treats hidden dependency under-approximation as a soundness failure.
