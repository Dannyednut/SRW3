# Phase 1H theorem targets H1–H10 — classification (section 28)

The phase specification requires the ten targets to be classified, not
forced into K proofs.  Statuses use the phase-1H vocabulary.  "Frozen K"
refers to the mechanized results on the `phase1g` baseline (28 kprove
claims; 21 PROVED + designed-fail canaries), which Phase 1H EXTENDS at the
client boundary without modifying it (`git diff` over `k/`, `phase1e/`,
`phase1f/`, `phase1g/` vs the Phase 1G tip is empty).

| # | Target | Classification | Evidence |
|---|--------|----------------|----------|
| H1 | client-execution binding | **DEMONSTRATED ON REAL CLIENT** + frozen-K correspondence: the 1F LEVEL-3 CORE relation (declared == execution-derived) is exercised over CLIENT-DERIVED traces; H3 tamper caught at the effect-completeness layer | `transcripts/srw3/scenarios_H.json` (H3, H-A4); `python/evidence.py` provenance |
| H2 | deterministic SRW3 evaluation | **EXPERIMENTALLY VALIDATED** (byte-identical verdicts, evidence digests, execution IDs and authority certificates across two independent Geth instances and payload replay; conditional on the canonical payload — CL-side attribute choice is a disclosed degree of freedom) | `transcripts/srw3/determinism.json` |
| H3 | state/effect evidence binding | **DEMONSTRATED ON REAL CLIENT** (payload.stateRoot == header stateRoot enforced in-adapter; client validates state root in-process against `IntermediateRoot`); the 1E authenticated-root machinery applies to the adapter binding, PROVED BY K in the frozen 1E layer | `python/evidence.py`; frozen `phase1e/` |
| H4 | authority-source preservation | **PROVED BY K** (frozen 1G NoCircularAuthority: own-id checks, strict level decrease, level-0 termination — 1G claims AZG1–AZG5) + **DEMONSTRATED ON REAL CLIENT** (H5/H8/H-A2/H-A8/H-A10 rejections at exact layers) | frozen `phase1g/proofs/`; `transcripts/adversarial/adversarial_H.json` |
| H5 | policy-context binding | **PROVED BY K** (frozen 1G record/policy binding classes) + **DEMONSTRATED ON REAL CLIENT** (H6/H7/H-A5/H-A7/H-A9) | frozen `phase1g/proofs/`; transcripts |
| H6 | shadow-mode safety | **DEMONSTRATED ON REAL CLIENT** (Ethereum VALID/INVALID behavior identical with and without the gate: H10-D block-hash equality; shadow REJECTs canonicalize) | `transcripts/srw3/determinism.json`; `scenarios_H.json` H10 |
| H7 | reorg/lineage consistency | **EXPERIMENTALLY VALIDATED** (branch switch/reorg-back; rejected commitments persist per branch and re-evaluate deterministically; head follows forkchoice; restart/replay idempotent) | `transcripts/adversarial/adversarial_H.json` (H-A6, H-A14, H-A15, H-A16) |
| H8 | failure non-bypassability | **EXPERIMENTALLY VALIDATED** at the boundary + SPECIFIED for enforcement: SRW3_ERROR is a distinct verdict class (never VALID); fail-closed in consensus-visible-sim; the "SRW3 unavailable ⇒ automatic valid" bypass exists ONLY in explicitly non-enforcing shadow mode | `scenarios_H.json` (adapter-failure records), `adversarial_H.json` (H-A11, H-A13) |
| H9 | consensus-boundary characterization | **SPECIFICATION THEOREM** (report §16) — not a mathematical claim about a model of Ethereum; demonstrated-insufficient-in-client by the consensus-visible simulation (CS2/CS3) | `transcripts/srw3/consensus_sim.json` |
| H10 | client-to-SRW3 commitment correspondence | **DEMONSTRATED ON REAL CLIENT** (payload.stateRoot == client header commitment; BAL execution-validated by client; evidence replay on an independent instance yields identical bindings) | `determinism.json`; `bal_analysis.json` |

## Not achieved mathematically in this phase (honest disclosure)

- The K toolchain was unavailable in this environment (sandbox reset; the
  frozen definitions remain on the phase1g baseline).  No NEW kprove claims
  were mechanized in Phase 1H; the claims module
  `formal/srw3-gate-h-claims.k` is a specification artifact referencing the
  frozen machinery.  Rebuilding K and mechanizing the two boundary claims
  (H1 client-bound reduction; H6 shadow-safety) remains open work that the
  frozen baseline supports.
- H2's determinism is conditional (canonical-payload-fixed); the CL-side
  attribute degree of freedom (build retries changing `timestamp`) is
  documented, not hidden.
