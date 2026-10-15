#!/usr/bin/env python3
"""Minimal shim: build the 13-field R3 config (the pack encoder's ProtoCfgR3)
from positional fields — the J fixtures' config builder."""
import sys
import os

HERE = os.path.dirname(os.path.abspath(__file__))
REPO = "/".join(HERE.split("/")[:-2])
for p in (f"{REPO}/phase1i-r3/python",):
    if p not in sys.path:
        sys.path.insert(0, p)

from srw3_r3_config_commitment import ProtoCfgR3  # noqa: E402


def make_cfg(chain_id, policy_version, policy_digest, app_set_digest,
             graph_digest, client_config_digest, execution_client_digest,
             fork, schedule, spec_version, authority_proof_type,
             authority_guest_digest, authority_config_digest):
    return ProtoCfgR3(
        chain_id=chain_id, policy_version=policy_version,
        policy_digest=policy_digest, app_set_digest=app_set_digest,
        graph_digest=graph_digest, client_config_digest=client_config_digest,
        execution_client_digest=execution_client_digest, fork=fork,
        schedule=schedule, spec_version=spec_version,
        authority_proof_type=authority_proof_type,
        authority_guest_digest=authority_guest_digest,
        authority_config_digest=authority_config_digest)
