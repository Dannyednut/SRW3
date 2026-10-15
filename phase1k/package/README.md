# SRW3 Implementation Package

**Package version 1.0.0 (Phase 1K)** · content base `phase1j-security-closure`
@ `a91dbcc` (`phase1j-complete`) · claims level **III**

This package assembles the verified SRW3 deliverable surface — the executable
Python mirror driving the real frozen authorization gate, the golden
conformance vectors, the test and adversarial suites, and the K proof-tier
sources — into one self-contained, byte-identity-certified tree.  Every
packaged artifact is a byte-identical copy of a file committed in the frozen
phase trees (`phase1e` … `phase1j`); the certificate is
`executions/byte-identity.txt` (45/45 identical at packaging time) and the
self-integrity manifest is `MANIFEST.sha256`.

## What this is (and is not)

- **IS**: the Level-III model implementation of the SRW3 commitment pipeline —
  configuration root (R3, 13 fields), policy catalog (1J), closed execution
  fragment `EVM_F` (4-op), derived evidence (trace/footprint/post-state),
  two single-producer receipts, the frozen 21-conjunct gate
  (`verify_lineage_g`), independent safety evaluation (`SafeJ`), and the
  fail-closed commit boundary (`pCommitJ` requirement classes) — with the
  adversarial suites (1E/1F/1G/R1/R2/R3/1J) and the golden vectors.
- **IS NOT**: end-to-end Ethereum enforcement.  There is no consensus
  integration, no client/protocol change, no protocol-root governance (the
  anchor is an explicit external assumption), and no full-EVM evidence
  coverage (Option B remains open).  See `INTEGRATION-GUIDE.md` §Non-claims.

## Quickstart

```sh
./install.sh                      # self-integrity + path-compat layer
./run_all.sh   [OUT-DIR]          # full Python verification tier
./verify_all.sh                   # MANIFEST byte-stability (incl. regenerated vectors)
```

Expected results at the content base (all fresh-run reproducible):

| tier | suite | result |
|---|---|---|
| unittests | 1J `test_security_closure.py` | 27/27 OK |
| adversarial | 1J attack matrix J-A01..A24 + honest + determinism + enumeration | 48/48 PASS |
| regression | R3 adversarial suite | 181/181 PASS |
| regression | R2 adversarial suite | 87/87 PASS |
| regression | R1 adversarial suite | 48/48 PASS |
| regression | 1G Python suite | 25/25 PASS |
| regression | 1F Python suite | 16/16 PASS (+3/3 byte checks) |
| regression | 1E Python suite | all PASS |

## Layout

```
package/
  VERSION                  package identity + lineage
  README.md                this file
  INTEGRATION-GUIDE.md     surface reference, inputs, fail-closed semantics, non-claims
  CLAIMS-INDEX.md          reconciled proof inventory across 1E..1J with statuses
  install.sh               self-integrity + the disclosed path-compat layer
  run_all.sh               the Python verification tier from THIS tree
  verify_all.sh            manifest byte-stability (vectors included)
  MANIFEST.sha256          sha256 of every packaged file (byte-stability oracle)
  python-gen/              the lineage verifier core (lin_verify.py)
  phase1e/python/          authenticated state model + suite
  phase1f/python/          execution-evidence model + suite
  phase1g/python/          THE FROZEN GATE (authz_model.verify_lineage_g) + suite
  phase1i-r1/python/       R1 commitment/gate binding + suite
  phase1i-r2/python/       R2 gate-verdict provenance + suite
  phase1i-r3/python/       R3 full configuration-root binding + suite
  phase1i-r3/vectors/      the R3 golden vectors (349-byte preimage, mutations)
  phase1j/python/          the J machine mirror (catalog, EVM_F, receipts,
                           closure, SafeJ, evidence identity, commit) + runner
  phase1j/tests/           the 1J unittest suite
  phase1j/vectors/         j_golden.json — the cross-layer conformance vectors
  semantics/               K proof-tier SOURCES (byte-identical): the frozen
                           gate definition (1G), the R3 machine, the J machine,
                           and their kprove ladders
```

## The one architectural rule

Authority is never self-authorized.  The gate verdict is **computed** by the
frozen gate from machine-constructed inputs (never accepted from a caller),
the commit boundary re-checks every `Commit_P` conjunct against the pinned,
anchor-authenticated configuration, and unavailable evidence refuses —
`EvidenceMissing ⇏ SRW3Valid`.  The 1J mirror demonstrates the composition
directly: the gate *accepts* the unsafe record (authority layer) while the
commit boundary still *refuses* it (policy layer) — two distinct layers,
composed fail-closed.
