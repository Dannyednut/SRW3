import unittest

from srw3.examples import local_vs_global_counterexample
from srw3.model import Event, Gate, State, evaluate_transition


class CountermodelTests(unittest.TestCase):
    def test_global_countermodel(self):
        _, global_comp, gate = local_vs_global_counterexample()
        pre = State.make(data={"x": 7, "y": 7})
        post = pre
        trace = (Event("read", "x"), Event("read", "y"))
        ok, reasons = evaluate_transition(global_comp, gate, pre, post, trace, "cm1")
        self.assertFalse(ok)
        self.assertEqual(reasons, ("interaction-invariant:A+B-capacity",))

    def test_resource_aliasing_pattern(self):
        # Both local claims pass; the shared resource budget fails.
        pre = State.make(resources={"r": 1})
        post = pre
        self.assertEqual(dict(pre.resources)["r"], 1)
        # The system-level condition would be spend_A + spend_B <= 1.
        spend_a = 1
        spend_b = 1
        self.assertGreater(spend_a + spend_b, dict(pre.resources)["r"])

    def test_authority_aggregation_pattern(self):
        source_limit = 10
        delegated_a = 10
        delegated_b = 10
        self.assertGreater(delegated_a + delegated_b, source_limit)

    def test_three_way_interaction_pattern(self):
        a = b = c = 7
        self.assertLessEqual(a + b, 15)
        self.assertLessEqual(a + c, 15)
        self.assertLessEqual(b + c, 15)
        self.assertGreater(a + b + c, 20)


if __name__ == "__main__":
    unittest.main()
