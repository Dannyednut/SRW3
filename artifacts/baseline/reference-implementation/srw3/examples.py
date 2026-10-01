from __future__ import annotations

from .model import (
    Application,
    Composition,
    Effects,
    Event,
    Gate,
    InteractionContract,
    Invariant,
    SecurityContract,
    SecurityHypergraph,
    State,
    Trace,
    evaluate_transition,
)


def _state_value(name: str, s: State) -> int:
    return dict(s.data).get(name, 0)


def simple_increment_app(name: str, variable: str, limit: int) -> Application:
    inv = Invariant(
        f"{name}.{variable}-within-limit",
        lambda _pre, post, _trace: _state_value(variable, post) <= limit,
        scope=frozenset({variable}),
    )

    def step(s: State):
        post = s.with_data(**{variable: _state_value(variable, s) + 1})
        return post, Trace((Event("write", variable, amount=1),)), f"{name}:inc", ()

    return Application(
        name=name,
        contract=SecurityContract(name, (inv,)),
        effects=Effects(reads=frozenset({variable}), writes=frozenset({variable})),
        transition=step,
    )


def local_vs_global_counterexample():
    a = simple_increment_app("A", "x", 10)
    b = simple_increment_app("B", "y", 10)
    interaction = Invariant(
        "A+B-capacity",
        lambda _pre, post, _trace: _state_value("x", post) + _state_value("y", post) <= 10,
        scope=frozenset({"x", "y"}),
    )
    c_local = Composition((a, b), SecurityHypergraph())
    c_global = Composition((a, b), SecurityHypergraph((InteractionContract(frozenset({"A", "B"}), (interaction,)),)))
    gate = Gate(frozenset())
    return c_local, c_global, gate


def oracle_lending_liquidator():
    oracle_inv = Invariant(
        "oracle.rooted-price",
        lambda _pre, post, _trace: _state_value("oracle_price", post) >= 0,
        scope=frozenset({"oracle_price"}),
    )
    lending_inv = Invariant(
        "lending.collateral-ge-debt",
        lambda _pre, post, _trace: _state_value("collateral", post) >= _state_value("debt", post),
        scope=frozenset({"collateral", "debt"}),
    )
    dex_inv = Invariant(
        "dex.conservation",
        lambda pre, post, _trace: _state_value("pool", post) >= 0 and _state_value("pool", post) <= _state_value("pool", pre) + 10,
        scope=frozenset({"pool"}),
    )

    def oracle_step(s: State):
        post = s.with_data(oracle_price=100)
        return post, Trace((Event("input", "oracle", amount=100),)), "oracle:set", ()

    def lending_step(s: State):
        post = s.with_data(collateral=100, debt=80, oracle_price=_state_value("oracle_price", s))
        return post, Trace((Event("read", "oracle_price"), Event("write", "collateral"), Event("write", "debt"))), "lending:borrow", ()

    def liquidator_step(s: State):
        post = s.with_data(pool=min(10, _state_value("pool", s) + 1), debt=max(0, _state_value("debt", s) - 1))
        return post, Trace((Event("read", "debt"), Event("write", "pool"), Event("write", "debt"))), "liquidator:liquidate", ()

    oracle = Application("Oracle", SecurityContract("Oracle", (oracle_inv,)), Effects(writes=frozenset({"oracle_price"})), oracle_step)
    lending = Application("Lending", SecurityContract("Lending", (lending_inv,)), Effects(reads=frozenset({"oracle_price"}), writes=frozenset({"collateral", "debt"})), lending_step)
    liquidator = Application("Liquidator", SecurityContract("Liquidator", (dex_inv,)), Effects(reads=frozenset({"debt"}), writes=frozenset({"pool", "debt"})), liquidator_step)

    price_link = Invariant(
        "oracle-lending.price-lineage",
        lambda _pre, post, _trace: _state_value("oracle_price", post) == 100,
        scope=frozenset({"oracle_price", "collateral", "debt"}),
    )
    liquidation_bound = Invariant(
        "lending-liquidator.debt-bound",
        lambda pre, post, _trace: _state_value("debt", post) >= 0 and _state_value("debt", post) <= _state_value("debt", pre),
        scope=frozenset({"debt", "pool"}),
    )
    tri = Invariant(
        "oracle-lending-liquidator.settlement-coherence",
        lambda _pre, post, _trace: (_state_value("oracle_price", post) == 100 and _state_value("debt", post) >= 0),
        scope=frozenset({"oracle_price", "debt", "pool"}),
    )
    h = SecurityHypergraph(
        (
            InteractionContract(frozenset({"Oracle", "Lending"}), (price_link,)),
            InteractionContract(frozenset({"Lending", "Liquidator"}), (liquidation_bound,)),
            InteractionContract(frozenset({"Oracle", "Lending", "Liquidator"}), (tri,)),
        )
    )
    return Composition((oracle, lending, liquidator), h)


def hidden_dependency_counterexample():
    """Declared footprint omits y, even though output depends on it."""
    inv = Invariant("output-bound", lambda _pre, post, _trace: _state_value("out", post) <= 10)
    def step(s: State):
        x = _state_value("x", s)
        y = _state_value("y", s)
        post = s.with_data(out=x + y)
        return post, Trace((Event("read", "x"), Event("read", "y"), Event("write", "out"))), "A:compute", ()
    app = Application("A", SecurityContract("A", (inv,)), Effects(reads=frozenset({"x"}), writes=frozenset({"out"})), step)
    return app


def temporal_revocation_counterexample():
    inv = Invariant(
        "revocation-before-use",
        lambda _pre, _post, trace: all(
            e.kind != "use" or any(prev.kind == "revoke" and prev.subject == e.subject and prev.timestamp <= e.timestamp for prev in trace.events[: trace.events.index(e)])
            for e in trace.events
        ),
    )
    contract = SecurityContract("Auth", (inv,))
    app = Application("Auth", contract, Effects(temporal=frozenset({"revoke-before-use"})), lambda s: None)  # type: ignore[arg-type]
    return app
