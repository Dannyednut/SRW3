# Phase 1H spec baseline (frozen)

- Repository: github.com/ethereum/execution-apis (current Execution API specification)
- Spec commit: `3b9944a07afb53a327a3b5908a607f14b4e764d8` (2026-10-07T08:05:37-05:00,
  "engine: allow null result in engine_getBlobsV2 schema (#781)")
- Frozen file copies: `execution-apis/` (README, common.md, paris/prague/cancun/
  osaka/amsterdam/bogota fork specs, openrpc methods/payload.yaml)
- SHA-256 of every frozen file: `SPEC-HASHES.txt`

## Method versions recorded (per the frozen spec)

| Method                        | Introduced at | Latest version at frozen HEAD |
|-------------------------------|---------------|-------------------------------|
| engine_newPayload             | Paris (V1/V2), Cancun (V3), Prague (V4) | **V5** (Amsterdam: `ExecutionPayloadV4` + `blockAccessList`, EIP-7928), **V6** (Bogota: + `inclusionListTransactions`, EIP-7805) |
| engine_getPayload             | Cancun V3, Prague V4, Osaka V5 | **V6** (Amsterdam: returns `ExecutionPayloadV4`) |
| engine_forkchoiceUpdated      | Paris V1, Cancun V2, Prague V3 | **V4** (Amsterdam attributes: + `slotNumber`, `targetGasLimit`), **V5** (Bogota) |
| engine_getPayloadBodiesByHash | Shanghai V1 | **V2** (Amsterdam: + `blockAccessList`) |
| Schema                        | PayloadStatusV1/V2, ExecutionPayloadV1..V4 | execution-apis `src/schemas` + openrpc |

## Fork configuration used by the experiment

| Item | Value |
|------|-------|
| Chain id | 93471 (private devnet) |
| Genesis | `phase1h/devnet/genesis.json` (all forks at time 0) |
| Active fork at experiment time | **Amsterdam** (`amsterdamTime: 0`) |
| Client | Geth v1.17.7-stable @ 3d858f858a458effb2a563788aedf1fe65e1f0d3 |
| Method version exercised | `engine_newPayloadV5`, `engine_getPayloadV6`, `engine_forkchoiceUpdatedV4`, `engine_getPayloadBodiesByHashV2` |
| Payload structure | `ExecutionPayloadV4` (with `blockAccessList`, `slotNumber`) |
| Fork ordering check | Geth `checkFork(timestamp, forks.Amsterdam, ...)` passes for all payloads (timestamp 1700000001+) |
| Blob schedule | cancun/prague entries required by `params.ChainConfig` validation (see genesis.json) |

## Notes

- The spec evolves method versions independently per fork; this experiment
  does NOT hard-code a historical version: the method version is selected by
  the ACTIVE FORK of the payload under evaluation (Amsterdam → V5/V6/V4/V2).
- Bogota (`engine_newPayloadV6`, `engine_forkchoiceUpdatedV5`,
  inclusion lists) exists in the frozen spec but is beyond Geth v1.17.7's
  implemented surface (its `ConsensusAPI` implements through Amsterdam);
  recorded as a client-side limitation, not assumed away.
