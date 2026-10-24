# SRW3 Phase 1P — The Refinement Relation: erase / tag / branchTag

**Phase:** 1P — Branch-Tagged Invariants and Universal Transition Preservation
**Status:** RECONSTRUCTION r2 (see branch-tag-design.md §0)
**Level:** III only; no consensus-integration claim.

## 1. The three functions

```
syntax AState ::= eraseT ( AStateT )   [function, total]
rule eraseT(absStT(_:Int, C:Bool, T:Bool, G:Int, E:Int, N:Int, SF:Bool, D:ADiag))
  => absSt(C, T, G, E, N, SF, D)

syntax AStateT ::= tagSt ( AState )    [function, total]
rule tagSt(absSt(C:Bool, T:Bool, G:Int, E:Int, N:Int, SF:Bool, D:ADiag))
  => absStT(branchTag(C, T), C, T, G, E, N, SF, D)

syntax Int ::= branchTag ( Bool , Bool ) [function, total]
rule branchTag(true,  true)  => 1
rule branchTag(false, false) => 0
```

* **eraseT** forgets the tag. It is the abstraction map from the tagged
  refinement layer back down to the frozen 1N state space. Total by
  construction (the tag is dropped, every other field passes through).
* **branchTag** reads the branch off the pin pair. It is total on the four
  Bool pairs but MEANINGFUL only on the invariant's two reachable pairs:
  (false,false) → 0 and (true,true) → 1. The mixed pairs (true,false) and
  (false,true) are unreachable under ABSInv (the 1N invariant's two
  branches both constrain the pin pair); on those the function still
  returns a value (0) but the value carries no refinement content —
  the CORR claims are restricted to ABSInv states, which excludes them.
  This is the declared, disclosed boundary — NOT a silent assumption:
  every CORR claim's requires carries ABSInv/branch membership explicitly.
* **tagSt** injects a 1N state into the tagged space at the branch its
  pins determine. On ABSInv states the result is tag-coherent by
  TAGCOMPLETE-B1/B2.

## 2. The soundness direction (T-SOUND / 1P-TAGSOUND)

The tagged machine must SIMULATE the frozen 1N machine: erasing the tag
from a tagged step yields the 1N step of the erased state, class by class.

```
1P-TAGSOUND:  tagCoherentT(S) impliesBool
              eraseT(absStepT(S, C)) ==K absStepJ(eraseT(S), C)
```

stated per reachable (branch, command-class) pair as the ERASE-* family
(the implication-checked general form is ALSO attempted — 1P-TAGSOUND —
and whatever the checker does with it is recorded; the per-class forms are
the mechanized content). Why per class: the 1O evidence says the checker
evaluates a matched function only under a conjunction of decidable facts;
the per-class claims hand it exactly that.

Class table of the ERASE-* family (10 claims — every REACHABLE
(branch, command-class) pair; the exec-stall row is reachable only as a
machine stall and is covered by the pre-init row):

| claim | branch | command | content |
|-------|--------|---------|---------|
| 1P-ERASE-INIT-ACCEPT | pre-init | aInitJ(aOkT) | re-tag commutes (0→1 vs the 1N accept) |
| 1P-ERASE-INIT-REFUSE | pre-init | aInitJ(aOkF) | both machines stutter |
| 1P-ERASE-EXEC-MINT | init | aExecJ(aOkT,aSrcAuth) | E+1 commutes |
| 1P-ERASE-EXEC-SOURCE | init | aExecJ(aOkT,aSrcOther) | adSource commutes |
| 1P-ERASE-EXEC-REFUSE | init | aExecJ(aOkF,_:ASrc) | adExecRefuse commutes |
| 1P-ERASE-GATE-MINT | init | aGateJ(aOkT), E>=1 | G+1 commutes |
| 1P-ERASE-GATE-REFUSE | init | aGateJ(_:AOk), E<=0 | adGate commutes (split form) |
| 1P-ERASE-COMMIT-ACCEPT | init | aCommitJ(aOkT,aOkT), G>=1∧E>=1 | G-1,E-1,N+1,SF:=true commutes |
| 1P-ERASE-COMMIT-REJECT | init | the reject shapes | unchanged commutes |
| 1P-ERASE-PROJECTIONS | both | — | absCfgPinnedOf/absCatPinnedOf/absSafeOf commute with eraseT |

## 3. The completeness direction (T-COMPLETE)

The tagged space must carry every 1N invariant state:

```
1P-TAGCOMPLETE-B1 (pre-init branch): ABSInv(absSt(false,false,G,E,N,SF,D))
                                     impliesBool ABSInvT(tagSt(absSt(false,false,G,E,N,SF,D)))
1P-TAGCOMPLETE-B2 (initialized):     ABSInv(absSt(true,true,G,E,N,SF,D))
                                     impliesBool ABSInvT(tagSt(absSt(true,true,G,E,N,SF,D)))
1P-TAGCOMPLETE (general form):       ABSInv(S) impliesBool ABSInvT(tagSt(S))
```

The B1/B2 forms are the mechanizable content (each pins the branch, so the
impliesBool consequents evaluate). The GENERAL form is the disjunctive
implication the 1O evidence predicts the checker cannot dispatch — it is
stated and attempted ANYWAY, honestly, because the experiment's value is
the residual's exact location, not a green gate.

## 4. What the refinement buys the universal theorem

IF the ladder closes the tagged universal (ABSInvT preserved along every
responded tagged run), THEN the 1N universal follows for the ABSInv state
space: tagSt injects (T-COMPLETE), the tagged run simulates the 1N run
(T-SOUND per class), and eraseT projects the final tagged state back onto
the 1N final state with ABSInv(eraseT(S)) from ABSInvT(S) (the invariant
implication, §3 of branch-tag-design.md). The composition is the
refinement lift:

    ABSInv(S0)  ─tagSt→  ABSInvT(S0')  ─(the tagged universal)→  ABSInvT(Sn')
                        ─eraseT─∘─T-SOUND─→                      ↓ eraseT
    ABSInv(S0)  ──────────(the 1N machine)──────────────────→  ABSInv(Sn)

Phase 1P mechanizes the middle arrow's ingredients (PRESV/COH per class)
and attempts the middle arrow itself (the UNIV ladder). The composition
THEOREM (the lift as one claim) is OUT OF 1P SCOPE — it is stated in the
report's open-items section, not smuggled into a green column.

## 5. Disclosure

eraseT/branchTag are NEW total functions on NEW syntax (absStT already
exists on the T rungs); they modify NO frozen rule and NO 1N definition.
tagSt is partial-by-predicate in the sense of §1 (mixed pin pairs excluded
by requires at every use). The refinement relation introduces NO new
standing assumption: P1's three claims restate tag facts derivable from
ABSInvT itself.
