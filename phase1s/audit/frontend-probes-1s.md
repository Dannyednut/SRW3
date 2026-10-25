# Phase 1S — Frontend Probes (audit/frontend-probes-1s.md)

Two feasibility probes were run BEFORE any Phase 1S formalization, because
the architecture of the §2/§4/§6 proofs depends on them. Raw logs:
`phase1s/transcripts/probes/`.

## Probe A — dual import of the frozen QS and 1P TDRR modules: INFEASIBLE

Importing `SRW3N-ABS-QS` and `SRW3N-ABS-TDRR` into one definition produces
inner-parser ambiguities on every shared token (`adNone`, `aOkT`, `aSrcAuth`,
…): each frozen module declares its own productions for the common command/
diagnostic sorts, and the merged definition sees two distinct
module-qualified constructors per token (`adNone_SRW3N-ABS-Q_ADiag` vs
`adNone_SRW3N-ABS-TDRR_ADiag`). `kompile` rc=113, four+ `[Error] Inner
Parser: Parsing ambiguity` diagnostics (log:
`transcripts/probes/kompile-probe-a.log`).

**Consequence of record:** a direct cross-module mechanical link against
the frozen 1P source cannot be built on the pinned frontend. This
CONFIRMS, mechanically and at the frontend level, the recorded 1Q/1P
import-contamination discipline. The integer-model side of every Phase 1S
correspondence is therefore the **in-repo verbatim mirror** declared inside
the frozen QS module itself (`absStQE` / `absStepE` / `ABSInvE` — the 1P
TDRR rows "verbatim, renamed", per the QS module's §G header). Its
provenance chain to the frozen 1P source:

1. the 1Q generator transcribed the rows verbatim from
   `phase1p/semantics/abs-machine-tdrr.k` (sha256 `448db6a4…`, anchored in
   the generator and re-verified this session — `audit/baseline-1s.md` §1);
2. the static row-witness `phase1s/scripts/verify_rows_1s.py` re-checks the
   correspondence row-by-row against the frozen 1P file (fail-closed; see
   `audit/row-witness-1s.txt`);
3. the residual trusted gap (the transcription is a Python-checked
   correspondence, not a K theorem) is DISCLOSED as TCB in
   `spec/state-correspondence.md` §5 and the final report.

## Probe B — single-import claim mechanics: VALIDATED

Four cell-wrapped claims against the frozen QS definition (definition of
record `/tmp/p1r-qs-def`, rc=0 for all; logs
`transcripts/probes/kprove_PROBE-*.log`):

| probe | statement | rc |
|---|---|---|
| `PROBE-COUNT-1` | `countToInt(succP(zeroP)) ==Int 1` | 0 |
| `PROBE-COUNT-SYMB` | `countToInt(succP(P)) ==Int countToInt(P) +Int 1` (symbolic tail) | 0 |
| `PROBE-E-STEP` | the verbatim mirror step evaluates on concrete fields | 0 |
| `PROBE-SLACK` | `countToInt(succP(succP(E0))) >=Int 0` from `countToInt(succP(E0)) >=Int 0` | 0 |

`PROBE-SLACK` is the pivotal pattern: the **arithmetic-slack propagation**
—the hypothesis is about the WRAPPED count (`succP`-headed, so it
evaluates), and the conclusion is about the doubly-wrapped count; the
induction-free span closes by evaluation + integer arithmetic. The mint
classes of the invariant-preservation chain close exactly this way. The
strip class (commit-accept) does NOT: its post-state needs the INNER
count's nonnegativity, which the wrapped hypothesis does not supply — the
exact C1.2 spot isolated by the probes, to be measured and disclosed by
the §3/§6 batteries.

Two engineering notes recorded for the runner: (a) claims must live in a
SPEC module, never in the kompiled definition (`[Error] Compiler: Claims
are not allowed in the definition`); (b) function-evaluation claims follow
the house convention of `<k>`-cell wrapping.
