#!/usr/bin/env python3
"""SRW3 Phase 1B — Python mirror of k/srw3gen.k (generalized semantics).

Independent cross-check oracle for the generalized commitment-gated calculus:
  * CM2 resource aliasing  : Resolves (resmap), AliasClosure = logicalOf,
                             resource-scope applicability (edgeR).
  * CM3 aggregate authority: bounded delegation (cap/parent), consumed usage
                             through the commitment boundary (usage-c/usage-p),
                             the aggregate budget as an EVALUATED obligation.
  * Generalized transitions: finite write/read/consume sequences, physical-key
                             granular footprints.

Mirrors the K modules 1:1 (SRW3G-STATE / -INVAR / -CLOSURE / -GATE). Any
divergence between this model and the K semantics is a defect to investigate,
not to paper over — the tests assert the SAME decision table as
scripts/run_gen_demos.sh.

No-hidden-axiom contract (inherited): every invariant is an evaluated
equation; the gate accepts by computing all applicable obligations; the ONLY
transition that updates committed/usage_c is the gate accept.
"""

from __future__ import annotations

from dataclasses import dataclass, field, replace
from typing import FrozenSet, Mapping, Tuple

# ---------------------------------------------------------------------------
# SRW3G-SYNTAX: identifiers
# ---------------------------------------------------------------------------
AppId = str          # noOne, appA, appB, appC, appD
InvId = str          # IA7 IB3 IC0 ID0 IRP IRQ ICAPC ICAPD IAGG
StKey = Tuple[str, int]          # stK(app, slot)
ResourceId = str                 # noRes, resP, resQ
Edge = tuple                     # ("edge", inv, {..}) | ("edgeR", ..) | ("edgeA", ..) | ("bareEdge", ..)
Policy = str                     # "enforce" | "trust"

APPS = ("appA", "appB", "appC", "appD")


# ---------------------------------------------------------------------------
# SRW3G-STATE: configuration
# ---------------------------------------------------------------------------
@dataclass(frozen=True)
class Config:
    committed: Tuple[Tuple[StKey, int], ...] = ()
    prospective: Tuple[Tuple[StKey, int], ...] = ()
    usage_c: Tuple[Tuple[AppId, int], ...] = ()
    usage_p: Tuple[Tuple[AppId, int], ...] = ()
    cap: Tuple[Tuple[AppId, int], ...] = ()
    parent: Tuple[Tuple[AppId, AppId], ...] = ()
    resmap: Tuple[Tuple[StKey, ResourceId], ...] = ()
    footprint_t: FrozenSet = field(default_factory=frozenset)
    footprint_d: FrozenSet = field(default_factory=frozenset)
    registry: FrozenSet = field(default_factory=frozenset)
    policy: Policy = "enforce"
    authorities: FrozenSet = field(default_factory=frozenset)
    polver: int = 1
    actor: AppId = "noOne"
    lineage: Tuple[Tuple[int, tuple], ...] = ()
    lineage_next: int = 0
    head: str = "rootC"
    result: str = ""

    # --- K-Map style accessors (lookupInt/lookupU/lookupCap/resolve) --------
    def committed_get(self, k: StKey) -> int:
        return dict(self.committed).get(k, 0)

    def cap_get(self, a: AppId) -> int:
        return dict(self.cap).get(a, 0)  # unset capacity = zero budget (safe default)

    def resolve(self, k: StKey) -> ResourceId:
        return dict(self.resmap).get(k, "noRes")

    def set_cell(self, cell: str, key, value) -> "Config":
        base = dict(getattr(self, cell))
        base[key] = value
        return replace(self, **{cell: tuple(sorted(base.items(), key=lambda kv: str(kv[0])))})

    def union_t(self, item) -> "Config":
        return replace(self, footprint_t=self.footprint_t | {item})

    def union_d(self, item) -> "Config":
        return replace(self, footprint_d=self.footprint_d | {item})


# ---------------------------------------------------------------------------
# SRW3G-INVAR: evaluated invariants (evalInvG)
# ---------------------------------------------------------------------------
def eval_inv_g(inv: InvId, st: Mapping[StKey, int], us: Mapping[AppId, int], cp: Mapping[AppId, int]) -> bool:
    if inv == "IA7":
        return st.get(("appA", 7), 0) <= 10
    if inv == "IB3":
        return st.get(("appB", 3), 0) <= 10
    if inv == "IC0":
        return st.get(("appC", 0), 0) <= 10
    if inv == "ID0":
        return st.get(("appD", 0), 0) <= 10
    if inv == "IRP":  # CM2: obligation stated over the ALIASED KEY PAIR of resP
        return st.get(("appA", 7), 0) + st.get(("appB", 3), 0) <= 10
    if inv == "IRQ":
        return st.get(("appC", 0), 0) == st.get(("appD", 0), 0)
    if inv == "ICAPC":
        return us.get("appC", 0) <= cp.get("appC", 0)
    if inv == "ICAPD":
        return us.get("appD", 0) <= cp.get("appD", 0)
    if inv == "IAGG":  # CM3: the AGGREGATE budget obligation
        return us.get("appC", 0) + us.get("appD", 0) <= cp.get("appB", 0)
    raise AssertionError(f"unknown invariant {inv}")


# Dependency oracles (A1: auditable manual read-set derivations, Phase-0 discipline)
TRUE_DEPS = {"IA7": {"appA"}, "IB3": {"appB"}, "IC0": {"appC"}, "ID0": {"appD"},
             "IRP": {"appA"}, "IRQ": {"appC"}}
TRUE_DEPS_R = {"IRP": {"resP"}, "IRQ": {"resQ"}}
TRUE_DEPS_A = {"ICAPC": {"appC"}, "ICAPD": {"appD"}, "IAGG": {"appC", "appD"}}
APP_UNIVERSE = frozenset({"IA7", "IB3", "IC0", "ID0"})
RES_UNIVERSE = frozenset({"IRP", "IRQ"})
AUTH_UNIVERSE = frozenset({"ICAPC", "ICAPD", "IAGG"})


# ---------------------------------------------------------------------------
# SRW3G-CLOSURE: projections, alias closure, applicability
# ---------------------------------------------------------------------------
def apps_of(foot: FrozenSet) -> FrozenSet:
    """App projection: AppId tokens + apps owning written StKeys."""
    out = set()
    for it in foot:
        if it in APPS:
            out.add(it)
        elif isinstance(it, tuple):
            out.add(it[0])
    return frozenset(out)


def auth_of(foot: FrozenSet) -> FrozenSet:
    """Authority projection: ONLY explicit AppId tokens (reads/consumes)."""
    return frozenset(it for it in foot if it in APPS)


def logical_of(foot: FrozenSet, resmap: Mapping[StKey, ResourceId]) -> FrozenSet:
    """AliasClosure(E) = { r | exists k in E. Resolves(k) = r }  (Part III-D)."""
    out = set()
    for it in foot:
        if isinstance(it, tuple):
            r = resmap.get(it, "noRes")
            if r != "noRes":
                out.add(r)
    return frozenset(out)


def nonempty_inter(a: FrozenSet, b: FrozenSet) -> bool:
    return bool(a & b)


def subset(a: FrozenSet, b: FrozenSet) -> bool:
    return a <= b


def applicable_gen(registry: FrozenSet, foot: FrozenSet, resmap: Mapping[StKey, ResourceId]) -> FrozenSet:
    """applicableGen: per-scope obligation applicability over ONE footprint."""
    apps = apps_of(foot)
    auth = auth_of(foot)
    logical = logical_of(foot, resmap)
    out = set()
    for e in registry:
        kind, inv, scope = e
        if kind == "bareEdge":
            continue  # dependency known, no contract -> no obligation (CM6 gap, preserved)
        proj = {"edge": apps, "edgeR": logical, "edgeA": auth}[kind]
        if proj & scope:
            out.add(inv)
    return frozenset(out)


def all_hold_g(obls: FrozenSet, st, us, cp) -> bool:
    return all(eval_inv_g(j, st, us, cp) for j in obls)


def _has_cover(edges: FrozenSet, inv: InvId, kind: str, deps: FrozenSet) -> bool:
    for e in edges:
        if e[0] == kind and e[1] == inv and deps <= e[2]:
            return True
    return False


def interaction_complete(registry: FrozenSet, univ: FrozenSet) -> bool:
    return all(_has_cover(registry, j, "edge", TRUE_DEPS[j]) for j in univ)


def resource_complete(registry: FrozenSet, univ: FrozenSet) -> bool:
    return all(_has_cover(registry, j, "edgeR", TRUE_DEPS_R[j]) for j in univ)


def authority_complete(registry: FrozenSet, univ: FrozenSet) -> bool:
    return all(_has_cover(registry, j, "edgeA", TRUE_DEPS_A[j]) for j in univ)


def contract_complete(registry: FrozenSet) -> bool:
    return all(e[0] != "bareEdge" for e in registry)


def security_closed_gen_u(registry: FrozenSet, policy: Policy,
                          app_univ: FrozenSet, res_univ: FrozenSet, auth_univ: FrozenSet) -> bool:
    """securityClosedGenU: enforce + the 4 completenesses over explicit universes."""
    if policy != "enforce":
        return False
    return (interaction_complete(registry, app_univ)
            and contract_complete(registry)
            and resource_complete(registry, res_univ)
            and authority_complete(registry, auth_univ))


# ---- demo registries (mirror pickRegistryG) --------------------------------
def _e(inv, scope):    return ("edge", inv, frozenset(scope))
def _er(inv, scope):   return ("edgeR", inv, frozenset(scope))
def _ea(inv, scope):   return ("edgeA", inv, frozenset(scope))


REGISTRIES = {
    "aliasNaive": frozenset({_e("IA7", {"appA"}), _e("IB3", {"appB"}), _e("IRP", {"appA"})}),
    "aliasOnly": frozenset({_e("IA7", {"appA"}), _e("IB3", {"appB"}), _er("IRP", {"resP"})}),
    "authNaive": frozenset({_ea("ICAPC", {"appC"}), _ea("ICAPD", {"appD"})}),
    "authOnly": frozenset({_ea("ICAPC", {"appC"}), _ea("ICAPD", {"appD"}),
                           _ea("IAGG", {"appC", "appD"})}),
    "fullNaive": frozenset({_e("IA7", {"appA"}), _e("IB3", {"appB"}), _e("IC0", {"appC"}),
                            _e("ID0", {"appD"}), _e("IRP", {"appA"}),
                            _ea("ICAPC", {"appC"}), _ea("ICAPD", {"appD"}),
                            _ea("IAGG", {"appC", "appD"})}),
    "full": frozenset({_e("IA7", {"appA"}), _e("IB3", {"appB"}), _e("IC0", {"appC"}),
                       _e("ID0", {"appD"}), _er("IRP", {"resP"}), _er("IRQ", {"resQ"}),
                       _ea("ICAPC", {"appC"}), _ea("ICAPD", {"appD"}),
                       _ea("IAGG", {"appC", "appD"})}),
}

AUTHORITIES_ALL = frozenset(APPS)
RESMAP_PQ = ((("appA", 7), "resP"), (("appB", 3), "resP"),
             (("appC", 0), "resQ"), (("appD", 0), "resQ"))


# ---------------------------------------------------------------------------
# SRW3G-STATE + SRW3G-GATE: the command interpreter
# ---------------------------------------------------------------------------
def bump_usage(usage: Tuple[Tuple[AppId, int], ...], a: AppId, n: int) -> Tuple[Tuple[AppId, int], ...]:
    d = dict(usage)
    d[a] = d.get(a, 0) + n
    return tuple(sorted(d.items()))


def run(program, cfg: Config) -> Config:
    """Execute a finite Srw3PgmG; mirrors the one-step rules verbatim.

    Multi-command transitions: the caller lists them after `begin`; `wfCheck`
    and `gate` are evaluated when reached, exactly as in the K semantics.
    """
    for cmd in program:
        op, *args = cmd

        if op == "useRegistryG":
            (kind,) = args
            cfg = replace(cfg, registry=REGISTRIES[kind], authorities=AUTHORITIES_ALL)
        elif op == "useResMap":
            (kind,) = args
            cfg = replace(cfg, resmap=RESMAP_PQ if kind == "rmPQ" else ())
        elif op == "init":
            i, s, v = args
            cfg = cfg.set_cell("committed", (i, s), v)
        elif op == "as":
            (p,) = args
            cfg = replace(cfg, actor=p)
        elif op == "grant":
            q, p, b = args
            cfg = cfg.set_cell("cap", q, b).set_cell("parent", q, p)
        elif op == "setPolicy":
            (p,) = args
            cfg = replace(cfg, policy=p)
        elif op == "begin":
            # shadow copy over BOTH state components; footprints reset
            cfg = replace(cfg, prospective=cfg.committed, usage_p=cfg.usage_c,
                          footprint_t=frozenset(), footprint_d=frozenset())
        elif op == "w":
            i, s, v = args
            cfg = cfg.set_cell("prospective", (i, s), v).union_t((i, s)).union_d((i, s))
        elif op == "wH":  # hidden write: real effect omitted from declaration (CM7)
            i, s, v = args
            cfg = cfg.set_cell("prospective", (i, s), v).union_t((i, s))
        elif op == "rd":
            (i,) = args
            cfg = cfg.union_t(i).union_d(i)
        elif op == "rdH":
            (i,) = args
            cfg = cfg.union_t(i)
        elif op == "consume":  # CM3: evaluated effect on the prospective usage bundle
            a, n = args
            cfg = replace(cfg, usage_p=bump_usage(cfg.usage_p, a, n)).union_t(a).union_d(a)
        elif op == "wfCheck":
            if cfg.policy == "enforce" and not subset(cfg.footprint_t, cfg.footprint_d):
                cfg = replace(cfg, result="blocked-effect-incomplete",
                              prospective=(), usage_p=())
                break
        elif op == "gate":
            obls = applicable_gen(cfg.registry, cfg.footprint_d, dict(cfg.resmap))
            holds = all_hold_g(obls, dict(cfg.prospective), dict(cfg.usage_p), dict(cfg.cap))
            member = cfg.actor in cfg.authorities
            if holds and member:
                n = cfg.lineage_next
                # accept: committed := prospective; usage_c := usage_p; lineage append
                cfg = replace(cfg,
                              committed=cfg.prospective,
                              usage_c=cfg.usage_p,
                              lineage=cfg.lineage + ((n, (cfg.head, n, ("auth", cfg.actor), cfg.polver, f"commit({n})")),),
                              lineage_next=n + 1,
                              head=f"commit({n})",
                              prospective=(), usage_p=(),
                              footprint_t=frozenset(), footprint_d=frozenset(),
                              result="commit")
            elif not holds:
                cfg = replace(cfg, result="reject", prospective=(), usage_p=(),
                              footprint_t=frozenset(), footprint_d=frozenset())
            else:
                cfg = replace(cfg, result="reject-auth", prospective=(), usage_p=(),
                              footprint_t=frozenset(), footprint_d=frozenset())
        else:
            raise AssertionError(f"unknown command {op}")
    return cfg


# Convenience constructor for the standard initial configuration
def initial() -> Config:
    return Config()
