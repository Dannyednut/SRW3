from __future__ import annotations

from dataclasses import dataclass, field
from typing import Callable, FrozenSet, Iterable, Mapping, Optional, Sequence, Tuple

StateTuple = Tuple[Tuple[str, int], ...]
ResourceTuple = Tuple[Tuple[str, int], ...]


def _canon_map(m: Mapping[str, int]) -> Tuple[Tuple[str, int], ...]:
    return tuple(sorted((str(k), int(v)) for k, v in m.items()))


def _dict(t: StateTuple | ResourceTuple) -> dict[str, int]:
    return dict(t)


@dataclass(frozen=True)
class State:
    """Small finite-state abstraction used for the Phase-0 reference oracle."""

    data: StateTuple = ()
    resources: ResourceTuple = ()
    auth: StateTuple = ()

    @classmethod
    def make(
        cls,
        data: Mapping[str, int] | None = None,
        resources: Mapping[str, int] | None = None,
        auth: Mapping[str, int] | None = None,
    ) -> "State":
        return cls(_canon_map(data or {}), _canon_map(resources or {}), _canon_map(auth or {}))

    def with_data(self, **updates: int) -> "State":
        d = _dict(self.data)
        d.update(updates)
        return State.make(d, _dict(self.resources), _dict(self.auth))

    def with_resources(self, **updates: int) -> "State":
        r = _dict(self.resources)
        r.update(updates)
        return State.make(_dict(self.data), r, _dict(self.auth))


@dataclass(frozen=True)
class Event:
    kind: str
    subject: str
    target: str = ""
    amount: int = 0
    timestamp: int = 0


@dataclass(frozen=True)
class Trace:
    events: Tuple[Event, ...] = ()

    def append(self, *events: Event) -> "Trace":
        return Trace(self.events + tuple(events))


Predicate = Callable[[State, State, Trace], bool]
LineagePredicate = Callable[["Lineage"], bool]


@dataclass(frozen=True)
class Invariant:
    name: str
    predicate: Predicate
    scope: FrozenSet[str] = frozenset()

    def holds(self, pre: State, post: State, trace: Trace) -> bool:
        return bool(self.predicate(pre, post, trace))


@dataclass(frozen=True)
class Lineage:
    parents: Tuple[str, ...] = ()
    transition_ids: Tuple[str, ...] = ()
    roots: Tuple[str, ...] = ()

    def append(self, state_id: str, transition_id: str, root_ids: Sequence[str]) -> "Lineage":
        return Lineage(
            parents=self.parents + (state_id,),
            transition_ids=self.transition_ids + (transition_id,),
            roots=self.roots + tuple(root_ids),
        )


@dataclass(frozen=True)
class RootEvidence:
    root_id: str
    datum: str
    valid: bool


@dataclass(frozen=True)
class SecurityContract:
    name: str
    invariants: Tuple[Invariant, ...] = ()
    required_inputs: FrozenSet[str] = frozenset()
    owned_resources: FrozenSet[str] = frozenset()
    capabilities: FrozenSet[str] = frozenset()
    assumed_apps: FrozenSet[str] = frozenset()

    def holds(self, pre: State, post: State, trace: Trace) -> bool:
        return all(inv.holds(pre, post, trace) for inv in self.invariants)

    def behavior_subset_of(self, other: "SecurityContract", universe: Iterable[State]) -> bool:
        """Finite-fragment refinement check: stronger contract admits no extra states."""
        for s in universe:
            if self.holds(s, s, Trace()) and not other.holds(s, s, Trace()):
                return False
        return True


@dataclass(frozen=True)
class Effects:
    reads: FrozenSet[str] = frozenset()
    writes: FrozenSet[str] = frozenset()
    owns: FrozenSet[str] = frozenset()
    capabilities: FrozenSet[str] = frozenset()
    external_inputs: FrozenSet[str] = frozenset()
    temporal: FrozenSet[str] = frozenset()

    def footprint_union(self, other: "Effects") -> "Effects":
        return Effects(
            reads=self.reads | other.reads,
            writes=self.writes | other.writes,
            owns=self.owns | other.owns,
            capabilities=self.capabilities | other.capabilities,
            external_inputs=self.external_inputs | other.external_inputs,
            temporal=self.temporal | other.temporal,
        )


@dataclass(frozen=True)
class Application:
    name: str
    contract: SecurityContract
    effects: Effects
    transition: Callable[[State], Optional[Tuple[State, Trace, str, Tuple[RootEvidence, ...]]]]


@dataclass(frozen=True)
class InteractionContract:
    participants: FrozenSet[str]
    invariants: Tuple[Invariant, ...]
    required_inputs: FrozenSet[str] = frozenset()

    def holds(self, pre: State, post: State, trace: Trace) -> bool:
        return all(inv.holds(pre, post, trace) for inv in self.invariants)


@dataclass(frozen=True)
class SecurityHypergraph:
    edges: Tuple[InteractionContract, ...] = ()

    def relevant(self, participants: FrozenSet[str]) -> Tuple[InteractionContract, ...]:
        return tuple(e for e in self.edges if e.participants <= participants)


@dataclass(frozen=True)
class Composition:
    applications: Tuple[Application, ...]
    hypergraph: SecurityHypergraph

    @property
    def names(self) -> FrozenSet[str]:
        return frozenset(a.name for a in self.applications)

    def local_invariants(self) -> Tuple[Invariant, ...]:
        result = []
        for app in self.applications:
            result.extend(app.contract.invariants)
        return tuple(result)

    def interaction_invariants(self) -> Tuple[Invariant, ...]:
        result = []
        for edge in self.hypergraph.relevant(self.names):
            result.extend(edge.invariants)
        return tuple(result)


class GateError(ValueError):
    pass


@dataclass(frozen=True)
class Gate:
    roots: FrozenSet[str]

    def evaluate(
        self,
        composition: Composition,
        pre: State,
        post: State,
        trace: Trace,
        lineage: Lineage,
        root_evidence: Sequence[RootEvidence],
    ) -> tuple[bool, tuple[str, ...]]:
        reasons: list[str] = []

        if not composition.applications:
            reasons.append("empty composition")

        # Root validation.
        for evidence in root_evidence:
            if evidence.root_id not in self.roots or not evidence.valid:
                reasons.append(f"invalid-root:{evidence.root_id}")

        # Local contracts.
        for inv in composition.local_invariants():
            if not inv.holds(pre, post, trace):
                reasons.append(f"local-invariant:{inv.name}")

        # Interaction contracts.
        for inv in composition.interaction_invariants():
            if not inv.holds(pre, post, trace):
                reasons.append(f"interaction-invariant:{inv.name}")

        # Minimal lineage sanity: every transition record must have a parent and id.
        if len(lineage.parents) != len(lineage.transition_ids):
            reasons.append("lineage-shape")
        if any(not x for x in lineage.parents + lineage.transition_ids):
            reasons.append("lineage-empty-field")

        return (not reasons, tuple(reasons))


def enumerate_reachable(
    initial: State,
    composition: Composition,
    gate: Gate,
    max_steps: int = 4,
) -> tuple[FrozenSet[State], tuple[tuple[State, tuple[str, ...]], ...]]:
    """Explore deterministic one-step application transitions in a finite model."""
    reached: set[State] = {initial}
    frontier: list[tuple[State, int]] = [(initial, 0)]
    violations: list[tuple[State, tuple[str, ...]]] = []

    while frontier:
        current, depth = frontier.pop()
        if depth >= max_steps:
            continue
        if len(reached) > 10_000:
            raise RuntimeError("finite reference exploration exceeded 10,000 states")

        for app in composition.applications:
            out = app.transition(current)
            if out is None:
                continue
            post, trace, transition_id, roots = out
            lineage = Lineage((str(hash(current)),), (transition_id,), tuple(r.root_id for r in roots))
            ok, reasons = gate.evaluate(composition, current, post, trace, lineage, roots)
            if ok:
                if post not in reached:
                    reached.add(post)
                    frontier.append((post, depth + 1))
            else:
                violations.append((post, reasons))

    return frozenset(reached), tuple(violations)


def evaluate_transition(
    composition: Composition,
    gate: Gate,
    pre: State,
    post: State,
    trace: Trace,
    transition_id: str,
    roots: Sequence[RootEvidence] = (),
) -> tuple[bool, tuple[str, ...]]:
    lineage = Lineage((str(hash(pre)),), (transition_id,), tuple(r.root_id for r in roots))
    return gate.evaluate(composition, pre, post, trace, lineage, roots)
