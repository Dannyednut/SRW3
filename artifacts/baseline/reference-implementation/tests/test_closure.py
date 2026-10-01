import unittest

from srw3.closure import security_closed
from srw3.examples import hidden_dependency_counterexample, local_vs_global_counterexample
from srw3.model import State


class ClosureTests(unittest.TestCase):
    def test_hidden_dependency_breaks_effect_completeness(self):
        app = hidden_dependency_counterexample()
        # True implementation reads x and y, declared abstraction only says x.
        comp = __import__("srw3.model", fromlist=["Composition", "SecurityHypergraph"]).Composition(
            (app,), __import__("srw3.model", fromlist=["SecurityHypergraph"]).SecurityHypergraph()
        )
        result = security_closed(
            comp,
            {"A": (frozenset({"x", "y"}), frozenset({"out"}))},
            (),
            (frozenset({"out"}),),
        )
        self.assertFalse(result.effects_complete)
        self.assertFalse(result.closed)
        self.assertIn("effects", result.failures())

    def test_local_only_composition_is_not_interaction_complete_when_edge_required(self):
        local, _, _ = local_vs_global_counterexample()
        result = security_closed(
            local,
            {"A": (frozenset({"x"}), frozenset({"x"})), "B": (frozenset({"y"}), frozenset({"y"}))},
            (frozenset({"A", "B"}),),
            (frozenset({"x", "y"}),),
        )
        self.assertFalse(result.interaction_complete)

    def test_closed_counterexample_has_complete_interaction_contract(self):
        _, comp, _ = local_vs_global_counterexample()
        result = security_closed(
            comp,
            {"A": (frozenset({"x"}), frozenset({"x"})), "B": (frozenset({"y"}), frozenset({"y"}))},
            (frozenset({"A", "B"}),),
            (frozenset({"x", "y"}),),
        )
        self.assertTrue(result.interaction_complete)
        self.assertTrue(result.contract_complete)
        self.assertTrue(result.closed)


if __name__ == "__main__":
    unittest.main()
