# SRW3 Phase 1L — Findings Against the Frozen Semantics

Per the Phase 1L handoff §3 protocol: "If any of these do not hold in the
source, report a counterexample and stop the theorem claim until the model
is repaired in a separately justified commit."  One finding; the safety
property is NOT violated; a DIAGNOSTIC expectation is impaired.  The
Phase 1J tree is FROZEN and was NOT modified; the repair belongs to a
separately justified commit.

## L-FINDING-1: the unauthorized-source dispatch rule's lineage pattern
omits the map tail — the diagnostic is unreachable in a fully-pinned
machine (the execution is STUCK instead of refused-with-diagnostics)

**The rule** (`phase1j/semantics/srw3closure-j.k` lines 1836-1841):

```k
  rule <k> jExecDispatch(SRC:Bytes, PG:List, _:Bytes, _:Int) => .K ... </k>
       <jstate> S:Map </jstate>
       <jlineage> -1:Int |-> C:ProtoCfgR3 </jlineage>
       <jrefuse> _:JRefuse => jrefusedSource() </jrefuse>
    requires isExecOkJ(ExecFragmentJ(S:Map, PG:List))
         andBool notBool BytesEq(SRC:Bytes, qcrExecClientDOf(C:ProtoCfgR3))
```

The `<jlineage>` pattern is the SINGLE-ENTRY map `-1 |-> C` with NO tail
variable: in K, a map pattern without a tail matches only that exact map.
A fully-initialized machine's lineage contains the pins AND the receipt
pools (`-1`, `-3`, and `-2`/`-4` after the first exec) — the rule cannot
match.  Consequently, for an execution whose declared source is NOT the
pinned execution-client identity:

- in a config-pinned-WITHOUT-catalog lineage (exactly `{-1|->cfg}`), the
  diagnostic fires as intended;
- in a FULLY-PINNED machine (the normal initialized state), NO dispatch
  rule matches: the OK-mint rules require `BytesEq(SRC, client)` — false
  by hypothesis; the unsupported/bounds rules require an
  unsupported/bounds-shaped exec result — false by hypothesis (the
  result is OK-shaped); the source-refusal rule's pattern cannot match
  the lineage.  The configuration is **STUCK**: the command is never
  consumed, NO diagnostic is written, and — the safety-relevant half —
  NO receipt is minted and NO committed cell moves.

**Evidence:**
1. The K claim `L-INV-EXEC-DISPATCH-SOURCE` (the diagnostic-writing
   destination) FAILS — the retained log shows the stuck configuration
   with the dispatch term unconsumed (`transcripts/k/kprove_L-INV-EXEC-
   DISPATCH-SOURCE.log`).
2. The FROZEN 1J LLVM transcript T11
   (`phase1j/transcripts/llvm/T11-llvm-unauthorized-source-refused.txt`,
   committed at `a91dbcc`) shows the SAME stuck configuration for the
   unauthorized-source demo: `<k> jExecDispatch(...) ~> runNilJ ~> .K
   </k>` with `<jrefuse>` unchanged — the T-series record itself is the
   counterexample witness (the demo's LABEL says "REFUSED"; the machine
   is stuck, which is fail-closed but not the documented diagnostic).
3. The K claim `L-INV-EXEC-SOURCE-NOCOMMIT` PROVES the safety content:
   on every resolution path (the single-entry diagnostic branch, the
   stuck branch, any sibling not refuted by the shape constraints) no
   committed cell and no receipt pool moves.

**Impact on the handoff §3 transition facts:** item 3 ("execution refusal
leaves the committed safety state unchanged and creates no execution
receipt") HOLDS (stuck ⊆ non-committing; the claim proves it).  Item 6 of
the L claim matrix (L-A05/A06 "explicit refusal") is IMPAIRED: the
refusal is implicit (stuck) rather than the documented explicit
diagnostic in the fully-pinned state.

**Impact on the mirror:** the Python mirror implements the INTENDED
behavior (the diagnostic fires; J-A08 passes 48/48).  The K machine and
the mirror therefore DIVERGE on this one resolution — the divergence is
fail-closed in both, but it is a cross-layer conformance gap and is
recorded as such.

**Disposition:** reported; NOT repaired inside Phase 1L (the 1J tree is
frozen; a repair is a separately justified commit adding the map tail
variable to the rule's lineage pattern — the 1L ladder's
L-INV-EXEC-SOURCE-NOCOMMIT already covers the safety content of either
resolution).
