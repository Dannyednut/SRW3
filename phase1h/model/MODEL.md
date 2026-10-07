# SRW3 Phase 1H — Model: the client boundary (MODEL.md)

## 1. What is modeled

Phase 1H models the boundary between THREE distinct judgments (the §29
formal boundary — never merged):

1. **Ethereum payload validity** — the execution client's own judgment
   (`engine_newPayloadV5` → `InsertBlockWithoutSetHead` → VALID/INVALID):
   structural validity, execution success, state/receipt root equality,
   BAL execution-validation (EIP-7928), fork membership.
2. **Ethereum fork choice** — the consensus layer's selection of the
   canonical chain (`engine_forkchoiceUpdatedV4`), including reorgs.
3. **The SRW3 security gate (Gate_H)** — the frozen Phase 1D-R1/1E/1F/1G
   gate applied at the client boundary, consuming CLIENT-DERIVED evidence:
   evidence binding, state-root binding, effect completeness, authority
   certificate chain, policy context binding, security invariants,
   interaction obligations.

The gate is evaluated at exactly one point: **after execution
(`newPayload`), before fork choice (`forkchoiceUpdated`)**.  This is the
only point at the Engine API where (a) the full execution result exists and
(b) a CL-side decision can still influence canonicalization without any
client modification.

## 2. Architecture (as implemented)

```
                 Ethereum (Geth v1.17.7, Amsterdam)
                    │
          ┌─────────┴─────────┐
          │                   │
   execution              fork choice
   (newPayloadV5)         (forkchoiceUpdatedV4)
          │                   │
          ▼                   ▼
   execution result     consensus authority
   + payload V4               │
   + BAL (EIP-7928)           │
          │                   │
          └────────┬──────────┘
                   ▼
        SRW3 adapter (CL-side, python/)
          ├─ ClientExecutionEvidence (§8 bindings, §7 real data)
          ├─ ClientPostStateRoot → SRW3 state-root binding (§9, adapter)
          ├─ AuthorityCertificate chain (1G rules at the boundary)
          ├─ SecurityContext_H (§11) + policy loader (§12)
          └─ Gate_H: L1 binding / L2 completeness / L3 authority /
                     L4 policy context / L5 invariants / L6 interaction
                   │
             ┌─────┴─────┐
           reject       accept
             │             │
             ▼             ▼
      shadow: record    shadow: record
      sim: refuse       sim: fcu(head) → canonical
      canonicalization
```

Two modes, never conflated:
- **shadow** — gate observes and records; canonicalization unconditional;
  Ethereum behavior byte-identical with/without the gate (H10-D).
- **consensus-visible-sim** — the CL treats `SRW3_REJECT`/`SRW3_ERROR` as
  INVALID: refuses to canonicalize and never extends the rejected branch.
  This is a SIMULATION of a protocol rule; the real client still answers
  VALID (recorded side by side).

## 3. Authority model at the boundary

The Phase 1G authority chain is instantiated as:

- **Level 0 (protocol root)** — the devnet genesis + Engine API boundary.
  Its authority remains PROTOCOL-GIVEN (assumption **A-G2 carried over**;
  Phase 1H does not close it — it is the same protocol/consensus root that
  Phase 1G identified).
- **Level 1 (execution client)** — the client identity
  (`web3_clientVersion`, chainId, chain-config digest), authorized by L0.
- **Level 2 (execution evidence)** — `ClientExecutionEvidence` records
  (payload digest, parent root, execution id, effect digest, child root),
  authorized by L1, fields bound one-to-one.

NoCircularAuthority (1G) applies verbatim: no self-citation, strictly
decreasing levels, termination at the authorized L0 root, per-step issuer
authorization derived from the CONTEXT (chainId, genesis, client config,
policy version) — never from the certificate under evaluation.

## 4. Evidence sources (all client-derived; §7)

| Datum | Client source | Recorded gaps |
|---|---|---|
| payload, parent/child roots | Engine API payload + headers | — |
| execution identity/config | `web3_clientVersion`, `admin_nodeInfo.protocols.eth.config` | `debug_chainConfig` NOT EXPOSED BY CLIENT in v1.17.7 |
| ordered effect trace | receipts + `debug_traceBlockByHash` (callTracer + prestateTracer diffMode) | not a first-class Engine API datum |
| BAL | `ExecutionPayloadV4.blockAccessList` (EIP-7928) | reads are keys only; call structure absent |
| post-state values (unchanged bounds) | `eth_getStorageAt` at the payload hash | beyond the tx-diff (boundary finding) |

## 5. What the model does NOT claim

- No claim that SRW3 rejection changes Ethereum validity (shadow + sim
  only; §39).
- No claim that BAL equals the security-effect trace (§19: preserved and
  strengthened).
- No claim that policy authority is closed (A-G7: policy remains a
  governance input pinned out-of-band by the deployment record).
- No claim of multi-client enforcement (single client; §26 derives the
  interoperability requirements instead).
