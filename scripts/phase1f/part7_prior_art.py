#!/usr/bin/env python3
"""SRW3 Phase 1F — Part 7: prior-art positioning (targeted, not encyclopedic).

Scope per the phase brief: state the EXISTING techniques the Level-3 layer
must be read against, and the specific distinction SRW3 Phase 1F claims.
This file records the search queries and the claim-by-claim comparison that
the report Section on prior art renders.
"""

ROWS = [
    # (technique, what it does, where it DIFFERS from SRW3 Level 3)
    ("EIP-8025 (execution witnesses / state-proof RPC)",
     "Client-verifiable execution/state witnesses via RPC so light clients "
     "can verify inclusion/state without full nodes.",
     "EIP-8025 authenticates STATE pieces to a CLIENT from a serving node. "
     "SRW3 Level 3 binds a LINEAGE RECORD's security decision to an ordered, "
     "digest-bound execution-effect trace inside a verified transition "
     "semantics (K/KEVM); the record, the trace, the execution identity and "
     "the state anchor are one mechanized certificate. No K-semantics, no "
     "obligation gate, no lineage threading exists in EIP-8025."),

    ("zkEVM provers (type-1..4; e.g. zkSync/Polygen-style, Scroll, PSE)",
     "Produce succinct validity proofs of EVM execution; a verifier accepts "
     "a state transition without re-execution.",
     "zkEVM proves EXECUTION VALIDITY of a block/tx against an EVM spec — "
     "a generic-execution-validity result. SRW3's core distinction (frozen "
     "since Phase 0-D and preserved here): generic execution validity is NOT "
     "SRW3 security validity. The 1F gate additionally evaluates the "
     "SECURITY OBLIGATION SURFACE (authority, alias, aggregate budgets), "
     "threads a cryptographic LINEAGE across transitions, and anchors state "
     "commitments (L2); a zkEVM proof supplies none of these. Complementary: "
     "a zkEVM proof could serve as one witness SOURCE (future work), but it "
     "would still feed the SRW3 gate, not replace it."),

    ("Stateless Ethereum / witness specs (state/witness formats, "
     "Verkle-era accessor proofs)",
     "Multitary/Verkle multiproofs let a stateless validator verify a "
     "transition against a witness without keeping full state.",
     "Witness formats authenticate the STATE TOUCHED by a transition "
     "(membership/non-membership), not the ORDERED EFFECT STREAM, and carry "
     "no execution identity, no per-transition security obligations, and no "
     "lineage-chain semantics. Phase 1F's trace is order-preserving and "
     "binds READ observations (the oracle-staleness class), which pure "
     "state-witness schemes do not address."),

    ("Trace-attestation / execution-receipt schemes (e.g. CCF-style "
     "receipts, TEE attested ledgers)",
     "Hardware or quorum attestation over an execution transcript so third "
     "parties can audit what a service executed.",
     "Such receipts attest via TRUSTED HARDWARE or QUORUM signatures; the "
     "attestation replaces verification. SRW3 1F has no trusted-execution "
     "assumption: the binding is recomputed (digests, identity, replay, "
     "anchor) inside mechanized semantics; the signature ≠ authenticity rule "
     "is explicit. The A-F3 boundary (trace authenticity needs re-execution "
     "or an execution-derived source) is the honest analogue and is "
     "demonstrated closed at the instrumented-execution layer."),

    ("Fraud/evidence-proof systems (optimistic-rollup fraud proofs, "
     "evidence-of-misbehavior)",
     "Detect/attribute invalid transitions after the fact with challenge "
     "periods.",
     "Fraud proofs are RETROACTIVE and challenge-gated; SRW3's gate is "
     "COMMIT-TIME: the decision (commit vs reject+restore) is part of the "
     "transition semantics with lineage atomicity. Fraud systems have no "
     "notion of a per-record 14-conjunct certificate or a lineage chain."),

    ("K-framework EVM verification (KEVM-verified contracts, e.g. "
     "runtimeverification's reachability proofs)",
     "Prove contract-level properties against the KEVM semantics.",
     "Contract verification proves properties OF PROGRAMS. SRW3 proves "
     "properties OF A GATE over records, traces, identities and anchors — "
     "the Phase 1F theorem set (22 PROVED claims incl. the branch-wise "
     "EXEC-EFFECT-BINDING certificate) is a different artifact class, "
     "machined against the same KEVM execution engine (complementary)."),
]


def main() -> int:
    print("=== SRW3 Phase 1F — prior-art positioning (claim-by-claim) ===\n")
    for name, what, diff in ROWS:
        print(f"[{name}]")
        print(f"  does        : {what}")
        print(f"  differs via : {diff}\n")
    print("Freeze discipline: the comparison above is scoped to the Level-3")
    print("layer and the standing distinction (generic execution validity vs")
    print("SRW3 security validity); it upgrades no evidence tier and claims")
    print("no exhaustive survey. Prior-art conjunction frozen as recorded.")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
