#!/usr/bin/env python3
"""Generate phase1i-r3/vectors/config-root-r3.json — the golden vector set for
the R3 configuration-root binding (handoff §8: "Retain a golden preimage
vector").  Regenerate with:  python3 vectors/gen_vectors.py
All digests are REAL Ethereum Keccak-256 (lin_verify.H, byte-identical to the
K LinH/Keccak256raw hook and to the LLVM krypto shim).  SHA3-256 is never
used (handoff §3)."""
import json
import os
import sys

HERE = os.path.dirname(os.path.abspath(__file__))
REPO = "/".join(HERE.split("/")[:-2])
for p in (f"{REPO}/phase1i-r3/python", f"{REPO}/python-gen"):
    if p not in sys.path:
        sys.path.insert(0, p)

from lin_verify import H  # noqa: E402
from srw3_r3_config_commitment import (  # noqa: E402
    DOMAIN, ENCODING_VERSION, ProtoCfgR3, legacy_r2_config_preimage,
    mutate_field, proto_cfg_canon_r3, proto_root_r3)

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

MUTATIONS = {
    "f01_chain_id": ("chain_id", b"chain-2"),
    "f02_policy_version": ("policy_version", 8),
    "f03_policy_digest": ("policy_digest", BASE.policy_digest + b"!"),
    "f04_app_set_digest": ("app_set_digest", BASE.app_set_digest + b"!"),
    "f05_graph_digest": ("graph_digest", BASE.graph_digest + b"!"),
    "f06_client_config_digest": ("client_config_digest",
                                 BASE.client_config_digest + b"!"),
    "f07_execution_client_digest": ("execution_client_digest",
                                    BASE.execution_client_digest + b"!"),
    "f08_fork": ("fork", b"fork-B"),
    "f09_schedule": ("schedule", b"schedule-B"),
    "f10_spec_version": ("spec_version", 4),
    "f11_authority_proof_type": ("authority_proof_type", 2),
    "f12_authority_guest_digest": ("authority_guest_digest",
                                   BASE.authority_guest_digest + b"!"),
    "f13_authority_config_digest": ("authority_config_digest",
                                    BASE.authority_config_digest + b"!"),
}


def vec(cfg):
    pre = proto_cfg_canon_r3(cfg)
    return {"preimage": pre.hex(), "preimage_len": len(pre),
            "root": proto_root_r3(cfg, H).hex()}


def main():
    out = {
        "schema": "SRW3-Phase1I-R3/config-root-vectors/v1",
        "hash_note": ("root = Ethereum Keccak-256 (original padding) over the "
                      "canonical preimage, byte-identical to K LinH / "
                      "Keccak256raw; NOT hashlib.sha3_256"),
        "domain": DOMAIN.hex(),
        "encoding_version": ENCODING_VERSION,
        "fixture": {
            "description": ("the handoff/pack sample configuration; the "
                            "canonical preimage is the 349-byte golden "
                            "vector (K and Python must reproduce it "
                            "byte-for-byte)"),
            "fields": {
                "chain_id": "chain-1", "policy_version": 7,
                "policy_digest": "policy-digest-32-byte-placeholder",
                "app_set_digest": "app-set-digest-32-byte-placeholder",
                "graph_digest": "graph-digest-32-byte-placeholder",
                "client_config_digest":
                    "client-config-digest-32-byte-placeholder",
                "execution_client_digest":
                    "execution-client-digest-32-byte-placeholder",
                "fork": "fork-A", "schedule": "schedule-A",
                "spec_version": 3, "authority_proof_type": 1,
                "authority_guest_digest": "guest-digest-32-byte-placeholder",
                "authority_config_digest":
                    "proof-config-digest-32-byte-placeholder",
            },
            **vec(BASE),
        },
        "all_field_mutations": {},
        "length_ambiguity": {},
        "r2_alias_witness": {},
        "domain_separation": {},
        "invalid_integers": [],
        "invalid_types": [],
    }

    base_pre = proto_cfg_canon_r3(BASE)
    for name, (field, value) in MUTATIONS.items():
        cfg2 = mutate_field(BASE, field, value)
        pre2 = proto_cfg_canon_r3(cfg2)
        out["all_field_mutations"][name] = {
            "field": field, "changed_to_repr": repr(value),
            **vec(cfg2),
            "preimage_differs_from_base": pre2 != base_pre,
        }

    # length ambiguity: adjacent LP32 fields ("A","BC") vs ("AB","C")
    left = mutate_field(mutate_field(BASE, "app_set_digest", b"A"),
                        "graph_digest", b"BC")
    right = mutate_field(mutate_field(BASE, "app_set_digest", b"AB"),
                         "graph_digest", b"C")
    out["length_ambiguity"] = {
        "left": {"app_set_digest": "A", "graph_digest": "BC", **vec(left)},
        "right": {"app_set_digest": "AB", "graph_digest": "C", **vec(right)},
        "preimages_differ":
            proto_cfg_canon_r3(left) != proto_cfg_canon_r3(right),
        "roots_differ": proto_root_r3(left, H) != proto_root_r3(right, H),
    }

    # the R2 alias witness: legacy 0x9C projection ignores fields 9..13
    legacy_a = legacy_r2_config_preimage(BASE)
    sched_b = mutate_field(BASE, "schedule", b"schedule-B")
    legacy_b = legacy_r2_config_preimage(sched_b)
    out["r2_alias_witness"] = {
        "note": ("the FROZEN R2 root preimage (0x9C tag, fields 1..8 only) "
                 "is UNCHANGED by a schedule mutation while the R3 preimage "
                 "and root both change — the alias this phase closes"),
        "legacy_preimage_schedule_A": legacy_a.hex(),
        "legacy_preimage_schedule_B": legacy_b.hex(),
        "legacy_preimages_equal": legacy_a == legacy_b,
        "r3_root_schedule_A": proto_root_r3(BASE, H).hex(),
        "r3_root_schedule_B": proto_root_r3(sched_b, H).hex(),
        "r3_roots_differ": proto_root_r3(BASE, H) != proto_root_r3(sched_b, H),
    }

    out["domain_separation"] = {
        "r3_preimage_prefix_hex":
            proto_cfg_canon_r3(BASE)[:21].hex(),
        "expected_prefix_hex": (DOMAIN.hex()
                                + (1).to_bytes(4, "big").hex()),
        "r2_preimage_prefix_hex": legacy_a[:1].hex(),
        "r2_tag": "9c",
        "note": ("the R3 preimage starts with the R3 domain+version; the "
                 "frozen R2 preimage starts with the 0x9C tag — an R2 root "
                 "or a differently versioned preimage is never accepted as "
                 "an R3 anchor (handoff §7)"),
    }

    for fname in ("policy_version", "spec_version", "authority_proof_type"):
        for bad in (-1, 1 << 32):
            out["invalid_integers"].append(
                {"field": fname, "value": bad,
                 "expected_exception": "ValueError"})
    out["invalid_types"] = [
        {"field": "schedule", "value": "not-bytes",
         "expected_exception": "TypeError"},
        {"field": "spec_version", "value": True,
         "expected_exception": "TypeError"},
    ]

    os.makedirs(HERE, exist_ok=True)
    path = os.path.join(HERE, "config-root-r3.json")
    with open(path, "w") as f:
        json.dump(out, f, indent=2, sort_keys=False)
        f.write("\n")
    print(f"wrote {path}")
    print("golden preimage len:", out["fixture"]["preimage_len"])
    print("golden root:", out["fixture"]["root"])


if __name__ == "__main__":
    main()
