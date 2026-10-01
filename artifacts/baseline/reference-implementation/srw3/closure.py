from __future__ import annotations

from dataclasses import dataclass
from typing import Callable, FrozenSet, Iterable

from .model import Application, Composition, Invariant


@dataclass(frozen=True)
class ClosureResult:
    effects_complete: bool
    interaction_complete: bool
    contract_complete: bool
    lineage_complete: bool

    @property
    def closed(self) -> bool:
        return all((self.effects_complete, self.interaction_complete, self.contract_complete, self.lineage_complete))

    def failures(self) -> tuple[str, ...]:
        checks = {
            "effects": self.effects_complete,
            "interaction": self.interaction_complete,
            "contract": self.contract_complete,
            "lineage": self.lineage_complete,
        }
        return tuple(name for name, ok in checks.items() if not ok)


def effect_complete(app: Application, true_reads: FrozenSet[str], true_writes: FrozenSet[str]) -> bool:
    """Sound abstraction requires an over-approximation of true security effects."""
    return true_reads <= app.effects.reads and true_writes <= app.effects.writes


def interaction_complete(composition: Composition, required_participants: Iterable[FrozenSet[str]]) -> bool:
    edges = {edge.participants for edge in composition.hypergraph.edges}
    return all(p in edges for p in required_participants)


def contract_complete(composition: Composition, required_scopes: Iterable[FrozenSet[str]]) -> bool:
    covered: set[str] = set()
    for inv in composition.local_invariants() + composition.interaction_invariants():
        covered |= set(inv.scope)
    return all(set(scope) <= covered for scope in required_scopes)


def lineage_complete(has_lineage: bool, required_dependency_count: int) -> bool:
    return has_lineage and required_dependency_count >= 0


def security_closed(
    composition: Composition,
    true_effects: dict[str, tuple[FrozenSet[str], FrozenSet[str]]],
    required_interactions: Iterable[FrozenSet[str]],
    required_scopes: Iterable[FrozenSet[str]],
    has_lineage: bool = True,
    required_dependency_count: int = 0,
) -> ClosureResult:
    apps_by_name = {a.name: a for a in composition.applications}
    effects_ok = all(
        name in apps_by_name and effect_complete(apps_by_name[name], reads, writes)
        for name, (reads, writes) in true_effects.items()
    )
    interaction_ok = interaction_complete(composition, required_interactions)
    contract_ok = contract_complete(composition, required_scopes)
    lineage_ok = lineage_complete(has_lineage, required_dependency_count)
    return ClosureResult(effects_ok, interaction_ok, contract_ok, lineage_ok)


def preserved_under_all(
    states: Iterable,
    transitions: Iterable[Callable],
    predicate: Callable,
) -> bool:
    """Finite proof oracle for inductive one-step preservation."""
    for state in states:
        if not predicate(state):
            continue
        for transition in transitions:
            out = transition(state)
            if out is None:
                continue
            post, *_ = out
            if not predicate(post):
                return False
    return True
