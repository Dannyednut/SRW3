# SRW3 Phase 1J — SECURITY CLOSURE AUDIT (SECURITY-CLOSURE-AUDIT.md)

**Phase:** 1J — Reachability Safety Closure & Execution-Evidence Completeness
**Branch:** `phase1j-security-closure` (additive tree `phase1j/` only)
**Frozen base:** `8a520fd8a3d4651b0884a59e8db8aec1d3eb7670` (`phase1i-r3-complete`)
**Audit scope:** the J machine, its proof ladder, the concrete execution
evidence, and the completion-gate claims of the handoff (§12).  This audit is
part of the deliverable and is written to be independently checkable: every
claim below names its artifact.

---

## A. Rule-set / surface audit (the command language)

The J machine (`phase1j/semantics/srw3closure-j.k`, module `SRW3CLOSURE-J`)
imports ONLY the frozen Phase 1G gate (`SRW3AUTHZ`, down to the unchanged
`srw3lin.k` + `krypto.md`).  It does NOT import SRW3PROTO-R3 or any earlier
protocol machine (handoff §2).  The command language is exactly:

```
PCmdJI ::= pInitJ(ProtoCfgR3, JCatalog)
         | pExecJ(Bytes /*declared source*/, List /*fragment program*/,
                  Bytes /*caller*/, Int /*value*/)
         | pGateEvalJ(JBlockJ, ExecCtx, LinRecG, AuthzCert, Bytes, Bytes)
         | pCommitJ(JBlockJ, Bytes, Bytes, Int)
```

- **Legacy surface excluded.** The 1I/R1/R2/R3 command names are not declared
  and no rule matches them: `transcripts/llvm/T15a/T15b` (kparse rejections,
  exit 113).  `pInitJ` takes NO anchor/root argument: `T15c` (kparse).
- **Producer exhaustiveness.** `pExecJ` is the ONLY producer of
  `jExecReceipt`; `pGateEvalJ` is the ONLY producer of `jGateReceipt`; the
  verdict field of a gate receipt is written ONLY by the mint, as the result
  of the frozen `VerifyLineageG` over the machine-constructed context
  (`azCtx(FC, ProtoAuthorizedSecCtxR3(C, jbParentRootOf(B)), CERT, pinned
  fields 11..13)`).  Mechanical check: the receipt constructors appear in
  exactly these two rules and in no other rewrite in `srw3closure-j.k`
  (grep `jExecReceipt(` / `jGateReceipt(` — 2 mint sites, both in the
  commands above).
- **No caller verdict/coverage/policy Boolean exists.** No command has a
  verdict-, trace-, post-state-, coverage-, authenticity- or policy-shaped
  argument (the forbidden patterns of handoff §4.2).  Injection shapes are
  ILL-FORMED: `T14a` (a verdict string on pGateEvalJ), `T14b` (a coverage
  Boolean on pCommitJ).  The Python mirror's API mirrors the command
  language 1:1 (`J-A15` checks the signatures).
- **The anchor is not caller data.** `<janchor>` is filled by
  `$SRW3JANCHOR` (the explicit authenticated external input) and written by
  NO rule of the definition (immutability by construction; the per-rule
  frame: no rule mentions `<janchor>` on a rewrite side — the init rule only
  reads it).  A wrong-anchor machine refuses the honest config: `T8`.
- **One chain-extending rule.** `pCommitJ`'s accept rule is the only rule
  that updates `<jlineage>` slot entries, `<jhead>`, `<jlinhead>`,
  `<jnext>`, or moves `<jstate>`.  The exec/gate commands mutate only the
  receipt pools / the refusal diagnostics.  `J-A23` (Python) demonstrates
  that post-commit exec+gate commands move nothing.

## B. The frozen-base audit (byte stability, handoff §2/§12)

- `git diff 8a520fd -- . ':!phase1j'` is EMPTY: every frozen tree
  (phase1e…phase1i-r3, k/, scripts/, transcripts/) is byte-identical to the
  R3 base.  Artifact: `transcripts/regression/regression.txt`.
- The R3 formulas the J machine must preserve are REPRODUCED with identical
  tags/composition (the R3 domain string, `U32BE(1)`, `LP32`; the frozen
  0x9D/0xA5/0xA6 policy-commitment and ctx-digest formulas; decisions):
  `J-CORRESPONDENCE-R3-CANON-PREFIX` and `J-CORRESPONDENCE-CTX-TAG` PROVED;
  cross-language byte conformance in `vectors/j_golden.json` (the Python
  mirror computes `policy_commitment_r3` from the SAME pack encoder the R3
  phase integrated verbatim).
- The J canonical encodings use NEW namespaces only: catalog
  `"SRW3/PolicyCat/J"||0x00`, evidence `"SRW3/Evidence/J"||0x00`, tags
  0xB1/0xB2/0xB3/0xB4/0xB5/0xB6/0xB7 — distinct from every frozen tag
  (0x00-0x02, 0x03/0x11/0x12/0x13/0x1F/0x57, 0x9C-0x9F/0xA5/0xA6).  The
  payload digest reuses the FROZEN 1F formula (`Keccak(0x11||bytes)`) over
  the J program bytes so the candidate, the exec receipt, and the frozen
  certificate share ONE payload identity (documented in the K source §D).

## C. Proof-inventory reconciliation (handoff §9)

- One source of truth: `proofs/run_j_proofs.sh`'s `J_CLAIMS` array (42
  labels) — each invoked exactly once per canonical run, raw exit code +
  retained log in `transcripts/k/`.
- `transcripts/k/claims-status.csv` (raw) + `claim-classification.csv`
  (scientific labels) + `score.txt` (`38 4`, 1:1 over the inventory — the
  R3 convention; no ambiguous scores).
- The four retained failures are classified, never relabeled:
  1. `J-EVIDENCE-STATE-CORRESPONDENCE` — hs keccak boundary (the fixture
     digests/records cannot evaluate on hs); DEMONSTRATED on LLVM (T1/T3:
     the mint FIRES, which requires the record/block binding with real
     keccak) and CHECKED in Python (`exec_receipt_matches_*`).
  2. `J-COMMIT-IMPLIES-SAFE-DESTINATION` — the honest-pipeline claim (the
     R3 PIPELINE-HONEST class); DEMONSTRATED on LLVM T1/T2; CHECKED in
     Python (HONEST-1BLOCK/2BLOCK).
  3. `J-COMMIT-UNSAFE-COMPOSITION-REJECTS` — the unsafe pipeline claim; the
     commit-boundary countermodel is DEMONSTRATED on LLVM T6 (state/head/
     counter unchanged, receipts unconsumed) and CHECKED in Python (J-A13).
  4. `J-REACHABLE-COMMITTED-SAFE` — the kore stuck-configuration/
     circularity blocker (the frozen PI7-ALL/R1-ALL/R2-ALL/R3-ALL class);
     the failed log is retained; the closure evidence is the PROVED
     component lemmas + the Python sequence enumeration + LLVM T2.
- The universal theorem was NOT proved by assuming its conclusion: `SafeJ`
  appears in the guard (computed) and in destinations, never as a hypothesis
  of a preservation claim.

## D. The completion gate (handoff §12), item by item

| Gate item | Status | Artifact |
|---|---|---|
| isolated model compiles on declared backends | hs + LLVM kompile green | `transcripts/k/kompile_j.log`, `transcripts/k/j_llvm_shim_build.log` |
| claim inventory and per-claim exit-status files reconcile | 42 labels, 1:1, raw logs | `transcripts/k/claims-status.csv`, `claim-classification.csv`, `score.txt` |
| base/step/reachable safety proved or explicitly not mechanized | base J-INIT-SAFE-BASE PROVED; step = the computed guard + J-SAFE-* PROVED; reachability NOT MECHANIZED (retained log) + substitutes | `transcripts/k/`, `transcripts/attacks/run_j_attacks.txt` |
| catalog bytes checked against configured digests; 3-app countermodel | J-CATALOG-CANON-FIXTURE (byte-level), J-CATALOG-BINDS-GRAPH, J-INIT-REFUSES-GRAPH-MISMATCH PROVED; T7 (LLVM, real keccak); J-A13 (K PROVED + LLVM T6 + Python) | as listed |
| the closed-fragment boundary rejects every excluded effect class | J-FRAG-UNSUPPORTED/-MIDPROGRAM/-BOUNDS PROVED; T9/T10 (LLVM); J-A06 (4 excluded classes + mid-program) | as listed |
| evidence derived by the semantics, not asserted by a caller | rule inventory (audit A); J-FRAG-* PROVED; T14a/b ill-formed; J-A01..A05 Python | as listed |
| Python and LLVM canonical identities agree byte-for-byte | 22/22 fields (canon bytes, roots, state roots, trace/footprint digests, payload digest, policy ctx, evidence id, block commit, cert id; verdicts normalized per the disclosed R2/R3 mirror artifact) | `vectors/j_golden.json` vs `transcripts/llvm/T0` |
| all frozen regression suites zero drift | frozen trees byte-identical (git diff empty); 1E OK, 1F 16/16, 1G 25/25, R1 48/48, R2 87/87, R3 181/181; 1J Python 48/48 + 27/27 unittests | `transcripts/regression/regression.txt` |
| exclusions, liveness costs, trust assumptions, failed attempts, client boundaries reported | report §Assumptions/§Limitations; this audit C/E | `report/SRW3-Phase1J-Security-Closure-Report.md` |
| frozen trees before `phase1j/` byte-identical to the R3 base | git diff empty | `transcripts/regression/regression.txt` |

## E. Assumption register (nothing hidden)

1. **ASSUMED** — the trusted R3 configuration-root anchor (`$SRW3JANCHOR`)
   is authenticated and stable for the considered run; governance/root
   authority remains outside the model (the R3 disposition, unchanged).
2. **ASSUMED** — Keccak-256 collision resistance (all hash-root
   distinctions; never claimed as injectivity).
3. **ASSUMED** — the frozen Phase 1G gate's soundness as used (mechanized
   in Phase 1G; the J machine consumes `VerifyLineageG` unchanged).
4. **ASSUMED** — the registered invariant language IS the intended policy
   (the finite typed fragment: bounds/sum/eq over the registered resources);
   the arbitrary-policy closure is NOT mechanized and is reported open.
5. **ASSUMED** — the declared execution source is the pinned
   execution-client identity (config field 7); the machine refuses other
   sources (J-A08) but does not model the client's own integrity.
6. **ASSUMED** — historical trace AUTHENTICITY beyond the modeled fragment
   (the 1F/1G input-side boundary): the J theorem establishes DERIVATION +
   CORRESPONDENCE + COVERAGE for `EVM_F` (Option A), not unrestricted
   Ethereum execution.  Option B (full-EVM evidence) remains OPEN.
7. **Level III only** — no consensus-integration claim; the off-chain gate
   result is not a real consensus rule (the 1H Geth adapter was a shadow
   boundary and remains one).
8. **Liveness cost** — fail-closed availability: a commit whose receipts,
   closure, or invariant data is missing/unavailable simply never fires
   (the [owise] refuse is a non-committing defer); unavailability is never
   interpreted as acceptance.

## F. Negative-control inventory (the attack matrix, handoff §8)

All 24 classes are implemented and PASS: `transcripts/attacks/
run_j_attacks.txt` (48 checks, 48 PASS) + the K/LLVM/hs equivalents listed
in `claim-classification.csv` (J-A01..A24 cross-references).  Highlights:
J-A13 (the 3-app countermodel) is proved at the K level
(J-SAFE-UNSAFE-COMPOSITION), demonstrated at the commit boundary on LLVM
(T6), and checked in Python with the full receipt discipline; J-A01..A05
(the caller-evidence classes) are excluded structurally AND by the derived-
binding checks; J-A18 (closure exhaustion) refuses both in K
(J-CLOSURE-EXHAUSTED) and Python.

## G. What this phase does NOT claim

- NOT a proof that every presented trace is historically true (the
  trace-origin result is derivation+correspondence within `EVM_F`).
- NOT full-EVM evidence coverage (LOGn/CREATE/DELEGATECALL/SELFDESTRUCT/
  gas/memory/precompiles/system operations are OUTSIDE the fragment and
  REFUSE — never approximated).
- NOT arbitrary-policy closure (the typed fragment only; the
  arbitrary-policy theorem is NOT MECHANIZED).
- NOT end-to-end Ethereum enforcement (no client/protocol integration).
- NOT protocol-root governance (the anchor is an explicit external
  assumption, inherited from R3).
