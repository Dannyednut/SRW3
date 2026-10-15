# SRW3 Phase 1L — Mechanical Rule Inventory of the Frozen J Machine

**Purpose:** the STRUCTURAL half of the induction argument (handoff §4
item 12: "structural/semantic exhaustiveness result") — no other
reachable rule writes the committed state, and the receipt
producers/consumers are closed.  The inventory is a mechanical scan of
`phase1j/semantics/srw3closure-j.k` (2,079 lines, FROZEN — byte-identical
to `phase1j-complete` @ `a91dbcc`, verified by `git diff` in the
provenance record).

## The transition rules (the complete command-tier inventory)

| rule (line) | command | writes `<jstate>` | writes slots/history | writes pools | writes heads/counters |
|---|---|---|---|---|---|
| 1689 | pInitJ (guarded) | NO (requires `.<Map>`, writes nothing) | NO | pins -1/-3 | `jhead := ProtoRootR3(C)`, `jlinhead := JLinRoot` |
| 1711 | pInitJ [owise] | no | no | no | no |
| 1733 | pExecJ (dispatch) | no | no | no | no |
| 1739 | jExecDispatch OK (pool exists) | no | no | -4 += receipt | no |
| 1761 | jExecDispatch OK (first mint) | no | no | -4 := {receipt} | no |
| 1820 | jExecDispatch unsupported | no | no | NO | `<jrefuse>` only |
| 1828 | jExecDispatch bounds | no | no | NO | `<jrefuse>` only |
| 1836 | jExecDispatch source | no | no | NO | `<jrefuse>` only (see findings.md L-FINDING-1: the lineage pattern is the single-entry map) |
| 1857 | pGateEvalJ (pool exists) | no | no | -2 += receipt | no |
| 1915 | pGateEvalJ (first mint) | no | no | -2 := {receipt} | no |
| 1983 | pCommitJ ACCEPT | **YES: `:= jerPostOf(jgExecOf(R))`** | **YES: `L3[slot <- B]`** | **consumes** -2/-4 | `jnext := N+1`, `jhead := JBlockCommitJ(B,C)`, `jlinhead := JRecChildF(jgRGOf(R))` |
| 2058 | pCommitJ [owise] | no | no | no (receipts NOT consumed) | no |

Scan method: every `rule <k>` in the command tier (lines 1668-2067)
 enumerated; each RHS cell checked for non-shared writes.  The full
 cell-level RHS of every non-commit rule is either a shared variable
 (`X:Map`, no rewrite) or a constructor/function application confined to
 `<jrefuse>`/the pools.  No rule outside the table touches the machine
 cells (the rest of the file is `[function,total]` definitions; the
 demo-module certificate command is not invoked by proofs and adds no
 machine transition).

## Consequences (each mechanized where the backend allows)

1. **L-INV-ONLY-COMMIT-MUTATES-STATE** — the sole `<jstate>`-writing rule
   is the accepted pCommitJ; every other rule leaves `<jstate>`,
   `<jnext>`, `<jhead>`, `<jlinhead>`, and the slot entries of
   `<jlineage>` unchanged.  STRUCTURAL, with the per-rule-class K claims
   (the frame/refusal/reject families of the ladder) covering every
   class the backend can carry.
2. **L-INV-RECEIPT-EXHAUSTIVE** — the exec-receipt pool is written by
   exactly the two jExecDispatch OK rules; the gate-receipt pool by
   exactly the two pGateEvalJ mint rules; the accepted commit consumes
   exactly one of each (`RS`/`ES` tails keep the rest); the [owise]
   commit consumes nothing.  STRUCTURAL + the PROVED reject claims.
3. **The sole chain-extending rule** — accepted pCommitJ, whose guard's
   SafeJ conjunct is computed over `jerPostOf(jgExecOf(R))`, the exact
   term written into `<jstate>` (the definitional identity the
   L-INV-COMMIT-ACCEPT-POSTSTATE claim states; blocked on the backend,
   B1 — the identity itself is a syntactic fact of the rule).
4. **Anchor immutability** — `<janchor>` appears in NO rule RHS (scan);
   filled only by the external input `$SRW3JANCHOR` in the configuration
   literal (line 1659).  The frame claims carry it where the backend
   allows.
