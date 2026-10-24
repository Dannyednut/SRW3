# SRW3 Phase 1P — The Branch-Tag Encoding: Design Specification

**Phase:** 1P — Branch-Tagged Invariants and Universal Transition Preservation
**Status:** RECONSTRUCTION r2 (see §0)
**Level:** III only; no consensus-integration claim.

## 0. Reconstruction status (read first)

The original Phase 1P working tree (branch `phase1p-branch-tag-encoding`, session
r1) was lost to a sandbox reset BEFORE any commit or push: the workspace reverted
to the Phase-1D-era snapshot, the clone at the 1O freeze (cdb5556) was destroyed,
and the remote carries no phase1p ref. No r1 byte survives on disk (filesystem
sweep negative; the persisted session artifacts contain no phase1p content).

This r2 tree is a FAITHFUL RE-DERIVATION from the recorded r1 design summary
(the design was fully specified before the loss; the experiment results were
recorded in the session summary and are listed in §8 as the r1 expectations).
Every r2 result in this branch comes from FRESH re-execution under the pinned
toolchain (K v7.1.337 + z3 4.13.3) on the fresh clone at cdb5556 — nothing is
imported from r1. Where r2 and r1 agree, that agreement is reproduction
evidence; where they disagree, the r2 raw log decides. The r1 edit labels
E1–E8 are superseded by the r2 edit set EA–EH (§5); the generator discloses
every edit fail-closed with a roundtrip determinism check.

## 1. The experiment

Phase 1O located the exact blocker of the machine-form universal theorem:
kprove case-splits REWRITE-position constructor variables, never
function-argument ones, and its implication checker cannot evaluate a
pattern-matched function under a disjunctive state constraint
(`phase1o/proofs/repro/univ-repro.k`, probes R1–R10; the residual
`ABSInv(absStepJ(state, ground-cmd))` retained on the R machine).

Phase 1P is a CONTROLLED experiment on ONE mechanism: make the invariant's
two branches an EXPLICIT, SOLVABLE component of the state — an integer
branch tag — so that (a) the invariant becomes CONJUNCTIVE (no disjunction
for the checker to choke on), and (b) the branch becomes a first-class value
the rewrite engine can select on. The ladder T → TD → TDR adds exactly one
mechanism per rung, so the residual's MOVEMENT is attributable.

The scientific question: does the branch-tag encoding let K v7.1.337 close
the universal transition-preservation theorem mechanically?

## 2. The tagged state space (absStT)

```
syntax AStateT ::= absStT ( tag:Int      // THE BRANCH TAG: 0 = pre-init,
                          cfgP:Bool      //                     1 = initialized
                          catP:Bool
                          cntG:Int
                          cntE:Int
                          nSlot:Int
                          safe:Bool
                          diag:ADiag )
```

The tag is the FIRST field (positionally prominent; every r2 access function
and every rule pattern names it first). The tag's meaning is fixed by the
invariant, not by a new sort: 0 = the pre-init branch of ABSInv's disjunction,
1 = the initialized branch. NO new sort, NO new module boundary — the tag is
an Int so the existing INT machinery (==Int, >=Int, <=Int) does the branching.

`absGenesisT` (the tagged genesis) is `absStT(0, false, false, 0, 0, 0, false, adNone)`.

## 3. The conjunctive invariant (ABSInvT)

The 1N invariant is a two-way disjunction:

```
ABSInv(absSt(...)) => (notBool C andBool notBool T andBool G ==Int 0 andBool E ==Int 0 andBool N ==Int 0)
                  orBool (C andBool T andBool G >=Int 0 andBool E >=Int 0 andBool SF)
```

The 1O evidence says the disjunction is itself part of the blocker: under a
disjunctive constraint the implication checker cannot evaluate the matched
step function. The tagged invariant moves the disjunction into the tag and
keeps the SHAPE CONJUNCTIVE (impliesBool, never orBool at the top level,
never if-then-else):

```
ABSInvT(absStT(TG:Int, C:Bool, T:Bool, G:Int, E:Int, N:Int, SF:Bool, _:ADiag))
  => TG >=Int 0 andBool TG <=Int 1
     andBool (TG ==Int 0 impliesBool (notBool C andBool notBool T andBool G ==Int 0 andBool E ==Int 0 andBool N ==Int 0))
     andBool (TG ==Int 1 impliesBool (C andBool T andBool G >=Int 0 andBool E >=Int 0 andBool SF))
```

Content: the SAME two branches as ABSInv, byte-for-byte inside the
impliesBool consequents, plus the tag-range conjunct. Nothing is weakened:
`ABSInvT(S)` implies `ABSInv(eraseT(S))` (the CORR family, §6).

`tagCoherentT` is the tag-agreement predicate proper (the invariant minus
the range conjunct's bookkeeping role — the COH family's subject):

```
tagCoherentT(absStT(TG, C, T, G, E, N, SF, _))
  => (TG ==Int 0 impliesBool (notBool C andBool notBool T andBool G ==Int 0 andBool E ==Int 0 andBool N ==Int 0))
     andBool (TG ==Int 1 impliesBool (C andBool T andBool G >=Int 0 andBool E >=Int 0))
```

## 4. The tagged step (absStepT) — the twelve-class mirror

absStepT mirrors the M3 partition class-for-class over (tag, command, bits).
THE INIT-ACCEPT IS THE ONLY LEGAL RE-TAG (0 → 1); every other class is
tag-preserving. The class table (tag-0 rows / tag-1 rows):

| # | class | pre | cmd | post | tag |
|---|-------|-----|-----|------|-----|
| 1 | init-accept | (0,F,F,_,_,_,_,D) | aInitJ(aOkT) | (1,T,T,0,0,0,true,D) | 0→1 |
| 2 | init-refuse | (0,F,F,G,E,N,SF,D) | aInitJ(aOkF) | (0,F,F,G,E,N,SF,D) | 0 |
| 3 | init-refused (re-init) | (1,T,T,G,E,N,SF,D) | aInitJ(_:AOk) | (1,T,T,G,E,N,SF,D) | 1 |
| 4 | exec-stall (the identity convention) | (0,F,F,G,E,N,SF,D) | aExecJ(_:AOk,_:ASrc) | (0,F,F,G,E,N,SF,D) | 0 |
| 5 | gate-refuse (pre-init) | (0,F,F,G,E,N,SF,D) | aGateJ(_:AOk) | (0,F,F,G,E,N,SF,adGate,D) | 0 |
| 6 | commit-reject (pre-init) | (0,F,F,G,E,N,SF,D) | aCommitJ(_:AOk,_:AOk) | (0,F,F,G,E,N,SF,D) | 0 |
| 7 | exec-mint | (1,T,T,G,E,N,SF,D) | aExecJ(aOkT,aSrcAuth) | (1,T,T,G,E+1,N,SF,D) | 1 |
| 8 | exec-source-refuse | (1,T,T,G,E,N,SF,D) | aExecJ(aOkT,aSrcOther) | (1,T,T,G,E,N,SF,adSource,D) | 1 |
| 9 | exec-unsupported-refuse | (1,T,T,G,E,N,SF,D) | aExecJ(aOkF,_:ASrc) | (1,T,T,G,E,N,SF,adExecRefuse,D) | 1 |
| 10 | gate-mint | (1,T,T,G,E,N,SF,D) | aGateJ(aOkT) | (1,T,T,G+1,E,N,SF,D) | 1 |
|    |           | REQUIRES E >=Int 1 (T/TD) or E >=Int 1 / E <=Int 0 split (TDR) |
| 11 | commit-accept | (1,T,T,G,E,N,_,D) | aCommitJ(aOkT,aOkT) | (1,T,T,G-1,E-1,N+1,true,D) | 1 |
|    |           | REQUIRES G >=Int 1 andBool E >=Int 1 (T/TD) or explicit split (TDR) |
| 12 | commit-reject | (1,T,T,G,E,N,SF,D) | aCommitJ(aOkT,aOkF) / aCommitJ(aOkF,_:AOk) | unchanged | 1 |

Plus the INCOHERENT-TAG complement (TDR only): a state whose tag is outside
{0,1} matches no class row; the TDR function closes totality with an explicit
identity rule guarded `TG >=Int 2 orBool TG <=Int -1`. Such states are
UNREACHABLE from coherent ones (the COH family proves the step map keeps
coherent states coherent), so the complement is inert on the proof-reachable
fragment — it exists for function totality and for the prover's complement
branch, exactly as the 1O R-machine's [owise] complement did.

## 5. The ladder: T → TD → TDR (one mechanism per rung)

* **T (SRW3N-ABS-T)** — the tag encoding alone. absStT/ABSInvT/absStepT as
  above (class rows 1–12 with requires + [owise] complements, as in the 1N
  partition). The RUNNER is the 1O R-form (12 ground-command rules updating
  the shadow THROUGH the function with a SYMBOLIC shadow variable —
  `AX:AStateT => absStepT(AX, aGateJ(aOkT))`). Isolates: does the conjunctive
  tagged invariant alone unblock the implication checker?
  r1 expectation: NO — the residual keeps the 1O signature (the shadow is
  still a symbolic constructor variable in function-argument position).

* **TD (SRW3N-ABS-TD)** — T + rewrite-level tag discrimination. The runner's
  ground-command rules pattern the shadow's BRANCH (tag-0 rows match
  `absStT(0, false, false, ...)`; tag-1 rows match `absStT(1, true, true, ...)`),
  so the function call carries a tag-PINNED state. The stall discipline is
  unchanged (no tag-0 exec rule). Isolates: with the tag pinned at the
  rewrite level, does the checker evaluate absStepT?
  r1 expectation: the residual MOVES — past the 1O leaf (the original
  disjunctive obstacle is overcome) — to the Int-inequality requires of the
  guarded classes (gate-mint E>=Int 1 vs [owise]; commit-accept
  G>=Int 1 andBool E>=Int 1) under the [owise] regime.

* **TDR (SRW3N-ABS-TDR)** — TD + the requires split. The two Int-guarded
  classes are split into explicit, mutually-exclusive, exhaustive pairs:
  gate-1 = mint `requires E >=Int 1` + refuse `requires E <=Int 0`;
  commit-1 = accept `requires G >=Int 1 andBool E >=Int 1` + reject(T,F) +
  reject(F,_) + accept-complement `requires G <=Int 0 orBool E <=Int 0`.
  No [owise] survives behind an Int guard; the only [owise] is the
  incoherent-tag complement (§4). Isolates: with every requires decidable
  and the partition exhaustive, can the engine close the universal within
  budget?
  r1 expectation: failed-budget on the real machine (exploration cost over
  the rewrite branch tree + per-branch z3 implication cost); NIL closes;
  CONS does not.

The WEAK variants (`-weak-t.k`, `-weak-td.k`, `-weak-tdr.k`) carry the 1O
weak-commit edit (the presented bit carried: commit(aOkT,B2) accepts with
safe := B2 ==K aOkT) composed with each rung — the soundness controls'
subject (§7 of the proof file; the weak universal MUST FAIL).

## 6. The refinement relation (see refinement-relation.md)

eraseT: AStateT → AState drops the tag; tagSt: AState → AStateT re-derives
the tag from the branch fields (0 on the pre-init branch, 1 on the
initialized branch, and — deliberately partial-by-predicate — undefined
behavior is EXCLUDED by requiring ABSInv of the argument). The CORR family
mechanizes: T-SOUND (eraseT(absStepT(S,c)) == absStepJ(eraseT(S),c) on
coherent S), T-COMPLETE per branch (ABSInv(S) implies ABSInvT(tagSt(S))),
and the ERASE-COMMUTES per-class claims.

## 7. The claim families (the r2 inventory)

* **P1 (3)** — the standing-assumption controls carried into the tagged
  layer (the tag-range facts used by the ladder: tag∈{0,1} from ABSInvT,
  genesis coherence, tagSt-roundtrip on the branches).
* **PRESV (21)** — the branch-complete preservation family, byte-shaped as
  the 1O PRESV family (12 initialized-branch claims, 9 pre-init claims),
  restated over absStT/ABSInvT/absStepT with the tag pinned per branch.
* **COH (13)** — tagCoherentT construction (genesis) + preservation per
  class (5 pre-init rows, 8 initialized rows counting the two commit-reject
  bit shapes): coherent in → coherent out, including the 0→1 re-tag.
* **CORR (10 + TAGSOUND + TAGCOMPLETE-B1/B2/general)** — the refinement
  relation: TAGSOUND (the step commutes with erase), TAGCOMPLETE-B1/B2
  (the per-branch completeness; the GENERAL form is the disjunctive
  implication — the honest attempt is retained even though the 1O evidence
  predicts the general form cannot dispatch), and 10 ERASE-* commutations.
* **UNIV (the ladder)** — 1P-UNIV-MACHINE-T / -TD / -TDR, the PREFIX
  corollaries, the NIL/CONS diagnostics, DEST + UNSAFE-COMMIT controls.
* **NEG (the soundness battery)** — the weak-universal (MUST FAIL), the
  weak breaking run (MUST PROVE), the weak-inv Bool control (MUST FAIL),
  the two mutants (MUST FAIL), the self-assumption guard probe (MUST
  WarnTrivialClaim), the destination control (MUST FAIL).

## 8. The r1 recorded expectations (reproduction targets)

From the r1 session record (lost with the workspace; reproduced verbatim
from the session summary — these are EXPECTATIONS, not evidence):

1. 1P-UNIV-MACHINE-T: rc=1, the 1O residual signature (conjunction alone
   insufficient; the checker cannot case-split the tag in function-argument
   position).
2. 1P-UNIV-MACHINE-TD: rc=1, residual moved to
   `absStepT(absStT(1,true,true,G,E,N,SF,ADiag), aGateJ(aOkT))` — the tag
   pinned (rewrite-level branch selection WORKS; the 1O disjunctive obstacle
   overcome); new blocker = the Int-inequality requires under [owise].
3. 1P-UNIV-MACHINE-TDR: failed-budget at 280s/560s; depth-6 bounded also
   stuck; 1P-UNIV-NIL-TDR PROVED; 1P-UNIV-CONS-TDR failed >500s.
4. Lemma smoke (r1): PRESV-I-COMMIT-ACCEPT, PRESV-P-INIT-ACCEPT,
   COH-P-INIT-ACCEPT, TAGSOUND, ERASE-INIT-ACCEPT all PROVED.
5. TLR (--trusted PRESV family): also failed-budget.
6. T1–T4 toy probes: RESULT UNREAD at the loss (the r1 session's final
   action). The r2 run produces this answer for the first time on record.

The r2 verdict rule: every r2 raw log decides its own claim; r1
expectations are never substituted for a missing r2 result.

## 9. The r2 findings (post-run; the raw logs decide)

**1P-F1 (the incomplete partition).** The first r2 TDR step form split the
Int-guarded classes into requires/complement pairs but left the
(bit x pool) grid INCOMPLETE: the (aGateJ(aOkF), E >=Int 1) cell matched no
row, and the TDRR residual exposed it (the stuck leaf moved to the aOkF
shape).  The corrected form covers the grid completely: gate = row A (any
bit, E<=0) + row B (aOkT, E>=1) + row C (aOkF, E>=1); commit = row A (any
shape, G<=0 or E<=0) + rows B/C/D (the three reject/accept shapes with
G>=1 and E>=1).  The lemma family forks with the partition (the LOW/HI
claims); the LOW requires carry the invariant's lower bounds (a first
draft that omitted them failed CORRECTLY — the invariant legitimately
fails for E<0).

**1P-F2 (the evaluation frontier).** With the complete partition:
  * T (conjunctive invariant, symbolic-shadow runner): stuck — the 1O
    signature; the conjunction alone does not help.
  * TD (rewrite-level tag discrimination): stuck PAST the 1O leaf — the
    residual `absStepT(absStT(tg:1, cfgP:true, catP:true, ..., safe:true,
    ...), aGateJ(aOkT))` — THE 1O DISJUNCTIVE OBSTACLE IS OVERCOME at the
    constructor level; the new blocker is the Int-inequality requires.
  * TDR (the function-level requires split, complete partition): the
    residual is UNCHANGED from TD — a function-level split cannot help;
    the engine does not fork on function-equation requires.
  * TDRR (the runner-level fork): the gate shapes now RESOLVE (the
    single-inequality fork propagates); the residual MOVES to
    `absStepT(absStT(tg:1, ..., cntG, cntE symbolic ...), aCommitJ(aOkT, aOkF))`
    — the COMPOUND (two-variable) guard does not propagate.  Fast stuck
    (rc=1 in ~13s), NOT failed-budget: with the fork mechanism pinned
    down, the wall is reached directly.  (The r1 record's failed-budget
    TDR/TLR runs are superseded by this sharper characterization; the r1
    detail is unrecoverable and the difference is disclosed, not hidden.)
  * TLR (the trusted PRESV family over TDR): dies at the identical leaf —
    the trusted lemmas cannot apply to a term the engine cannot evaluate.

**1P-F3 (the toy answer — the r1 session's UNREAD result, produced here).**
At toy scale the TDR architecture does NOT close either: T1-TOY-TAG-UNIV
sticks at `tstep(stT(tag:S0, iv:S1), subC)` — the same Int-guard wall.
The blocker is ARCHITECTURAL (the engine's function-argument evaluation
under undecidable requires), not a scale artifact.

**The r2 verdict.** THE UNIVERSAL THEOREM IS NOT MECHANIZED on K
v7.1.337.  What the branch-tag encoding BOUGHT (all freshly mechanized,
gate green, 110 claims): the conjunctive tagged invariant, the
rewrite-level branch selection (the 1O residual's elimination), the
complete preservation/coherence/refinement families, the ground
execution evidence, and a soundness battery (weak/mutants/self/
destination) all behaving exactly as designed.  The residual frontier is
now PRECISELY: kprove v7.1.337 evaluates a pinned-branch step function
under a SINGLE-variable rewrite-fork, and stops at COMPOUND guards.
Candidate 1Q mechanisms (out of 1P scope): constructor-valued pool
occupancy (e.g. a Zero/NonZero constructor instead of the Int count —
turning the remaining Int guards into constructor splits), or a backend
that propagates compound rewrite-requires into function-argument
evaluation.
