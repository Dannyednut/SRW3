# SRW3 Phase 0-D — Implementation Status

Date: 2026-09-25

## Executed in the current environment

- Python reference semantics compiled successfully with `python -m compileall`.
- 15 unit/regression tests pass.
- Finite proof oracle runs over 121 finite states for the interaction-aware countermodel and certifies the modeled one-step safety condition.
- The same proof pipeline rejects the under-specified local-only composition because its required interaction contract is absent.
- Hidden-effect under-approximation is detected as an explicit closure failure.
- The Oracle -> Lending -> Liquidator model is executable as a finite reference example.

## Important interpretation

The finite proof oracle is a reference checker for the abstract model. It is not a machine-checked theorem in KEVM/K, and it is not a production security guarantee.

## K/KEVM status

The current environment does not contain `kompile`, `krun`, or `kprove`, so the K layer has been authored as a mechanization scaffold but has not been compiled here.

The current KEVM repository pins K `v7.1.337` in its Nix flake (June 2026). The official K installation documentation recommends `kup`, binary packages, or Docker for installation.

## Phase-0-D theorem target

    SecurityClosed_P(A)
    && InitialSafe_P(A)
    && GateComplete_P(A)
    && ContractSound_P(A)
    ==> ReachCommitted(A) subset Safe(P)

The implementation currently verifies this shape only for the finite executable reference fragment. The next formal step is to express the same transition/gate rules as K claims over the KEVM configuration and obtain an actual proof/refutation.
