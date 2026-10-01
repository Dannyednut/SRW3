from __future__ import annotations

from dataclasses import dataclass
from typing import Callable, Iterable, Sequence

from .closure import ClosureResult
from .model import Application, Composition, Gate, State, Trace, evaluate_transition


@dataclass(frozen=True)
class ProofResult:
    theorem: str
    proved: bool
    checked_states: int
    checked_transitions: int
    counterexamples: tuple[tuple[State, State, tuple[str, ...]], ...] = ()


def global_invariants_hold(composition: Composition, pre: State, post: State, trace: Trace) -> bool:
    return all(inv.holds(pre, post, trace) for inv in composition.local_invariants() + composition.interaction_invariants())


def prove_one_step_inductive_safety(
    states: Sequence[State],
    composition: Composition,
    gate: Gate,
) -> ProofResult:
    """Finite proof oracle for the induction step.

    For every state that already satisfies all modeled invariants, execute every
    application transition from that state and require admitted results to also
    satisfy the complete modeled security property.
    """
    cex: list[tuple[State, State, tuple[str, ...]]] = []
    transitions = 0

    for pre in states:
        # The theorem is conditional on a safe current state.
        if not global_invariants_hold(composition, pre, pre, Trace()):
            continue
        for app in composition.applications:
            out = app.transition(pre)
            if out is None:
                continue
            post, trace, transition_id, roots = out
            transitions += 1
            ok, reasons = evaluate_transition(composition, gate, pre, post, trace, transition_id, roots)
            if ok and not global_invariants_hold(composition, pre, post, trace):
                cex.append((pre, post, reasons + ("post-state-not-safe",)))
            elif not ok and global_invariants_hold(composition, pre, post, trace):
                # Rejection of a safe state is allowed; this is a liveness/precision
                # issue, not a soundness failure, so it is intentionally not a cex.
                pass

    return ProofResult(
        theorem="SRW3 finite one-step inductive safety",
        proved=not cex,
        checked_states=len(states),
        checked_transitions=transitions,
        counterexamples=tuple(cex),
    )


def prove_finite_closed_composition(
    states: Sequence[State],
    composition: Composition,
    gate: Gate,
    closure: ClosureResult,
) -> ProofResult:
    if not closure.closed:
        return ProofResult(
            theorem="SRW3 closed-composition safety",
            proved=False,
            checked_states=0,
            checked_transitions=0,
            counterexamples=((states[0], states[0], tuple("closure:" + x for x in closure.failures())),) if states else (),
        )
    return prove_one_step_inductive_safety(states, composition, gate)
