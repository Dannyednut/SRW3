# Phase 1H — exact Engine API insertion point (Geth v1.17.7)

Client: `go-ethereum` v1.17.7-stable, commit
`3d858f858a458effb2a563788aedf1fe65e1f0d3` (source: `tools/src/geth-src`,
binary: prebuilt `geth-linux-amd64-1.17.7-3d858f85`).

## Source-level call path for `engine_newPayloadV5`

```
RPC (authrpc :8551, JWT) 
  └─ eth/catalyst/api.go :: func (api *ConsensusAPI) NewPayloadV5(...)        (line 862)
       fork/timestamp/param checks (checkFork(forks.Amsterdam, ...), BAL presence)
       └─ api.newPayload(ctx, params, versionedHashes, beaconRoot, requests, witness=false)   (line 905)
            ├─ engine.ExecutableDataToBlock(params, ...)                        (line 925)
            ├─ duplicate/invalid-ancestor/parent checks                         (lines 942-980)
            └─ api.eth.BlockChain().InsertBlockWithoutSetHead(ctx, block, witness)   (line 1003)
                 │   core/blockchain.go:2885
                 └─ full state transition:
                      core/state_processor.go :: StateProcessor.Process (line 68)
                        - PreExecution (beacon-root + parent-hash system ops,
                          BAL construction starts)                  (state_processor.go:107-118)
                        - per-tx execution (BAL merge)              (:138-144)
                        - PostExecution (requests, BAL finalize)    (:152, :190)
                      core/block_validator.go :: ValidateState
                        - BAL: header.BlockAccessListHash == locally
                          re-derived BAL hash (EXECUTION-VALIDATED) (block_validator.go:183-196)
                        - receipts root, state root:                (:170-200)
                          statedb.IntermediateRoot vs header.Root   (:199-201)
            └─ status: VALID/INVALID + latestValidHash = block.Hash()       (api.go:1065-1080)
```

Canonicalization (a SEPARATE step, and the one the SRW3 gate must precede
to be consensus-relevant):

```
  eth/catalyst/api.go :: ForkchoiceUpdatedV4 (line 223) / forkchoiceUpdated (line 246)
    └─ beacon-fork-choice update -> canonical head move + reorg handling
```

## State / root / trace availability at each stage

| Datum | Available at insertion point? | Source |
|---|---|---|
| payload + parent root | yes | `ExecutableDataToBlock`, parent header |
| post-state root | yes | header `stateRoot` validated against `statedb.IntermediateRoot` |
| execution result (receipts, logs) | yes (in-process) / via RPC | `ProcessResult`, `eth_getBlockReceipts` |
| execution effect trace | in-process StateDB access only; externally via `debug_traceBlockByHash` (callTracer / prestateTracer diffMode) | NOT EXPOSED BY CLIENT as a first-class Engine API datum |
| BAL | yes | `block.AccessList()` (EIP-7928; execution-validated at import) |
| chain config / fork | yes (in-process `api.eth.BlockChain().Config()`) / via `admin_nodeInfo.protocols.eth.config` externally | `debug_chainConfig` does NOT exist in v1.17.7 (recorded gap) |
| witness | optional (`makeWitness` flag on `InsertBlockWithoutSetHead`; wired through `forkchoiceUpdated`/`newPayload` witness variants) | stateless-witness machinery |

## Where the SRW3 gate sits (Phase 1H architecture)

Two admissible placements were implemented:

1. **CL-side boundary gate (DEMONSTRATED, primary).**  The harness acts as
   the consensus client: `forkchoiceUpdatedV4(build)` → `getPayloadV6` →
   `newPayloadV5` (client EXECUTES here) → **SRW3 gate** →
   `forkchoiceUpdatedV4(head)` only on `SRW3_VALID` (consensus-visible-sim)
   or unconditionally (shadow).  This placement needs NO client change and
   is exactly the `execution/consensus` boundary of §29.
2. **In-process client hook (SPECIFIED, patch provided, NOT BUILT).**
   `client/patch/srw3-shadow-hook.patch` inserts a non-blocking shadow-gate
   call at the end of `ConsensusAPI.newPayload` (after
   `InsertBlockWithoutSetHead` succeeds, before the VALID status is
   returned).  Status: patch produced against v1.17.7 source; NOT COMPILED
   in this environment (no Go toolchain; the reproducible experiment uses
   the prebuilt client binary unchanged — this guarantees the client
   behavior results are attributable to the REAL client, not a fork).

## Not exposed by client (recorded)

- `debug_chainConfig` — absent in v1.17.7; chain config read via
  `admin_nodeInfo.protocols.eth.config`.
- First-class Engine-API execution trace/state-diff — absent; obtained via
  `debug_traceBlockByHash` (callTracer + prestateTracer diffMode) which the
  adapter treats as client-derived evidence (provenance recorded per field).
- BAL: exposed through the payload itself (`ExecutionPayloadV4.
  blockAccessList`) and `engine_getPayloadBodiesByHashV2`.
