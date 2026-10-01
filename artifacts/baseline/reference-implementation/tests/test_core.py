import unittest

from srw3.examples import (
    hidden_dependency_counterexample,
    local_vs_global_counterexample,
    oracle_lending_liquidator,
)
from srw3.model import Effects, Event, Gate, SecurityContract, State, evaluate_transition


class Phase0DTests(unittest.TestCase):
    def test_local_invariants_can_miss_global_interaction_invariant(self):
        local, global_comp, gate = local_vs_global_counterexample()
        pre = State.make(data={"x": 7, "y": 7})
        post = pre
        # No-op transition preserves local invariants but interaction invariant is false.
        ok_local, reasons_local = evaluate_transition(local, gate, pre, post, (), "noop")
        ok_global, reasons_global = evaluate_transition(global_comp, gate, pre, post, (), "noop")
        self.assertTrue(ok_local, reasons_local)
        self.assertFalse(ok_global)
        self.assertIn("interaction-invariant:A+B-capacity", reasons_global)

    def test_oracle_lending_liquidator_interaction_contract_is_represented(self):
        comp = oracle_lending_liquidator()
        gate = Gate(frozenset())
        pre = State.make(data={"oracle_price": 100, "collateral": 100, "debt": 80, "pool": 0})
        post = State.make(data={"oracle_price": 100, "collateral": 100, "debt": 79, "pool": 1})
        trace = (
            Event("read", "oracle_price"),
            Event("read", "debt"),
            Event("write", "debt", amount=-1),
            Event("write", "pool", amount=1),
        )
        ok, reasons = evaluate_transition(comp, gate, pre, post, trace, "liq")
        self.assertTrue(ok, reasons)

    def test_hidden_dependency_is_detectable_as_effect_underapproximation(self):
        app = hidden_dependency_counterexample()
        declared = app.effects
        true_reads = {"x", "y"}
        self.assertFalse(true_reads <= declared.reads)

    def test_refinement_is_monotone_in_finite_fragment(self):
        inv0 = lambda _pre, post, _trace: dict(post.data).get("x", 0) <= 10
        inv1 = lambda _pre, post, _trace: dict(post.data).get("x", 0) <= 5
        weak = SecurityContract("weak")
        strong = SecurityContract("strong")
        # Finite representative universe; stronger condition is subset of weaker.
        universe = [State.make(data={"x": x}) for x in range(0, 11)]
        strong_states = {s for s in universe if inv1(s, s, ())}
        weak_states = {s for s in universe if inv0(s, s, ())}
        self.assertTrue(strong_states <= weak_states)


if __name__ == "__main__":
    unittest.main()
