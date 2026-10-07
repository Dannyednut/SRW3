# SRW3 Phase 1H — client selection (section 4)

## Criteria (from the phase specification)

1. reproducible local execution
2. accessible Engine API
3. testnet/devnet support
4. deterministic post-execution state access
5. maintainable hook around payload execution/validation
6. sufficient access to execution traces / state-diff information
7. practical build/test environment

## Evaluation matrix

| Criterion | Geth v1.17.7 | Nethermind | Besu | Erigon | Reth |
|---|---|---|---|---|---|
| 1 reproducible local exec | **YES** — custom post-merge genesis (TTD=0) + Engine-API-only block production, deterministic attributes | yes | yes | dev-mode oriented at archive sync | yes |
| 2 accessible Engine API | **YES** — authrpc + JWT, implements through **Amsterdam** (newPayloadV5/FCUv4/getPayloadV6/getPayloadBodiesByHashV2) | yes (through Prague/Osaka; Amsterdam surface behind) | yes | yes | yes |
| 3 devnet support | **YES** — documented private-net recipe; used here | yes | yes | limited private-net docs | yes |
| 4 deterministic post-state | **YES** — state root in payload + header cross-check; `eth_getStorageAt` at block hash | yes | yes | yes | yes |
| 5 maintainable hook | **YES** — single-file insertion point (`eth/catalyst/api.go :: newPayload` → `InsertBlockWithoutSetHead`), small engine package | larger API surface (dotnet), hook spread across several projects | JVM; hook points spread | complex sync-oriented codebase | hook possible; larger unsafe surface |
| 6 trace/state-diff access | **YES** — `debug_traceBlockByHash` with callTracer + prestateTracer(diffMode) + receipts; **BAL carried IN the payload** (EIP-7928) | traces available | traces available | traces available | traces available |
| 7 build/test environment HERE | **YES** — prebuilt official binary (`gethstore`), pinned version+commit; source cloned for analysis. NOTE: no Go toolchain in this sandbox → in-process patch provided but NOT BUILT (disclosed) | requires .NET runtime (absent) | requires JVM (present) but heavy for 2-core/3GB | requires Go toolchain (absent) | requires Rust toolchain (absent), heavy build |
| Bonus: BAL (EIP-7928) | **YES** — full Amsterdam BAL construction/validation/payload transport (§19 experiment depends on it) | partial | no | no | partial |

## Decision

**Geth v1.17.7-stable** (`3d858f858a458effb2a563788aedf1fe65e1f0d3`,
built 2026-09-30, Go 1.27.1) is selected.  The decisive reasons are the
combination of (a) the ONLY client implementing the current
Amsterdam Engine API surface incl. EIP-7928 BAL end-to-end — which §2/§19
require — (b) the smallest single-function hook point (§5), (c) complete
trace/state-diff tooling, and (d) a reproducible environment from the
official prebuilt binary (client behavior therefore attributable to the
REAL client, not to a fork).

## Rejected alternatives (explicit)

- **Nethermind** — .NET runtime unavailable in the experiment environment;
  Amsterdam/BAL surface not confirmed at an equivalent level; hook point
  distributed over several projects (criterion 7, 2, 5).
- **Besu** — JVM present, but 3 GB RAM sandbox makes a JVM EL + Python
  harness + traces tight; BAL/Amsterdam surface incomplete (criterion 2, 7).
- **Erigon** — Engine API present but private-devnet flow less standard,
  no prebuilt binary path here, Go toolchain absent (criterion 3, 7).
- **Reth** — strongest BAL/Amsterdam momentum upstream, but Rust toolchain
  absent and multi-hour build on 2 cores; hook surface larger (criterion 7, 5).

## Single-client scope

Per the phase spec, ONE client is integrated.  Multi-client
interoperability requirements are DERIVED (not implemented) — see report
section 26.
