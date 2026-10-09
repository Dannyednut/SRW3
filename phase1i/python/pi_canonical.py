"""SRW3 Phase 1I — canonical encoding layer for the protocol model.

The protocol commitment predicate must be a function of SECURITY-SEMANTIC
content only (determinism requirement, Phase 1I spec section 11):

    Inputs_A = Inputs_B  =>  Decision_A = Decision_B

regardless of serialization differences.  The canonical form is explicit and
domain-separated, continuing the frozen tag discipline:

  1G  0x8C cert body, 0xA1..0xA4 identity preimages
  1H  "SRW3-CONTEXT-H-V1"  security-context digest (UNCHANGED, reused here)
  1I  "SRW3-POLICYCOMMIT-V1"  policy commitment
      "SRW3-PROTOCFG-V1"      protocol configuration root (level-0 anchor)
      "SRW3-BLOCKCOMMIT-V1"   block commitment (commitment record identity)
      "SRW3-SRW3ROOT-V1"      candidate combined SRW3 root (section 16, option D
                              — compared, NOT auto-selected)

Canonical form for a field mapping:  "<DOMAIN>\\n" + "\\n".join("k=v") over
fields in lexicographic key order, every value a string  (ints in decimal,
bytes as 0x-hex).  No floats, no wall-clock values, no unordered container
serialization, no process/object identity.  The same discipline as the
Phase 1H-R1 SecurityContext digest, extended to protocol objects.
"""
from __future__ import annotations

import json

from eth_utils import keccak

DOM_POLICYCOMMIT = "SRW3-POLICYCOMMIT-V1"
DOM_PROTOCFG = "SRW3-PROTOCFG-V1"
DOM_BLOCKCOMMIT = "SRW3-BLOCKCOMMIT-V1"
DOM_SRW3ROOT = "SRW3-SRW3ROOT-V1"


def canon_str(v) -> str:
    """Deterministic string form of a canonical field value."""
    if isinstance(v, bool):
        return "true" if v else "false"
    if isinstance(v, int):
        return str(int(v))          # decimal, sign preserved; 0x-hex is text
    if isinstance(v, bytes):
        return "0x" + v.hex()
    if isinstance(v, str):
        return v
    raise TypeError(f"non-canonical field type: {type(v)}")


def canonical_serialization(domain: str, fields: dict) -> str:
    """Documented canonical form: domain + sorted k=v lines."""
    return domain + "\n" + "\n".join(
        f"{k}={canon_str(fields[k])}" for k in sorted(fields))


def canonical_digest(domain: str, fields: dict) -> str:
    """keccak256 over the canonical serialization (0x-hex string)."""
    return "0x" + keccak(canonical_serialization(domain, fields).encode()).hex()


# ---------------------------------------------------------------------------
# Adversarial serialization variants (spec section 11): each function takes a
# canonical field mapping and returns a DIFFERENT raw serialization of the
# same semantic content, or a detection result for malformed input.  The
# protocol model consumes only the canonical projection, so every variant
# must yield the identical digest/decision — the suites assert this.
# ---------------------------------------------------------------------------

def variant_reordered_json(fields: dict) -> str:
    """Same fields, keys emitted in reverse-sorted order (JSON field order)."""
    payload = {k: fields[k] for k in sorted(fields, reverse=True)}
    return json.dumps(payload, sort_keys=False)


def variant_json_sorted(fields: dict) -> str:
    return json.dumps(fields, sort_keys=True)


def variant_int_encoding(fields: dict) -> dict:
    """Integer-valued fields re-encoded as 0x-hex strings (same integers)."""
    out = {}
    for k, v in fields.items():
        if isinstance(v, int) and not isinstance(v, bool):
            out[k] = hex(v)
        else:
            out[k] = v
    return out


def variant_missing_optional(fields: dict, optional: tuple) -> dict:
    """Drop keys declared optional (absence of an optional field is not a
    semantic difference; optional fields are NOT part of the canonical set)."""
    return {k: v for k, v in fields.items() if k not in optional}


def duplicate_key_json(fields: dict) -> tuple[str, str, bool]:
    """Serialize a mapping that contains a duplicated key with conflicting
    values; return (raw_json, parsed_dict, duplicate_detected).  JSON object
    semantics make the duplicate unrepresentable in a dict, so the PARSED
    value is last-wins and the duplicate is detectable only pre-parse: the
    protocol rule is that a raw serialization with a duplicate key is
    MALFORMED input (never silently canonicalized)."""
    raw = ("{" + ",".join(f'"{k}": {json.dumps(canon_str(fields[k]))}'
                          for k in sorted(fields))
           + f',"{sorted(fields)[0]}": "DUP" }}')
    parsed = json.loads(raw)
    detected = raw.count(f'"{sorted(fields)[0]}"') == 2
    return raw, parsed, detected
