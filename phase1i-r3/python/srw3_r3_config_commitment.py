# INTEGRATION PROVENANCE: this file is the reference encoder delivered with
# SRW3_Phase1I_R3_ConfigRoot_Binding_Pack.zip (handoff §3 "Reference encoding
# (also implemented in srw3_r3_config_commitment.py)"), integrated VERBATIM
# into phase1i-r3/python/ (original sha256 recorded in
# provenance/provenance-hashes.txt).  The only project-specific glue lives in
# r3_model.py, which injects the frozen real-Keccak function H (lin_verify.H,
# byte-identical to K LinH / Keccak256raw) as the `lin_h` argument.
"""Reference canonical encoder for SRW3 Phase 1I-R3 configuration-root binding.

This module deliberately does not choose a hash implementation. The SRW3 K
implementation must use its established LinH/Keccak primitive; the project's
Python mirror should inject its already-verified real-Keccak function into
proto_root_r3(). These standard-library tests validate byte encoding only.

Encoding v1:
    b"SRW3/ProtoCfg/R3\\0" || U32BE(1) || fields in the documented order
Byte strings are encoded as U32BE(length) || bytes. Integer fields are U32BE.
All lengths and integers must fit unsigned 32 bits.
"""
from __future__ import annotations

from dataclasses import dataclass, fields, replace
from typing import Callable

DOMAIN = b"SRW3/ProtoCfg/R3\x00"
ENCODING_VERSION = 1
U32_MAX = (1 << 32) - 1


@dataclass(frozen=True)
class ProtoCfgR3:
    """The complete 13-field configuration represented by Phase 1I-R2."""
    chain_id: bytes
    policy_version: int
    policy_digest: bytes
    app_set_digest: bytes
    graph_digest: bytes
    client_config_digest: bytes
    execution_client_digest: bytes
    fork: bytes
    schedule: bytes
    spec_version: int
    authority_proof_type: int
    authority_guest_digest: bytes
    authority_config_digest: bytes

    def __post_init__(self) -> None:
        byte_names = (
            "chain_id", "policy_digest", "app_set_digest", "graph_digest",
            "client_config_digest", "execution_client_digest", "fork",
            "schedule", "authority_guest_digest", "authority_config_digest",
        )
        int_names = ("policy_version", "spec_version", "authority_proof_type")
        for name in byte_names:
            value = getattr(self, name)
            if not isinstance(value, bytes):
                raise TypeError(f"{name} must be bytes, got {type(value).__name__}")
            if len(value) > U32_MAX:
                raise ValueError(f"{name} exceeds the U32 length limit")
        for name in int_names:
            value = getattr(self, name)
            if isinstance(value, bool) or not isinstance(value, int):
                raise TypeError(f"{name} must be an int (not bool)")
            if not 0 <= value <= U32_MAX:
                raise ValueError(f"{name} must fit unsigned 32-bit encoding")


def u32be(value: int) -> bytes:
    """Encode an unsigned 32-bit integer in big-endian byte order."""
    if isinstance(value, bool) or not isinstance(value, int):
        raise TypeError("U32 value must be an int (not bool)")
    if not 0 <= value <= U32_MAX:
        raise ValueError("U32 value is out of range")
    return value.to_bytes(4, byteorder="big", signed=False)


def lp32(value: bytes) -> bytes:
    """Encode a byte string as a 32-bit length followed by its exact bytes."""
    if not isinstance(value, bytes):
        raise TypeError("LP32 input must be bytes")
    if len(value) > U32_MAX:
        raise ValueError("LP32 input exceeds U32 length limit")
    return u32be(len(value)) + value


def proto_cfg_canon_r3(config: ProtoCfgR3) -> bytes:
    """Return the canonical, domain-separated preimage committing to all 13 fields.

    The field order is normative and intentionally does not reuse the frozen
    Phase 1I/R2 configuration root preimage. Any future encoding change must
    increment ENCODING_VERSION or change the domain string.
    """
    if not isinstance(config, ProtoCfgR3):
        raise TypeError("config must be ProtoCfgR3")
    parts = [DOMAIN, u32be(ENCODING_VERSION)]
    parts.extend((
        lp32(config.chain_id),
        u32be(config.policy_version),
        lp32(config.policy_digest),
        lp32(config.app_set_digest),
        lp32(config.graph_digest),
        lp32(config.client_config_digest),
        lp32(config.execution_client_digest),
        lp32(config.fork),
        lp32(config.schedule),
        u32be(config.spec_version),
        u32be(config.authority_proof_type),
        lp32(config.authority_guest_digest),
        lp32(config.authority_config_digest),
    ))
    return b"".join(parts)


def proto_root_r3(config: ProtoCfgR3, lin_h: Callable[[bytes], bytes]) -> bytes:
    """Compute the R3 root with the project's injected LinH/Keccak function.

    No fallback to hashlib.sha3_256 is provided because SHA3-256 and Ethereum
    Keccak-256 differ. Callers must supply the project's tested LinH function.
    """
    if not callable(lin_h):
        raise TypeError("lin_h must be callable")
    result = lin_h(proto_cfg_canon_r3(config))
    if not isinstance(result, bytes):
        raise TypeError("lin_h must return bytes")
    return result


def legacy_r2_config_preimage(config: ProtoCfgR3) -> bytes:
    """Model the frozen R2/1I fields 1..8 preimage for regression tests only.

    Mirrors the inspected R2 shape: 0x9C || chainId || U32(policyVersion) ||
    policyDigest || appSetDigest || graphDigest || clientConfigDigest ||
    executionClientDigest || fork. Fields 9..13 are absent. Do not use for R3.
    """
    if not isinstance(config, ProtoCfgR3):
        raise TypeError("config must be ProtoCfgR3")
    return b"\x9c" + b"".join((
        config.chain_id,
        u32be(config.policy_version),
        config.policy_digest,
        config.app_set_digest,
        config.graph_digest,
        config.client_config_digest,
        config.execution_client_digest,
        config.fork,
    ))


def mutate_field(config: ProtoCfgR3, field_name: str, value: object) -> ProtoCfgR3:
    """Test helper: return a new configuration with one field changed."""
    known = {field.name for field in fields(ProtoCfgR3)}
    if field_name not in known:
        raise KeyError(f"unknown ProtoCfgR3 field: {field_name}")
    return replace(config, **{field_name: value})
