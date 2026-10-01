from srw3.closure import security_closed
from srw3.examples import local_vs_global_counterexample
from srw3.model import State
from srw3.proof import prove_finite_closed_composition

local, composed, gate = local_vs_global_counterexample()
states = [State.make(data={"x": x, "y": y}) for x in range(0, 11) for y in range(0, 11)]

print("== Local-only model (asked to prove an interaction property without an interaction contract) ==")
closure_local = security_closed(
    local,
    {"A": (frozenset({"x"}), frozenset({"x"})), "B": (frozenset({"y"}), frozenset({"y"}))},
    (frozenset({"A", "B"}),),
    (frozenset({"x", "y"}),),
)
print(closure_local)

print("\n== Interaction-aware model ==")
closure_global = security_closed(
    composed,
    {"A": (frozenset({"x"}), frozenset({"x"})), "B": (frozenset({"y"}), frozenset({"y"}))},
    (frozenset({"A", "B"}),),
    (frozenset({"x", "y"}),),
)
print(closure_global)

result = prove_finite_closed_composition(states, composed, gate, closure_global)
print("\n== Finite proof oracle ==")
print(result)
if result.counterexamples:
    for c in result.counterexamples[:3]:
        print("COUNTEREXAMPLE:", c)
