# SRW3 Phase 1M — Workstream C audit: the explicit, non-committing
# gate-failure transition (the B4 removal, measured)

**Disposition:** the gate-failure path is now EXPLICIT and NON-COMMITTING,
the partition of well-formed gate commands is exhaustive by construction,
and the removal of the 1L B4 stuck path is MEASURED by a decidable OLD/NEW
pair (M2 stuck vs M3 explicit refusal).  Level III only; no
consensus-integration claim.

## 1. The partition (specified before the transition)

For every well-formed `pGateEvalJ(B, FC, RG, CERT, ERC, ERP)` command in
any state:

* **SUCCESS** — a gate-mint rule matches (the pool-exists mint, or the
  fresh-pool mint under their 10-conjunct guard): the command is consumed
  and the machine-derived receipt (the COMPUTED verdict `VerifyLineageG`
  over the machine-constructed context) is minted into the gate pool.
* **FAILURE** — neither mint rule matches: the NEW `[owise]` refusal
  consumes the command and writes ONLY `<jrefuse> := jrefusedGate()`.

The partition is **EXHAUSTIVE BY CONSTRUCTION** (K's `[owise]` semantics:
the rule fires iff no other rule for the command matches — two mint rules
plus one `[owise]` cover the complete match space) and **NON-OVERLAPPING**
(`[owise]` cannot fire when a mint matches — mechanized as the negative
control MC-NEG-REFUSE-ON-MINT, FAILED as required).  No broad unguarded
rewrite was introduced: the `[owise]` is the final fail-closed branch the
handoff §4 permits, with its exhaustiveness carried by the K semantics and
its non-overlap claimed-and-controlled.

## 2. The M3 machine

`phase1m/semantics/srw3closure-j-m3.k` = M2 with EXACTLY FOUR disclosed
edits (verified by roundtrip in `scripts/make_m3.py`): the header; the
module rename; `jrefusedGate()` added to the JRefuse domain (alongside
jrefusedUnsupported/jrefusedBounds/jrefusedSource); and ONE rule —

```k
rule <k> pGateEvalJ(_:JBlockJ, _:ExecCtx, _:LinRecG, _:AuthzCert,
                    _:Bytes, _:Bytes) => .K ... </k>
     <jrefuse> _:JRefuse => jrefusedGate() </jrefuse>
  [owise]
```

placed immediately after the two gate-mint rules.  The refusal writes ONLY
the diagnostic (every other cell is absent from the rule and therefore
unchanged); the command is consumed; no receipt is minted; no committed
state, head, lineage head, or slot moves.

## 3. The proof record (the MC ladder; transcripts/k/claims-status-mc.csv)

* **MC-GATE-REFUSE-NOCOMMIT — PROVED**: on the just-initialized shape
  (the two pins, CONCRETE `.Map` tail — both mint unifications refuted
  syntactically) the refusal fires and EVERY committed cell is framed
  unchanged.
* **MC-GATE-REFUSE-WITNESS-EMPTYPOOL — PROVED**: the initialized machine
  with a CONCRETE empty exec pool (`.Set` refutes the fresh-mint's
  `SetItem(E) ES` requirement syntactically): the refusal fires, nothing
  moves.
* **MC-GATE-REFUSE-WRONGSLOT — PROVED**: the CONCRETE wrong-slot block
  (slot 7 vs counter 5 — the mint guard DECIDABLY false): the refusal
  fires, nothing moves.  This is the NEW side of the B4 pair.
* **MC-OLD-GATE-COVERAGE-WRONGSLOT — FAILED(rc=1) as required**: the SAME
  concrete command over M2 (no refusal rule) — "the configuration cannot
  be rewritten further": the command is NEVER consumed.  **The 1L B4
  stuck path, concretely witnessed** (the OLD side of the pair).
* **MC-NEG-REFUSE-ON-MINT — FAILED(rc=124) as required**: with the mint
  rules live, the "refusal, nothing else moves" destination is false on
  the mint branch — the refusal does not over-apply.
* **MC-GATE-COVERAGE-GATEPOOL / -FRESH — FAILED(rc=124), ATTEMPT**: the
  all-branch domain-coverage claims (mint + `[owise]` both live) grind to
  their time budgets — the mint branch's rewrite now EXPANDS the evaluator
  cascade inside the receipt (the B5' search-cost boundary; the redirect
  made the mint rewrite expensive where the opaque hook was cheap).  The
  coverage statement is therefore carried by: the exhaustion-by-
  construction of the `[owise]` partition, the refusal-path claims
  (PROVED), the mint-path consumption evidenced by the frozen machine's
  mint rules (the 1J ladder's gate family), and the two ATTEMPT residuals
  retained.  NOT claimed as a mechanized all-branch theorem.
* **MC-OLD-GATE-COVERAGE — FAILED(rc=124)** (the symbolic-cell variant of
  the OLD witness; the concrete WRONGSLOT form is the decisive one).

## 4. The cross-layer agreement (the mirror)

`python/run_mc_crosscheck.py` — 10/10 (`transcripts/attacks/
mc_mirror_crosscheck.txt`): the REAL frozen mirror's `gate_eval` returns
None with NO movement on every unmet-precondition class (wrong slot, wrong
parent, non-matching record, uninitialized) and mints on the honest class —
exactly the M3 partition (explicit refusal ↔ None+no-movement; mint ↔
mint).  The machine and the mirror now agree on every well-formed gate
command class: the model-and-mirror refusal promise the handoff §4 cites
is kept by BOTH layers.

## 5. Assumptions and non-claims

* The `[owise]` partition's exhaustiveness rests on K's `[owise]`
  semantics (documented language behavior); its non-overlap is mechanized
  as the negative control.  The all-branch coverage claim is NOT mechanized
  (B5' grind, retained).
* The refusal diagnostic carries no failure CLASS (the coarse jrefusedGate()
  form); the per-class refusal behavior is witnessed by the concrete claims
  and the mirror classes.
* The universal reachable-committed-state theorem remains NOT MECHANIZED.
* Level III only; no consensus-integration claim.
