# SRW3 Phase 1H — Provenance

## Lineage

- Branch `phase1h` created from `phase1g` @ `a71ba645fa7347a422ea968db4bc96d0f4ea75b7`
  (tag `phase1g-complete`).  Historical branches `phase1d-r1-complete`,
  `phase1e`, `phase1f`, `phase1g` untouched (verified: `git diff` of the
  frozen directories against the Phase 1G tip is empty).
- Session start: the sandbox had been reset (no K toolchain, no repo);
  recovered by cloning `origin` and checking out `phase1g`.

## Pinned external artifacts

| Artifact | Version / commit | SHA-256 |
|---|---|---|
| Geth binary | 1.17.7-stable, commit `3d858f858a458effb2a563788aedf1fe65e1f0d3` (built 2026-09-30, Go 1.27.1), from `gethstore.blob.core.windows.net/builds/geth-linux-amd64-1.17.7-3d858f85.tar.gz` | see MANIFEST (downloaded tarball re-verifiable) |
| go-ethereum source | v1.17.7 tag @ `3d858f85` (shallow clone, analysis only) | — |
| execution-apis | `3b9944a07afb53a327a3b5908a607f14b4e764d8` (2026-10-07) | `spec-baseline/SPEC-HASHES.txt` (frozen copies) |
| solc | 0.8.29+commit.ab55807c.Linux.g++ | compiled artifacts committed under `fixtures/contracts/` |
| eth-account | 0.14.0 (Python venv; tx signing only) | — |
| Python | 3.12.14 (stdlib + eth-account + reportlab for the PDF) | — |

## Deviations / disclosures (scientific honesty record)

1. **No Go toolchain in the environment.**  The experiment deliberately
   runs the OFFICIAL prebuilt Geth binary unmodified (stronger
   attribution: all client behavior is the real client's).  The in-process
   shadow hook is provided as a specification patch
   (`client/patch/srw3-shadow-hook.patch`) — **NOT BUILT**.
2. **No K toolchain in the environment.**  The frozen K machinery of
   Phases 1D-R1/1E/1F/1G stands unmodified on the baseline; Phase 1H adds
   the claim SPECIFICATION (`formal/srw3-gate-h-claims.k`) and classifies
   the ten theorem targets (`formal/THEOREM-CLASSIFICATION.md`).  No new
   kprove claims were mechanized in Phase 1H.
3. **Consensus client role simulated by the harness.**  The CL flow
   (forkchoiceUpdated/getPayload/newPayload ordering, payload attributes,
   fork choice, reorgs) is driven by `python/cl_sim.py` through the REAL
   Engine API of the REAL client.  No third-party consensus-client
   software was run; the simulation is disclosed in the report (§35
   criterion 32).
4. **Determinism conditionality.**  The CL-side payload-build retry is an
   attribute degree of freedom (changes `timestamp`); the determinism
   experiment detects/retries such runs (`rebuilt` flags) and the hazard
   is documented rather than hidden (§17).
5. **Geth build-behavior findings** (documented, not worked around
   silently): batches of 40+ heavily-conflicting SSTOREs were never
   committed into a payload; `getPayloadV6` delivers-and-closes the build
   job.
6. **Chain-config exposure:** `debug_chainConfig` absent in v1.17.7 —
   read via `admin_nodeInfo.protocols.eth.config` (recorded as NOT
   EXPOSED BY CLIENT with the mitigation).

## Reproducibility recipe (central H1/H2/H3 experiments)

```bash
# 1. binary + genesis (pinned above)
phase1h/devnet/reset_devnet.sh
# 2. scenarios H1..H10 (fresh chain each run)
rm -rf phase1h/fixtures/lineage phase1h/policy
phase1h/python/run_h.py            # venv with eth-account; geth on :8545/:8551
# 3. adversarial H-A1..H-A16
phase1h/devnet/reset_devnet.sh && rm -rf phase1h/fixtures/lineage
phase1h/python/run_adversarial.py
# 4. determinism (spawns its own two instances)
phase1h/python/run_determinism.py
# 5. consensus-visible simulation / perf / BAL
phase1h/python/run_consensus_sim.py
phase1h/python/run_perf.py
phase1h/python/run_bal_analysis.py
```

All transcripts in `transcripts/` are committed verbatim (engine logs,
Engine API call logs, SRW3 decisions, adversarial records, determinism
comparison, perf numbers, BAL analysis).
