#!/usr/bin/env python3
# =============================================================================
# SRW3 Phase 1J — unit tests (the unittest layer over the executable mirror;
# the R3 test discipline: the machine-level invariants + the golden-vector
# conformance + determinism, as PYTHON CHECKS — never as a substitute for the
# K proof ladder).
# =============================================================================
import json
import os
import sys
import unittest

HERE = os.path.dirname(os.path.abspath(__file__))
REPO = "/".join(HERE.split("/")[:-2])
for p in (f"{REPO}/phase1j/python", f"{REPO}/python-gen", f"{REPO}/phase1e/python",
          f"{REPO}/phase1f/python", f"{REPO}/phase1g/python",
          f"{REPO}/phase1i-r1/python", f"{REPO}/phase1i-r2/python",
          f"{REPO}/phase1i-r3/python"):
    if p not in sys.path:
        sys.path.insert(0, p)

import j_model as JM  # noqa: E402
from j_model import (JApp, JResource, JHyper, JCatalog, jinv_local, jinv_sum,  # noqa: E402
                     jinv_eq, j_catalog_canon, j_catalog_root, j_app_set_root,
                     j_graph_root, j_policy_root, j_catalog_wf, exec_fragment,
                     JExecUnsupported, JExecBounds, prog_bytes, payload_digest,
                     trace_digest, footprint_keys, footprint_canon,
                     footprint_digest, state_root, state_get, safe_j, inv_holds,
                     affected_closure, JClosureExhausted, footprint_registered,
                     block_commit_j, JMachine)
import run_j_attacks as R  # noqa: E402
from r3_model import ProtoRootR3  # noqa: E402


class TestCatalogCanon(unittest.TestCase):
    def setUp(self):
        self.cat = R.fixture_catalog()
        self.cfg = R.fixture_cfg()

    def test_canon_len(self):
        self.assertEqual(len(j_catalog_canon(self.cat)), 451)

    def test_subroots_differ(self):
        c = self.cat
        self.assertNotEqual(j_app_set_root(c), j_graph_root(c))
        self.assertNotEqual(j_graph_root(c), j_policy_root(c))

    def test_catalog_root_binds_contents(self):
        c2 = R.catalog_no_he1()
        self.assertNotEqual(j_catalog_root(self.cat), j_catalog_root(c2))
        self.assertNotEqual(j_graph_root(self.cat), j_graph_root(c2))
        self.assertEqual(j_app_set_root(self.cat), j_app_set_root(c2))

    def test_wf_ok_and_failures(self):
        self.assertTrue(j_catalog_wf(self.cat))
        self.assertFalse(j_catalog_wf(R.catalog_bad_owner()))
        self.assertFalse(j_catalog_wf(R.catalog_dup_res()))

    def test_cfg_root_matches_python(self):
        self.assertEqual(ProtoRootR3(self.cfg), ProtoRootR3(R.fixture_cfg()))


class TestFragment(unittest.TestCase):
    def test_derived_pipeline(self):
        post0, eff0, t0 = exec_fragment({}, R.PROG0)
        self.assertEqual(post0, {R.ORACLE: {0: 100}})
        self.assertEqual(eff0, {R.ORACLE: {0: 100}})
        self.assertEqual(len(t0), 1)
        post1, _, t1 = exec_fragment(post0, R.PROG1)
        self.assertEqual(state_get(post1, R.K1), 100)
        self.assertEqual(state_get(post1, R.K2), 100)
        self.assertEqual(state_get(post1, R.K4), 100)
        self.assertEqual(len(t1), 2)

    def test_read_observes_threaded_state(self):
        _, _, t = exec_fragment({}, [("write", R.ORACLE, 0, 100),
                                     ("read", R.ORACLE, 0)])
        self.assertEqual(t[-1].op, 1)
        self.assertEqual(t[-1].a2, 100)

    def test_unsupported_refuses(self):
        with self.assertRaises(JExecUnsupported):
            exec_fragment({}, [("unsupported", 96)])
        with self.assertRaises(JExecUnsupported):
            exec_fragment({}, [("write", R.ORACLE, 0, 1), ("unsupported", 8),
                               ("write", R.ORACLE, 1, 2)])

    def test_bounds_refuse(self):
        with self.assertRaises(JExecBounds):
            exec_fragment({}, [("write", 1 << 32, 0, 1)])
        with self.assertRaises(JExecBounds):
            exec_fragment({}, [("write", R.ORACLE, 0, 1 << 64)])

    def test_footprint_first_occurrence(self):
        _, _, t = exec_fragment({}, [("write", R.LENDING, 0, 100),
                                     ("write", R.ORACLE, 0, 5),
                                     ("write", R.LENDING, 0, 7)])
        ks = footprint_keys(t)
        self.assertEqual(ks, [R.K2, R.K1])

    def test_reorder_changes_digests(self):
        _, _, t1 = exec_fragment({}, R.PROG1)
        _, _, t2 = exec_fragment({}, list(reversed(R.PROG1)))
        self.assertNotEqual(trace_digest(t1), trace_digest(t2))
        self.assertNotEqual(footprint_canon(t1), footprint_canon(t2))


class TestSafety(unittest.TestCase):
    def setUp(self):
        self.cat = R.fixture_catalog()
        self.post0, _, _ = exec_fragment({}, R.PROG0)
        self.post1, _, _ = exec_fragment(self.post0, R.PROG1)
        self.postu, _, _ = exec_fragment(self.post1, R.PROG_UNSAFE)
        self.postg, _, _ = exec_fragment(self.post1, R.PROG_GLOBAL)

    def test_genesis_safe(self):
        self.assertTrue(safe_j(self.cat, {}))

    def test_honest_posts_safe(self):
        self.assertTrue(safe_j(self.cat, self.post0))
        self.assertTrue(safe_j(self.cat, self.post1))

    def test_three_app_countermodel(self):
        # locals + pairwise pass; the 3-app solvency hyperedge fails
        self.assertTrue(all(inv_holds(v, self.postu) for v in self.cat.locals))
        self.assertTrue(inv_holds(jinv_sum(12, 2, (R.K2, R.K4), 550),
                                  self.postu))
        self.assertFalse(inv_holds(jinv_sum(11, 1, (R.K2, R.K3), 600),
                                   self.postu))
        self.assertFalse(safe_j(self.cat, self.postu))

    def test_global_countermodel(self):
        self.assertTrue(all(inv_holds(v, self.postg)
                            for v in self.cat.locals))
        self.assertTrue(all(inv_holds(v, self.postg)
                            for v in self.cat.hyper_invs))
        self.assertFalse(all(inv_holds(v, self.postg)
                             for v in self.cat.globals))
        self.assertFalse(safe_j(self.cat, self.postg))

    def test_frame_preservation(self):
        mutated = JM.state_write(self.post1, R.LENDING, 0, 400)
        self.assertEqual(state_get(mutated, R.K1), state_get(self.post1, R.K1))
        self.assertEqual(state_get(mutated, R.K4), state_get(self.post1, R.K4))

    def test_closure_fixture(self):
        aff = affected_closure([R.K1], self.cat.hypers, 8)
        self.assertEqual(sorted(aff), sorted([R.K1, R.K2, R.K3, R.K4]))
        with self.assertRaises(JClosureExhausted):
            affected_closure([R.K1], self.cat.hypers, 0)
        self.assertTrue(footprint_registered(
            [], self.cat))
        from exec_model import ExEvt, OP_WRITE
        self.assertFalse(footprint_registered(
            [ExEvt(OP_WRITE, 4242, 7, 1)], self.cat))


class TestMachine(unittest.TestCase):
    def setUp(self):
        self.cfg = R.fixture_cfg()
        self.cat = R.fixture_catalog()
        self.anchor = ProtoRootR3(self.cfg)
        self.chain = R.build_chain()
        self.b0, self.b1, self.bu = R.jblocks(self.chain, self.cfg, self.cat)

    def _machine_to_block1(self):
        m = JMachine(self.anchor)
        self.assertTrue(m.init(self.cfg, self.cat))
        m.exec(R.EXEC_CLIENT_D, R.PROG0, R.CALLER, 0)
        m.gate_eval(self.b0, self.chain["ctx0"], self.chain["rg0"],
                    self.chain["c0"], state_root(R.POST0),
                    payload_digest(R.PROG0))
        self.assertTrue(m.commit(self.b0, state_root(R.POST0),
                                 payload_digest(R.PROG0), 1))
        m.exec(R.EXEC_CLIENT_D, R.PROG1, R.CALLER, 0)
        m.gate_eval(self.b1, self.chain["ctx1"], self.chain["rg1"],
                    self.chain["c1"], state_root(R.POST1),
                    payload_digest(R.PROG1))
        self.assertTrue(m.commit(self.b1, state_root(R.POST1),
                                 payload_digest(R.PROG1), 1))
        return m

    def test_honest_two_blocks(self):
        m = self._machine_to_block1()
        self.assertEqual(m.next_slot, 2)
        self.assertEqual(state_get(m.state, R.K1), 100)
        self.assertEqual(state_get(m.state, R.K2), 100)
        self.assertEqual(state_get(m.state, R.K4), 100)

    def test_init_refuses_mutations(self):
        self.assertFalse(JMachine(self.anchor).init(self.cfg,
                                                    R.catalog_no_he1()))
        self.assertFalse(JMachine(self.anchor).init(self.cfg,
                                                    R.catalog_bad_owner()))
        self.assertFalse(JMachine(b"\xab" * 32).init(self.cfg, self.cat))

    def test_unauthorized_source(self):
        m = JMachine(self.anchor)
        m.init(self.cfg, self.cat)
        ok, why = m.exec(b"\x11" * 32, R.PROG0, R.CALLER, 0)
        self.assertFalse(ok)
        self.assertEqual(why, ("source",))
        self.assertEqual(len(m.exec_receipts), 0)

    def test_unsafe_composition_rejected(self):
        m = self._machine_to_block1()
        m.exec(R.EXEC_CLIENT_D, R.PROG_UNSAFE, R.CALLER, 0)
        g = m.gate_eval(self.bu, self.chain["ctxu"], self.chain["rgu"],
                        self.chain["cu"], state_root(R.POSTU),
                        payload_digest(R.PROG_UNSAFE))
        # the frozen gate ACCEPTS the record (authority layer)
        self.assertIsNotNone(g)
        self.assertEqual(g.verdict, "valid-g")
        st, hd, nx = dict(m.state), m.head, m.next_slot
        self.assertFalse(m.commit(self.bu, state_root(R.POSTU),
                                  payload_digest(R.PROG_UNSAFE), 1))
        self.assertEqual((m.state, m.head, m.next_slot), (st, hd, nx))

    def test_receipt_single_use(self):
        m = self._machine_to_block1()
        st, hd, nx = dict(m.state), m.head, m.next_slot
        self.assertFalse(m.commit(self.b1, state_root(R.POST1),
                                  payload_digest(R.PROG1), 1))
        self.assertEqual((m.state, m.head, m.next_slot), (st, hd, nx))

    def test_anchor_immutable_no_api(self):
        m = JMachine(self.anchor)
        self.assertFalse(hasattr(m, "set_anchor"))
        self.assertFalse(hasattr(m, "update_config"))
        self.assertFalse(hasattr(m, "replace_catalog"))

    def test_determinism(self):
        a = self._machine_to_block1()
        b = self._machine_to_block1()
        self.assertEqual(a.head, b.head)
        self.assertEqual(a.state, b.state)
        self.assertEqual(a.lin_head, b.lin_head)


class TestGoldenVectors(unittest.TestCase):
    def setUp(self):
        with open(f"{REPO}/phase1j/vectors/j_golden.json") as f:
            self.g = json.load(f)
        self.cat = R.fixture_catalog()
        self.cfg = R.fixture_cfg()

    def test_canon_and_roots(self):
        self.assertEqual(len(j_catalog_canon(self.cat)),
                         self.g["catj_canon_len"])
        self.assertEqual(j_catalog_root(self.cat).hex(), self.g["catj_root"])
        self.assertEqual(ProtoRootR3(self.cfg).hex(), self.g["cfgj_root"])

    def test_state_roots(self):
        self.assertEqual(state_root({}).hex(), self.g["stateroot0"])
        self.assertEqual(state_root(R.POST0).hex(), self.g["stateroot0p"])
        self.assertEqual(state_root(R.POST1).hex(), self.g["stateroot1"])

    def test_digests(self):
        _, _, t0 = exec_fragment({}, R.PROG0)
        self.assertEqual(trace_digest(t0).hex(), self.g["tracedigest0"])
        self.assertEqual(footprint_digest(t0).hex(), self.g["footdigest0"])
        self.assertEqual(footprint_canon(t0).hex(), self.g["footkeys0"])
        self.assertEqual(payload_digest(R.PROG0).hex(),
                         self.g["payloaddigest0"])


if __name__ == "__main__":
    unittest.main(verbosity=2)
