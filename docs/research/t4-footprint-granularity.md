# T4 — Footprint Granularity Across the Abstract Layers

**Status: documented distinction (Phase 1U workstream E). No equivalence
claim is made across the granularity boundary.**

## The two granularities

| | Original abstract model (`k/srw3.k`) | Generalized model (`k/srw3gen.k`) |
|---|---|---|
| Footprint item | **AppId** — one item per application touched by the transition | **StKey / AppId** — one item per storage key written and per application read/consumed |
| Write effect | `w(I,S,V)` adds `SetItem(I)` to `<footprint-t>/<footprint-d>` | `w(I,S,V)` adds `SetItem(stK(I,S))` to both footprints |
| Read effect | `rd(I)` adds `SetItem(I)` | `rd(I)` adds `SetItem(I)` (app-level; reads are not key-addressed at this layer) |
| wfCheck (enforce) | `subset(FT, FD)` over **app sets** | `subset(FT, FD)` over the **mixed key/app set** |
| Obligation applicability | `applicable(edges, app-footprint)` — an edge fires iff its app set intersects the footprint | `applicableGen(edges, key-footprint, resmap)` — an edge fires iff its dependency set intersects the (alias-closed) footprint |

## Which effect-completeness property each layer claims

- **Original model (`srw3.k`)**: *app-granular effect completeness* —
  "every application whose storage the transition touched is declared."
  A transition that writes TWO slots of the SAME app declares one footprint
  item. The wfCheck gate therefore proves: the true app-level read/write set
  is covered by the declared abstraction. It does **not** prove slot-level
  coverage.
- **Generalized model (`srw3gen.k`)**: *storage-key-granular effect
  completeness* — "every (account, storage-slot) key the transition wrote is
  declared, and every application whose authority it consumed is declared,
  with the alias closure (CM2) applied at the gate." This is strictly finer
  information, and the obligation applicability uses it (resource-scoped
  edges `edgeR` / alias resolution over `<resmap>`).

## Consequences (what may and may not be claimed)

1. The two layers both satisfy the SAME abstract schema
   (Γ* ⊆ Γ̂ at their respective granularity, obligation applicability over
   the declared footprint, one commit path, lineage on accept), but the
   properties are **not** the same predicate: app-granular coverage does not
   imply key-granular coverage (a transition may declare app A while writing
   an undeclared slot of A — hidden at layer 1, caught at layer 2), and
   key-granular coverage does not trivially refine to the app-level
   statement without the app-projection argument.
2. The demo `gen_hidden_enforce.srw3` exhibits a key-level declaration gap
   that the generalized wfCheck blocks; the corresponding minimal-model demo
   (`demo4_hidden_enforce.srw3`) blocks a *cross-app* hidden write. The two
   exhibits are analogous but not equivalent.
3. The per-class image correspondence and the ghost-fidelity layers are
   stated and verified WITHIN each layer. No bisimulation or representation
   equivalence between the two granularities is claimed anywhere in the
   project record — establishing (or refuting) such a correspondence is a
   separate research obligation, listed as open in
   `STATE-OF-RECORD.md` §Open residuals.
4. Any future claim of "the generalized model refines the minimal model"
   must first state the footprint-projection map
   (key-granular → app-granular via `app:StKey`) and discharge the
   coverage-reflection obligation; until then the layers stand side by side.

## Cross-references

- Examiner finding T4 (independent examination v1.2 lead, validated by
  source inspection in Phase 1U).
- ThewfCheck rules: `k/srw3.k` (SRW3-GATE) and `k/srw3gen.k` (SRW3G-GATE).
- The obligation applicability definitions: `applicable` / `applicableGen`.
- The alias-closure discipline (CM2) is generalized-model-only; the minimal
  model has no alias dimension.
