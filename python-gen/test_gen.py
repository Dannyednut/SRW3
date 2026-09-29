#!/usr/bin/env python3
"""SRW3 Phase 1B — demos + countermodel tests for the Python generalized model.

Mirrors the K demo contract (scripts/run_gen_demos.sh) and the mandate's
countermodel obligations:
  * CM2: physical-key-footprint-only systems MUST mis-decide the aliased
    transition; the alias-aware calculus rejects the unsafe and accepts the
    safe. (permanent regression)
  * CM3: per-item membership checks are insufficient; the aggregate budget
    must be an evaluated obligation. (permanent regression)
  * AliasClosure completeness under the physical wfCheck premise.
  * membership != aggregate safety, stated as a property.
"""

import os
import sys

sys.path.insert(0, os.path.dirname(__file__))

from srw3gen_model import (  # noqa: E402
    APP_UNIVERSE, AUTH_UNIVERSE, RES_UNIVERSE, REGISTRIES, RESMAP_PQ,
    Config, applicable_gen, all_hold_g, logical_of, security_closed_gen_u, run,
)

D = dict(RESMAP_PQ)  # resmap as dict for direct closure queries

F = Config  # shorthand


def demo(cmds):
    return run(cmds, F())


# ---------------------------------------------------------------------------
# The 10 generalized demos — SAME contract table as run_gen_demos.sh
# ---------------------------------------------------------------------------

def _c(cfg):
    return dict(cfg.committed)


def _u(cfg):
    return dict(cfg.usage_c)


def test_cm2_counterexample_naive_commits_alias_unsafe():
    # A writes 5 via (appA,7); B writes 6 via the ALIAS (appB,3); both resolve
    # to resP -> IRP violated (5+6=11 > 10) but the naive registry has IRP
    # app-anchored at the primary holder only: B's write raises no obligation.
    cfg = demo([
        ("useRegistryG", "aliasNaive"), ("useResMap", "rmPQ"),
        ("init", "appA", 7, 5), ("init", "appB", 3, 0),
        ("as", "appB"), ("begin",), ("w", "appB", 3, 6), ("wfCheck",), ("gate",),
    ])
    assert cfg.result == "commit", cfg.result
    assert _c(cfg) == {("appA", 7): 5, ("appB", 3): 6}
    # the committed state violates the logical resource invariant:
    assert not all_hold_g(frozenset({"IRP"}), _c(cfg), {}, {})


def test_cm2_alias_aware_rejects_overflow():
    cfg = demo([
        ("useRegistryG", "aliasOnly"), ("useResMap", "rmPQ"),
        ("init", "appA", 7, 5), ("init", "appB", 3, 0),
        ("as", "appB"), ("begin",), ("w", "appB", 3, 6), ("wfCheck",), ("gate",),
    ])
    assert cfg.result == "reject"
    assert _c(cfg) == {("appA", 7): 5, ("appB", 3): 0}


def test_cm2_alias_aware_accepts_safe_bound():
    cfg = demo([
        ("useRegistryG", "aliasOnly"), ("useResMap", "rmPQ"),
        ("init", "appA", 7, 5), ("init", "appB", 3, 0),
        ("as", "appB"), ("begin",), ("w", "appB", 3, 4), ("wfCheck",), ("gate",),
    ])
    assert cfg.result == "commit"
    assert _c(cfg) == {("appA", 7): 5, ("appB", 3): 4}


def test_cm3_overflow_counterexample_naive_commits():
    # root budget B=10; delegate capacities 6/6; 6+6=12 > 10. Each consume
    # individually passes ICAPC/ICAPD (membership-style) -> naive commits.
    cmds = [("grant", "appB", "appB", 10), ("grant", "appC", "appB", 6),
            ("grant", "appD", "appB", 6), ("useRegistryG", "authNaive")]
    cfg = demo(cmds + [("as", "appC"), ("begin",), ("consume", "appC", 6), ("wfCheck",), ("gate",),
                       ("as", "appD"), ("begin",), ("consume", "appD", 6), ("wfCheck",), ("gate",)])
    assert cfg.result == "commit"
    assert _u(cfg) == {"appC": 6, "appD": 6}
    # committed usage violates the aggregate budget:
    assert not all_hold_g(frozenset({"IAGG"}), {}, _u(cfg),
                          {"appB": 10, "appC": 6, "appD": 6})


def test_cm3_authority_aware_rejects_overflow():
    cmds = [("grant", "appB", "appB", 10), ("grant", "appC", "appB", 6),
            ("grant", "appD", "appB", 6), ("useRegistryG", "authOnly")]
    cfg = demo(cmds + [("as", "appC"), ("begin",), ("consume", "appC", 6), ("wfCheck",), ("gate",),
                       ("as", "appD"), ("begin",), ("consume", "appD", 6), ("wfCheck",), ("gate",)])
    # first commit ok (6 <= 10 aggregate); second rejected by IAGG (6+6 > 10)
    assert cfg.result == "reject"
    assert _u(cfg) == {"appC": 6}


def test_cm3_safe_aggregate_commits():
    cmds = [("grant", "appB", "appB", 10), ("grant", "appC", "appB", 6),
            ("grant", "appD", "appB", 6), ("useRegistryG", "authOnly")]
    cfg = demo(cmds + [("as", "appC"), ("begin",), ("consume", "appC", 4), ("wfCheck",), ("gate",),
                       ("as", "appD"), ("begin",), ("consume", "appD", 5), ("wfCheck",), ("gate",)])
    assert cfg.result == "commit"
    assert _u(cfg) == {"appC": 4, "appD": 5}  # 4+5=9 <= 10


def test_multiwrite_multiresource_commits():
    cfg = demo([
        ("useRegistryG", "full"), ("useResMap", "rmPQ"),
        ("grant", "appB", "appB", 10), ("grant", "appC", "appB", 6), ("grant", "appD", "appB", 6),
        ("init", "appA", 7, 5), ("init", "appB", 3, 0), ("init", "appC", 0, 1), ("init", "appD", 0, 1),
        ("as", "appB"), ("begin",),
        ("w", "appA", 7, 2), ("w", "appB", 3, 3), ("w", "appC", 0, 1), ("w", "appD", 0, 1),
        ("consume", "appC", 4), ("wfCheck",), ("gate",),
    ])
    assert cfg.result == "commit"
    assert _c(cfg) == {("appA", 7): 2, ("appB", 3): 3, ("appC", 0): 1, ("appD", 0): 1}
    assert _u(cfg) == {"appC": 4}


def test_hidden_effect_trust_commits():
    cfg = demo([
        ("useRegistryG", "full"), ("useResMap", "rmPQ"),
        ("grant", "appB", "appB", 10), ("grant", "appC", "appB", 6), ("grant", "appD", "appB", 6),
        ("init", "appA", 7, 5), ("init", "appB", 3, 0), ("init", "appC", 0, 1), ("init", "appD", 0, 1),
        ("setPolicy", "trust"), ("as", "appB"), ("begin",),
        ("w", "appB", 3, 3), ("wH", "appD", 0, 9), ("wfCheck",), ("gate",),
    ])
    assert cfg.result == "commit"
    assert _c(cfg)[("appD", 0)] == 9  # unsafe state committed (CM7 preserved)


def test_hidden_effect_enforce_blocked():
    cfg = demo([
        ("useRegistryG", "full"), ("useResMap", "rmPQ"),
        ("grant", "appB", "appB", 10), ("grant", "appC", "appB", 6), ("grant", "appD", "appB", 6),
        ("init", "appA", 7, 5), ("init", "appB", 3, 0), ("init", "appC", 0, 1), ("init", "appD", 0, 1),
        ("setPolicy", "enforce"), ("as", "appB"), ("begin",),
        ("w", "appB", 3, 3), ("wH", "appD", 0, 9), ("wfCheck",), ("gate",),
    ])
    assert cfg.result == "blocked-effect-incomplete"


def test_alias_hidden_effect_enforce_blocked():
    cfg = demo([
        ("useRegistryG", "aliasOnly"), ("useResMap", "rmPQ"),
        ("init", "appA", 7, 5), ("init", "appB", 3, 0),
        ("as", "appB"), ("begin",), ("w", "appA", 7, 2), ("wH", "appB", 3, 9), ("wfCheck",), ("gate",),
    ])
    assert cfg.result == "blocked-effect-incomplete"


# ---------------------------------------------------------------------------
# Countermodel properties (mandate Parts II/III/V/VI)
# ---------------------------------------------------------------------------

def test_cm2_closure_captures_the_counterexample():
    # Resolves(K1) = Resolves(K2) = resP with K1 != K2:
    assert D[("appA", 7)] == D[("appB", 3)] == "resP"
    assert ("appA", 7) != ("appB", 3)
    # physical footprint {K2}; naive declared view sees only the physical key;
    # the logical closure exposes the resource the write really touches:
    phys = frozenset({("appB", 3)})
    assert logical_of(phys, D) == frozenset({"resP"})
    # applicability over the PHYSICAL footprint with the alias-aware registry
    # fires IRP (edgeR over resP) — the obligation the naive registry missed:
    assert "IRP" in applicable_gen(REGISTRIES["aliasOnly"], phys, D)
    assert "IRP" not in applicable_gen(REGISTRIES["aliasNaive"], phys, D)


def test_cm3_membership_is_not_aggregate_safety():
    # grant tree: root budget 10, delegates 6/6; b1=b2=6 each within its own
    # capacity (membership holds) while b1+b2=12 exceeds the root budget.
    cap = {"appB": 10, "appC": 6, "appD": 6}
    us = {"appC": 6, "appD": 6}
    assert all_hold_g(frozenset({"ICAPC", "ICAPD"}), {}, us, cap)      # membership holds
    assert not all_hold_g(frozenset({"IAGG"}), {}, us, cap)            # aggregate fails
    assert AUTH_UNIVERSE == frozenset({"ICAPC", "ICAPD", "IAGG"})
    # the fix is INSIDE the obligation framework: authOnly covers IAGG by an
    # edgeA whose scope spans both delegates; the gate then evaluates it.
    assert security_closed_gen_u(REGISTRIES["authOnly"], "enforce",
                                 frozenset(), frozenset(), AUTH_UNIVERSE)
    assert not security_closed_gen_u(REGISTRIES["authNaive"], "enforce",
                                     frozenset(), frozenset(), AUTH_UNIVERSE)


def test_alias_closure_completeness_under_wfcheck():
    # Part III: under the physical completeness premise FT ⊆ FD, the logical
    # closures are ordered the same way (monotonicity of logical_of).
    ft = frozenset({("appB", 3)})
    fd = frozenset({("appA", 7), ("appB", 3)})
    assert ft <= fd
    assert logical_of(ft, D) <= logical_of(fd, D)


def test_full_registry_is_closure_complete():
    assert security_closed_gen_u(REGISTRIES["full"], "enforce",
                                 APP_UNIVERSE, RES_UNIVERSE, AUTH_UNIVERSE)
    # and each naive registry fails at least one completeness conjunct:
    assert not security_closed_gen_u(REGISTRIES["aliasNaive"], "enforce",
                                     APP_UNIVERSE, RES_UNIVERSE, AUTH_UNIVERSE)
    assert not security_closed_gen_u(REGISTRIES["fullNaive"], "enforce",
                                     APP_UNIVERSE, RES_UNIVERSE, AUTH_UNIVERSE)


if __name__ == "__main__":
    sys.exit(__import__("pytest").main([__file__, "-q"]))
