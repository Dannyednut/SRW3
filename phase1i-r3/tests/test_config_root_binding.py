"""SRW3 Phase 1I-R3 — configuration-root binding test suite.

Part 1 (the 11 reference tests delivered with the handoff pack) validates the
canonical byte encoding: golden preimage, field coverage, length-prefix
behavior, input bounds, and the R2 alias witness.

Part 2 validates the golden VECTOR FILE (vectors/config-root-r3.json) against
a fresh recomputation with real Ethereum Keccak-256, and the R3 MACHINE
discipline at the Python level: authorized-root initialization, anchor
immutability, and config-change/refuse behavior.

Run:  python3 -m unittest -v   (from phase1i-r3/tests)
Classification: EXECUTABLE EVIDENCE — not a substitute for the K proofs.
"""
import json
import os
import sys
import unittest

HERE = os.path.dirname(os.path.abspath(__file__))
R3 = os.path.dirname(HERE)
REPO = os.path.dirname(R3)
for p in (f"{R3}/python", f"{REPO}/python-gen", f"{REPO}/phase1e/python",
          f"{REPO}/phase1f/python", f"{REPO}/phase1g/python"):
    if p not in sys.path:
        sys.path.insert(0, p)

from srw3_r3_config_commitment import (  # noqa: E402
    DOMAIN, ENCODING_VERSION, ProtoCfgR3, legacy_r2_config_preimage,
    lp32, mutate_field, proto_cfg_canon_r3, proto_root_r3, u32be)
from lin_verify import H  # noqa: E402
from r3_model import (R3Logic, R3State, ProtoRootR3,  # noqa: E402
                      LegacyR2Projection)

GOLDEN_PREIMAGE_HEX = (
    "535257332f50726f746f4366672f5233000000000100000007636861696e2d310000000700000021706f6c6963792d6469676573742d33322d627974652d706c616365686f6c646572000000226170702d7365742d6469676573742d33322d627974652d706c616365686f6c6465720000002067726170682d6469676573742d33322d627974652d706c616365686f6c64657200000028636c69656e742d636f6e6669672d6469676573742d33322d627974652d706c616365686f6c6465720000002b657865637574696f6e2d636c69656e742d6469676573742d33322d627974652d706c616365686f6c64657200000006666f726b2d410000000a7363686564756c652d4100000003000000010000002067756573742d6469676573742d33322d627974652d706c616365686f6c6465720000002770726f6f662d636f6e6669672d6469676573742d33322d627974652d706c616365686f6c646572")


BASE = ProtoCfgR3(
    chain_id=b"chain-1", policy_version=7,
    policy_digest=b"policy-digest-32-byte-placeholder",
    app_set_digest=b"app-set-digest-32-byte-placeholder",
    graph_digest=b"graph-digest-32-byte-placeholder",
    client_config_digest=b"client-config-digest-32-byte-placeholder",
    execution_client_digest=b"execution-client-digest-32-byte-placeholder",
    fork=b"fork-A", schedule=b"schedule-A", spec_version=3,
    authority_proof_type=1,
    authority_guest_digest=b"guest-digest-32-byte-placeholder",
    authority_config_digest=b"proof-config-digest-32-byte-placeholder")


class CanonicalEncoderTests(unittest.TestCase):
    """Part 1 — the handoff pack's reference tests (verbatim semantics)."""

    def test_golden_preimage_vector(self):
        # Cross-language conformance fixture: output must match byte-for-byte.
        expected = bytes.fromhex(GOLDEN_PREIMAGE_HEX)
        self.assertEqual(len(expected), 349)
        self.assertEqual(proto_cfg_canon_r3(BASE), expected)

    def test_domain_and_schema_version_are_first(self):
        self.assertTrue(proto_cfg_canon_r3(BASE).startswith(DOMAIN + u32be(ENCODING_VERSION)))

    def test_all_thirteen_fields_affect_canonical_preimage(self):
        changes = {
            "chain_id": b"chain-2", "policy_version": BASE.policy_version + 1,
            "policy_digest": BASE.policy_digest + b"!", "app_set_digest": BASE.app_set_digest + b"!",
            "graph_digest": BASE.graph_digest + b"!", "client_config_digest": BASE.client_config_digest + b"!",
            "execution_client_digest": BASE.execution_client_digest + b"!", "fork": b"fork-B",
            "schedule": b"schedule-B", "spec_version": BASE.spec_version + 1,
            "authority_proof_type": BASE.authority_proof_type + 1,
            "authority_guest_digest": BASE.authority_guest_digest + b"!",
            "authority_config_digest": BASE.authority_config_digest + b"!",
        }
        base = proto_cfg_canon_r3(BASE)
        for name, value in changes.items():
            with self.subTest(field=name):
                self.assertNotEqual(base, proto_cfg_canon_r3(mutate_field(BASE, name, value)))

    def test_r2_preimage_ignores_fields_9_through_13(self):
        base = legacy_r2_config_preimage(BASE)
        changes = {
            "schedule": b"schedule-B", "spec_version": BASE.spec_version + 1,
            "authority_proof_type": BASE.authority_proof_type + 1,
            "authority_guest_digest": BASE.authority_guest_digest + b"!",
            "authority_config_digest": BASE.authority_config_digest + b"!",
        }
        for name, value in changes.items():
            with self.subTest(field=name):
                self.assertEqual(base, legacy_r2_config_preimage(mutate_field(BASE, name, value)))

    def test_r3_binds_each_r2_omitted_authority_field(self):
        base = proto_cfg_canon_r3(BASE)
        changes = {
            "schedule": b"schedule-B", "spec_version": BASE.spec_version + 1,
            "authority_proof_type": BASE.authority_proof_type + 1,
            "authority_guest_digest": BASE.authority_guest_digest + b"!",
            "authority_config_digest": BASE.authority_config_digest + b"!",
        }
        for name, value in changes.items():
            with self.subTest(field=name):
                self.assertNotEqual(base, proto_cfg_canon_r3(mutate_field(BASE, name, value)))

    def test_length_prefix_separates_adjacent_byte_fields(self):
        left = mutate_field(mutate_field(BASE, "app_set_digest", b"A"), "graph_digest", b"BC")
        right = mutate_field(mutate_field(BASE, "app_set_digest", b"AB"), "graph_digest", b"C")
        self.assertNotEqual(proto_cfg_canon_r3(left), proto_cfg_canon_r3(right))
        self.assertNotEqual(lp32(b"A") + lp32(b"BC"), lp32(b"AB") + lp32(b"C"))

    def test_integer_encoding_is_fixed_width_big_endian(self):
        self.assertEqual(u32be(1), b"\x00\x00\x00\x01")
        self.assertEqual(u32be(0x01020304), b"\x01\x02\x03\x04")

    def test_rejects_negative_and_overflowing_integer_fields(self):
        for name in ("policy_version", "spec_version", "authority_proof_type"):
            with self.subTest(field=name, value=-1):
                with self.assertRaises(ValueError): mutate_field(BASE, name, -1)
            with self.subTest(field=name, value=1 << 32):
                with self.assertRaises(ValueError): mutate_field(BASE, name, 1 << 32)

    def test_rejects_wrong_types(self):
        with self.assertRaises(TypeError): mutate_field(BASE, "schedule", "not-bytes")
        with self.assertRaises(TypeError): mutate_field(BASE, "spec_version", True)

    def test_hash_function_receives_exact_preimage(self):
        seen = []
        def fake_lin_h(preimage):
            seen.append(preimage)
            return b"test-digest"
        self.assertEqual(proto_root_r3(BASE, fake_lin_h), b"test-digest")
        self.assertEqual(seen, [proto_cfg_canon_r3(BASE)])

    def test_hash_function_must_be_explicit(self):
        with self.assertRaises(TypeError): proto_root_r3(BASE, None)


class GoldenVectorConformanceTests(unittest.TestCase):
    """Part 2a — vectors/config-root-r3.json must match a fresh recomputation
    (real Keccak-256) and the handoff golden preimage."""

    @classmethod
    def setUpClass(cls):
        with open(os.path.join(R3, "vectors", "config-root-r3.json")) as f:
            cls.V = json.load(f)

    def test_vector_file_matches_fresh_recomputation(self):
        fx = self.V["fixture"]
        self.assertEqual(bytes.fromhex(fx["preimage"]), proto_cfg_canon_r3(BASE))
        self.assertEqual(bytes.fromhex(fx["root"]), proto_root_r3(BASE, H))

    def test_vector_file_matches_pack_golden_preimage(self):
        expected = bytes.fromhex(GOLDEN_PREIMAGE_HEX)
        self.assertEqual(len(expected), 349)
        self.assertEqual(bytes.fromhex(self.V["fixture"]["preimage"]), expected)

    def test_all_thirteen_mutation_vectors_differ(self):
        base_pre = bytes.fromhex(self.V["fixture"]["preimage"])
        base_root = bytes.fromhex(self.V["fixture"]["root"])
        self.assertEqual(len(self.V["all_field_mutations"]), 13)
        for name, m in self.V["all_field_mutations"].items():
            with self.subTest(mutation=name):
                self.assertTrue(m["preimage_differs_from_base"])
                self.assertNotEqual(bytes.fromhex(m["preimage"]), base_pre)
                self.assertNotEqual(bytes.fromhex(m["root"]), base_root)

    def test_alias_witness_and_domain_separation(self):
        aw = self.V["r2_alias_witness"]
        self.assertTrue(aw["legacy_preimages_equal"])
        self.assertTrue(aw["r3_roots_differ"])
        ds = self.V["domain_separation"]
        self.assertEqual(bytes.fromhex(ds["r3_preimage_prefix_hex"]),
                         bytes.fromhex(ds["expected_prefix_hex"]))
        self.assertEqual(ds["r2_preimage_prefix_hex"], "9c")

    def test_invalid_inputs_rejected(self):
        for case in self.V["invalid_integers"]:
            with self.subTest(case):
                with self.assertRaises(ValueError):
                    mutate_field(BASE, case["field"], case["value"])
        for case in self.V["invalid_types"]:
            with self.subTest(case):
                with self.assertRaises(TypeError):
                    mutate_field(BASE, case["field"], case["value"])


class R3MachineRootBindingTests(unittest.TestCase):
    """Part 2b — the machine-level root-binding discipline (Python mirror of
    the K rules; executable evidence for R3-INIT-REQUIRES-AUTHORIZED-ROOT and
    R3-CONFIG-IMMUTABLE)."""

    def setUp(self):
        self.root = ProtoRootR3(BASE)
        self.st = R3State(self.root)

    def test_honest_init_under_authorized_root(self):
        ok, msg = R3Logic.init(self.st, BASE)
        self.assertTrue(ok)
        self.assertEqual(self.st.head, self.root)
        self.assertEqual(self.st.head, self.st.anchor)
        self.assertEqual(self.st.linhead, b"\x00" * 32)

    def test_init_with_mutated_config_reusing_old_root_refuses(self):
        ok, _ = R3Logic.init(R3State(self.root), BASE)
        self.assertTrue(ok)
        for field, value in (("schedule", b"schedule-B"),
                             ("spec_version", 4),
                             ("authority_proof_type", 2),
                             ("authority_guest_digest",
                              BASE.authority_guest_digest + b"!"),
                             ("authority_config_digest",
                              BASE.authority_config_digest + b"!")):
            with self.subTest(field=field):
                st = R3State(self.root)
                bad = mutate_field(BASE, field, value)
                ok, msg = R3Logic.init(st, bad)
                self.assertFalse(ok)
                self.assertIsNone(st.pinned_cfg)
                self.assertEqual(st.head, b"\x00")

    def test_init_with_wrong_anchor_refuses(self):
        st = R3State(b"\xab" * 32)   # a DIFFERENT protocol's anchor
        ok, _ = R3Logic.init(st, BASE)
        self.assertFalse(ok)
        self.assertIsNone(st.pinned_cfg)

    def test_anchor_is_not_settable_through_the_command_api(self):
        """The command API is EXACTLY {init, gate_eval, accept}; no R3Logic
        method ever ASSIGNS the anchor or the pinned configuration (the
        Python mirror of 'no rule writes <r3anchor>' / R3-ANCHOR-IMMUTABLE
        and R3-CONFIG-IMMUTABLE)."""
        import inspect
        import re
        r3api = [n for n in dir(R3Logic) if not n.startswith("_")]
        self.assertEqual(sorted(n for n in r3api if n != "NAME"),
                         ["accept", "gate_eval", "init"])
        src = inspect.getsource(R3Logic)
        # no ASSIGNMENT to the anchor / pin anywhere in the command API
        # ('=' not part of a comparison; comments stripped first)
        code = "\n".join(ln.split("#")[0] for ln in src.splitlines())
        self.assertIsNone(re.search(r"\.anchor\s*=(?!=)", code))
        self.assertIsNone(re.search(r"\.pinned_cfg\s*=(?!\s*cfg\b)", code))
        st = R3State(self.root)
        R3Logic.init(st, BASE)            # works: anchor untouched
        self.assertEqual(st.anchor, self.root)
        self.assertEqual(st.head, self.root)

    def test_reinit_refused(self):
        R3Logic.init(self.st, BASE)
        before = self.st.snapshot()
        ok, _ = R3Logic.init(self.st, BASE)
        self.assertFalse(ok)
        self.assertEqual(self.st.snapshot(), before)


if __name__ == "__main__":
    unittest.main()
