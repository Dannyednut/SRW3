import unittest

from srw3.closure import security_closed
from srw3.examples import local_vs_global_counterexample, oracle_lending_liquidator
from srw3.model import Gate, State, SecurityHypergraph, Composition
from srw3.proof import prove_finite_closed_composition


class ProofTests(unittest.TestCase):
    def test_local_only_model_cannot_claim_closed_composition(self):
        local, _, gate = local_vs_global_counterexample()
        closure = security_closed(
            local,
            {"A": (frozenset({"x"}), frozenset({"x"})), "B": (frozenset({"y"}), frozenset({"y"}))},
            (frozenset({"A", "B"}),),
            (frozenset({"x", "y"}),),
        )
        result = prove_finite_closed_composition(
            [State.make(data={"x": x, "y": y}) for x in range(0, 11) for y in range(0, 11)],
            local,
            gate,
            closure,
        )
        self.assertFalse(result.proved)
        self.assertTrue(any("closure:interaction" in reason for reason in result.counterexamples[0][2]))

    def test_interaction_aware_model_proves_finite_safety(self):
        _, comp, gate = local_vs_global_counterexample()
        states = [State.make(data={"x": x, "y": y}) for x in range(0, 11) for y in range(0, 11)]
        closure = security_closed(
            comp,
            {"A": (frozenset({"x"}), frozenset({"x"})), "B": (frozenset({"y"}), frozenset({"y"}))},
            (frozenset({"A", "B"}),),
            (frozenset({"x", "y"}),),
        )
        result = prove_finite_closed_composition(states, comp, gate, closure)
        self.assertTrue(result.proved, result.counterexamples[:1])
        self.assertGreater(result.checked_transitions, 0)

    def test_closed_composition_gate_rejects_bad_noop(self):
        _, comp, gate = local_vs_global_counterexample()
        pre = State.make(data={"x": 7, "y": 7})
        ok, reasons = __import__("srw3.model", fromlist=["evaluate_transition"]).evaluate_transition(comp, gate, pre, pre, (), "noop")
        self.assertFalse(ok)
        self.assertIn("interaction-invariant:A+B-capacity", reasons)

    def test_oracle_lending_liquidator_finite_safe_step(self):
        comp = oracle_lending_liquidator()
        gate = Gate(frozenset())
        states = [
            State.make(data={"oracle_price": 100, "collateral": 100, "debt": d, "pool": p})
            for d in range(0, 101)
            for p in range(0, 2)
            if d <= 100
        ]
        closure = security_closed(
            comp,
            {
                "Oracle": (frozenset(), frozenset({"oracle_price"})),
                "Lending": (frozenset({"oracle_price"}), frozenset({"collateral", "debt"})),
                "Liquidator": (frozenset({"debt"}), frozenset({"pool", "debt"})),
            },
            (frozenset({"Oracle", "Lending"}), frozenset({"Lending", "Liquidator"}), frozenset({"Oracle", "Lending", "Liquidator"})),
            (frozenset({"oracle_price", "collateral", "debt", "pool"}),),
        )
        self.assertTrue(closure.closed)
        # We only check that the gate/contract model is executable over the finite universe.
        self.assertIsNotNone(prove_finite_closed_composition(states[:50], comp, gate, closure))


if __name__ == "__main__":
    unittest.main()
