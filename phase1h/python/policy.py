"""SRW3 Phase 1H — policy loading with NON-self-declared authority.

The policy file (srw3_policy.json) declares invariants, application set,
interaction graph and execution fragment.  Its AUTHORITY is NOT declared by
the policy itself: the deployment configuration (deployment.json, owned by
governance, digest pinned out-of-band) pins the digest of the policy file.
The loader recomputes the digest over the canonical JSON form (without the
recorded policyDigest field) and refuses to evaluate under a mismatch.

This preserves the Phase 1G A-G7 boundary:
    policy authority remains a protocol/governance input.
"""
from __future__ import annotations

import hashlib
import json
import os

from eth_utils import keccak


class PolicyError(Exception):
    pass


def canonical_json_without(obj: dict, drop: list[str]) -> bytes:
    o = {k: v for k, v in obj.items() if k not in drop}
    return json.dumps(o, sort_keys=True, separators=(",", ":")).encode()


def digest_of(obj: dict, drop: list[str] | None = None) -> str:
    return "0x" + keccak(canonical_json_without(obj, drop or [])).hex()


class Policy:
    def __init__(self, obj: dict, path: str):
        self.obj = obj
        self.path = path
        self.policy_version = obj["policyVersion"]
        self.application_set = [a.lower() for a in obj["applicationSet"]]
        self.invariants = obj["invariants"]
        self.interaction_graph = obj["interactionGraph"]
        self.authority_config = obj["authorityConfiguration"]
        self.execution_fragment = obj["executionFragment"]
        self.recorded_digest = obj.get("policyDigest")

    def verify_against_deployment(self, deployment: dict) -> str:
        """Returns the computed policy digest; raises on mismatch with the
        deployment-pinned digest (authority comes from the deployment, not
        from the policy)."""
        computed = digest_of(self.obj, drop=["policyDigest"])
        if self.recorded_digest and self.recorded_digest != computed:
            raise PolicyError(
                f"policy self-digest mismatch: recorded={self.recorded_digest} "
                f"computed={computed}")
        pinned = deployment["pinnedPolicyDigest"]
        if computed != pinned:
            raise PolicyError(
                f"policy not authorized by deployment: pinned={pinned} "
                f"computed={computed} (H6/H-A7 protection)")
        return computed


def load_policy(path: str) -> Policy:
    with open(path) as f:
        return Policy(json.load(f), path)


def load_deployment(path: str) -> dict:
    with open(path) as f:
        return json.load(f)


def make_deployment(pinned_policy_digest: str, chain_id: int,
                    genesis_hash: str) -> dict:
    """The governance-side deployment record (outside the policy)."""
    return {
        "deploymentVersion": "srw3-1h-deployment-v1",
        "chainId": chain_id,
        "genesisHash": genesis_hash,
        "pinnedPolicyDigest": pinned_policy_digest,
    }


def write_policy_files(dirpath: str, policy_obj: dict) -> tuple[str, dict]:
    """Materialize srw3_policy.json + deployment.json; returns paths."""
    os.makedirs(dirpath, exist_ok=True)
    d = digest_of(policy_obj, drop=["policyDigest"])
    policy_obj = dict(policy_obj)
    policy_obj["policyDigest"] = d
    pol_path = os.path.join(dirpath, "srw3_policy.json")
    json.dump(policy_obj, open(pol_path, "w"), indent=2)
    return pol_path, {"policyDigest": d}
