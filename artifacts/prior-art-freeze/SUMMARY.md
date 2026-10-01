# Prior-Art Freeze Check — Theorem-Closure Pass (§5)

date: 2026-09-28 (UTC)
scope: bounded re-verification before freezing the conjunction-hypothesis claim,
per the audit instruction: "Before freezing this claim, check whether any prior
system combines substantially all of those properties. If a close prior system
is found, narrow the claim again rather than defending an already falsified
novelty statement."

## Queries run (raw JSON in this directory)

1. "commitment-gated execution pre-transaction invariant check commit abort
   blockchain" (freeze_3eb27b52.json)
2. "speculative transaction execution cross-contract invariant enforcement
   sequencer 2025 2026" (freeze_789e1e34.json)
3. "formally verified composition safety theorem hypergraph smart contract
   invariants K framework" (freeze_a0b879b1.json)

## Findings (nearest neighbors, none combining substantially all seven)

| system / result | what it has | what it lacks vs. the conjunction |
|---|---|---|
| guard-contract post-state assert pattern (e.g. "noyeet", DoraHacks) | in-transaction revert-condition check (level A/B of the §R taxonomy) | no hypergraph, no closure/effect-completeness conditions, no lineage, no mechanized semantics, no theorem |
| constraint-based speculative execution (Microsoft, CD-Equiv 2021) | pre-execution constraint reasoning over transaction sequences | database/TP equivalence checking; no cross-contract invariant registry, no commitment boundary, no lineage |
| VerX / DCV (declarative safety verification) | automated safety proofs of contract properties | static/offline verification; no runtime commitment gate, no hypergraph closure, no lineage, no executable semantics binding |
| audit-gated deployment protocols (SSRN) | pre-launch human audit gate | not runtime enforcement; no mechanization |
| LeVer (LLM synthesis + Lean verification) | verified synthesis loop | not a runtime commitment-gated execution model |
| Phylax Credible Layer (round-2 finding, unchanged) | builder/sequencer pre-inclusion cross-contract invariant enforcement (level B) | no explicit interaction hypergraph w/ closure-completeness, no effect-completeness (wfCheck), no lineage-anchored commitment gate, no mechanized semantics over KEVM, no compositional safety theorem |

## Conclusion

No surveyed system combines substantially all of: explicit interaction
hypergraph; closure-completeness condition; effect-completeness requirement;
commitment-gated composition; lineage structure; executable mechanization over
KEVM; compositional safety theorem. The corrected prior-art position of the
Round-2 audit (§Q.3 of the report) is RETAINED UNCHANGED and may now be frozen:

* NOT claimed as novel: pre-inclusion invariant enforcement (Phylax et al.);
  cross-contract invariant checking; formal invariant verification;
  lineage/hash chains.
* Claimed as a CONJUNCTION HYPOTHESIS (falsifiable, per-system rebuttal table
  above): the seven-element combination, mechanized end-to-end over KEVM with
  a machine-checked lineage-length safety theorem (now including the
  ghost-state closure of this pass).

Evidence: this directory's three JSON files (fetched 2026-09-28) plus the
round-2 evidence in ../SUMMARY.md (19 searches, primary-source reads).
