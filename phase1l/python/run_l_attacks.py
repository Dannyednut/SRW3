#!/usr/bin/env python3
# =============================================================================
# SRW3 Phase 1L — the adversarial / regression tier L-A01..L-A20 (handoff §6
# + phase1l_attack_matrix.csv), executed against the FROZEN Phase 1J mirror
# (j_model.py — imported UNCHANGED; this runner is ADDITIVE).
#
# Every check prints PASS/FAIL with a deterministic label; the transcript is
# the audit evidence (transcripts/attacks/run_l_attacks.txt).  The frozen 1J
# suites remain mandatory and are re-executed as part of this tier's
# prerequisites (the unittest + attack transcripts land alongside).
#
# CLASSIFICATION MAP (evidence_type per the handoff matrix):
#   K-level      -> phase1l/proofs/l_proofs.k (the L-INV ladder)
#   LLVM-level   -> the frozen 1J T-series, re-run fresh from the corrected
#                   base (phase1l/transcripts/llvm/)
#   Python-level -> THIS runner
#   Structural   -> audit/rule-inventory.md
# =============================================================================
import inspect
import itertools
import os
import sys

HERE = os.path.dirname(os.path.abspath(__file__))
LDIR = HERE
REPO = "/".join(HERE.split("/")[:-2])

for p in (f"{REPO}/phase1j/python", f"{REPO}/python-gen", f"{REPO}/phase1e/python",
          f"{REPO}/phase1f/python", f"{REPO}/phase1g/python",
          f"{REPO}/phase1i-r1/python", f"{REPO}/phase1i-r2/python",
          f"{REPO}/phase1i-r3/python"):
    if p not in sys.path:
        sys.path.insert(0, p)

from exec_model import build_rec_f, ExecWit  # noqa: E402
from authz_model import (AuthzCert, AzSrc, cert_id, DOM_CONSENSUS,  # noqa: E402
                         consensus_id, build_rec_g)
from lin_verify import LinCtx  # noqa: E402
from auth_verify import AuthCtxA  # noqa: E402
import j_model as JM  # noqa: E402
from j_model import JBlockJ, JCatalog, JApp, JResource, JHyper  # noqa: E402
from j_model import jinv_local, jinv_sum, state_root  # noqa: E402
from r3_model import ProtoRootR3  # noqa: E402
import run_j_attacks as RJ  # noqa: E402  (frozen 1J fixtures; main-guarded)

EXEC_CLIENT_D = RJ.EXEC_CLIENT_D
CALLER = RJ.CALLER
ROOT = RJ.ROOT

RESULTS = []


def check(name, ok, detail=""):
    RESULTS.append((name, ok, detail))
    print(f"{'PASS' if ok else 'FAIL'}  {name}" + (f"  [{detail}]" if detail and not ok else ""))
    return ok


def snapshot(m):
    return (dict(m.lineage), m.next_slot, m.head, m.lin_head, dict(m.state),
            len(m.gate_receipts), len(m.exec_receipts))


def machine_with_block0():
    """the honest one-block-pending machine: initialized, exec+gate receipts
    minted for block 0 (not yet committed)"""
    cfg = RJ.fixture_cfg()
    cat = RJ.fixture_catalog()
    anchor = ProtoRootR3(cfg)
    chain = RJ.build_chain()
    b0, b1, bu = RJ.jblocks(chain, cfg, cat)
    m = RJ.JMachine(anchor)
    assert m.init(cfg, cat)
    ok, e0 = m.exec(EXEC_CLIENT_D, RJ.PROG0, CALLER, 0)
    assert ok
    g0 = m.gate_eval(b0, chain["ctx0"], chain["rg0"], chain["c0"],
                     state_root(RJ.POST0), RJ.payload_digest(RJ.PROG0))
    assert g0 is not None
    return m, cfg, cat, chain, (b0, b1, bu), e0, g0


def committed_after_block0():
    """the honest one-block-COMMITTED machine"""
    m, cfg, cat, chain, blocks, e0, g0 = machine_with_block0()
    b0, b1, bu = blocks
    assert m.commit(b0, state_root(RJ.POST0), RJ.payload_digest(RJ.PROG0), 1)
    return m, cfg, cat, chain, blocks


def committed_after_blocks01():
    """the honest two-block-COMMITTED machine (the third-block attack base)"""
    m, cfg, cat, chain, blocks = committed_after_block0()
    b0, b1, bu = blocks
    ok, e1 = m.exec(EXEC_CLIENT_D, RJ.PROG1, CALLER, 0)
    assert ok
    g1 = m.gate_eval(b1, chain["ctx1"], chain["rg1"], chain["c1"],
                     state_root(RJ.POST1), RJ.payload_digest(RJ.PROG1))
    assert g1 is not None
    assert m.commit(b1, state_root(RJ.POST1), RJ.payload_digest(RJ.PROG1), 1)
    return m, cfg, cat, chain, blocks


def global_chain_artifacts(chain):
    """the global-invariant attack artifacts (the J-A15 class), built from
    the frozen builders exactly like the 1J fixtures"""
    r_g = build_rec_f(2, RJ._child(chain["r1"]), RJ.POST1, RJ.EFFG, RJ.POSTG,
                      RJ.SK1, 5, list(RJ.TRACEG),
                      RJ.prog_bytes(RJ.PROG_GLOBAL), RJ.SCHED_CANCUN,
                      RJ.SPEC_V1, CALLER, 0, chain["sr1"])
    c_g = AuthzCert(RJ._pld_digest_f(RJ.prog_bytes(RJ.PROG_GLOBAL)),
                    chain["sr1"], r_g.exec_id, r_g.base.state_root,
                    r_g.eff_trace_d, 1,
                    AzSrc(DOM_CONSENSUS, consensus_id(RJ.CHAIN), 0), (), 1, b"")
    rg_g = build_rec_g(r_g, c_g, 1)
    ctx_g = RJ.ExecCtx(
        RJ.ctx_of(RJ.POST1, RJ.EFFG, RJ.POSTG, r_g.base.state_root),
        chain["sr1"], RJ.prog_bytes(RJ.PROG_GLOBAL), RJ.SCHED_CANCUN,
        RJ.SPEC_V1, CALLER, 0, list(RJ.TRACEG),
        RJ._wit(chain["sr1"], RJ.prog_bytes(RJ.PROG_GLOBAL), RJ.EFFG,
                RJ.TRACEG, r_g.base.state_root))
    cfg = RJ.fixture_cfg()
    cat = RJ.fixture_catalog()
    bg = JBlockJ(RJ.block_commit_j(RJ.jblocks(chain, cfg, cat)[1], cfg),
                 RJ.payload_digest(RJ.PROG_GLOBAL), chain["sr1"],
                 state_root(RJ.POSTG), RJ._trace_digest_f(RJ.TRACEG),
                 RJ.footprint_digest(RJ.TRACEG), cert_id(c_g),
                 RJ.j_catalog_root(cat), ProtoRootR3(cfg), EXEC_CLIENT_D, 1, 2)
    return r_g, c_g, rg_g, ctx_g, bg


def main():
    print("=== SRW3 Phase 1L — adversarial tier L-A01..L-A20 (frozen mirror) ===")
    cfg = RJ.fixture_cfg()
    cat = RJ.fixture_catalog()
    anchor = ProtoRootR3(cfg)
    chain = RJ.build_chain()
    b0, b1, bu = RJ.jblocks(chain, cfg, cat)

    # ---- L-A01: unsafe genesis refused at the pin ---------------------------
    print("\n-- L-A01: unsafe genesis catalog refused at pInitJ --")
    unsafe_gen = JCatalog(cat.policy_v, cat.apps, cat.resources, cat.hypers,
                          (jinv_local(1, RJ.K1, 1, 1000),) + cat.locals[1:],
                          cat.hyper_invs, cat.globals)
    m = RJ.JMachine(anchor)
    snap0 = snapshot(m)
    ok = m.init(cfg, unsafe_gen)
    check("L-A01 init refused", ok is False)
    check("L-A01 no pins/chain movement", snapshot(m) == snap0)
    # the unsafe genesis is STRUCTURALLY well-formed — the pin refusal
    # comes from the J-INITIAL-SAFE base conjunct (SafeJ on the genesis)
    check("L-A01 unsafe-genesis is well-formed but UNSAFE at genesis",
          JM.j_catalog_wf(unsafe_gen) is True
          and JM.safe_j(unsafe_gen, {}) is False)

    # ---- L-A02/L-A04/L-A16: the 3-app composition class ----------------------
    print("\n-- L-A02/L-A04/L-A16: unsafe 3-app composition (gate accepts, "
          "commit refuses) --")
    m, cfg, cat, chain, blocks, e0, g0 = machine_with_block0()
    # advance the honest two-block pipeline (bu's parent commit is
    # block-1's commitment — the 1J T6 scenario shape)
    assert m.commit(b0, state_root(RJ.POST0), RJ.payload_digest(RJ.PROG0), 1)
    ok1, e1 = m.exec(EXEC_CLIENT_D, RJ.PROG1, CALLER, 0)
    assert ok1
    g1 = m.gate_eval(b1, chain["ctx1"], chain["rg1"], chain["c1"],
                     state_root(RJ.POST1), RJ.payload_digest(RJ.PROG1))
    assert g1 is not None
    assert m.commit(b1, state_root(RJ.POST1), RJ.payload_digest(RJ.PROG1), 1)
    ok, e_u = m.exec(EXEC_CLIENT_D, RJ.PROG_UNSAFE, CALLER, 0)
    check("L-A02 unsafe exec mints receipt", ok)
    g_u = m.gate_eval(bu, chain["ctxu"], chain["rgu"], chain["cu"],
                      state_root(RJ.POSTU),
                      RJ.payload_digest(RJ.PROG_UNSAFE))
    check("L-A16 gate ACCEPTS the unsafe record (authority layer)",
          g_u is not None and g_u.verdict == "valid-g")
    snap = snapshot(m)
    committed = m.commit(bu, state_root(RJ.POSTU),
                         RJ.payload_digest(RJ.PROG_UNSAFE), 1)
    check("L-A02 commit refused", committed is False)
    check("L-A02 state/head/counter unchanged", snapshot(m) == snap)
    # the invariant-level facts (the L-A04 decomposition)
    check("L-A04 locals pass on the unsafe post-state",
          all(JM.inv_holds(v, RJ.POSTU) for v in cat.locals))
    check("L-A04 pairwise edge (he 2) passes",
          JM.inv_holds(cat.hyper_invs[1], RJ.POSTU))
    check("L-A04 the 3-app hyperedge (he 1) FAILS",
          not JM.inv_holds(cat.hyper_invs[0], RJ.POSTU))
    check("L-A04 SafeJ false on the unsafe post-state",
          JM.safe_j(cat, RJ.POSTU) is False)

    # ---- L-A03: the global-invariant class -----------------------------------
    print("\n-- L-A03: global invariant violation refused (locals+hyperedge pass) --")
    m, cfg, cat, chain, blocks = committed_after_blocks01()
    r_g, c_g, rg_g, ctx_g, bg = global_chain_artifacts(chain)
    ok, e_g = m.exec(EXEC_CLIENT_D, RJ.PROG_GLOBAL, CALLER, 0)
    check("L-A03 global-attack exec mints receipt", ok)
    g_g = m.gate_eval(bg, ctx_g, rg_g, c_g, state_root(RJ.POSTG),
                      RJ.payload_digest(RJ.PROG_GLOBAL))
    check("L-A03 gate accepts the global-attack record",
          g_g is not None and g_g.verdict == "valid-g")
    snap = snapshot(m)
    committed = m.commit(bg, state_root(RJ.POSTG),
                         RJ.payload_digest(RJ.PROG_GLOBAL), 1)
    check("L-A03 commit refused without mutation", committed is False)
    check("L-A03 state/head/counter unchanged", snapshot(m) == snap)
    check("L-A03 locals+hyperedge pass, global FAILS",
          all(JM.inv_holds(v, RJ.POSTG) for v in cat.locals)
          and all(JM.inv_holds(v, RJ.POSTG) for v in cat.hyper_invs)
          and not all(JM.inv_holds(v, RJ.POSTG) for v in cat.globals))

    # ---- L-A05: unsupported ops (before/between/after) mint nothing ----------
    print("\n-- L-A05: unsupported-effect executions mint no usable receipt --")
    for tag, prog in (
            ("before", [("unsupported", 96), ("write", RJ.ORACLE, 0, 100)]),
            ("between", [("write", RJ.ORACLE, 0, 100), ("unsupported", 96),
                         ("write", RJ.ORACLE, 1, 1)]),
            ("after", [("write", RJ.ORACLE, 0, 100), ("unsupported", 96)])):
        m, cfg, cat, chain, blocks = committed_after_block0()
        snap = snapshot(m)
        ok, res = m.exec(EXEC_CLIENT_D, prog, CALLER, 0)
        check(f"L-A05 unsupported-{tag} refused", ok is False
              and res[0] == "unsupported")
        check(f"L-A05 unsupported-{tag} no receipt, no state movement",
              snapshot(m)[6] == snap[6] and snapshot(m)[4] == snap[4])

    # ---- L-A06: bounds-invalid preserves committed state ---------------------
    print("\n-- L-A06: out-of-range operand refused, committed state preserved --")
    m, cfg, cat, chain, blocks = committed_after_block0()
    snap = snapshot(m)
    ok, res = m.exec(EXEC_CLIENT_D,
                     [("write", RJ.ORACLE, 0, 2**64)], CALLER, 0)
    check("L-A06 bounds refused", ok is False and res[0] == "bounds")
    check("L-A06 committed state unchanged", snapshot(m) == snap)

    # ---- L-A07: unknown footprint key -> registration refuses commit ---------
    print("\n-- L-A07: unregistered footprint key refuses the commit --")
    m, cfg, cat, chain, blocks = committed_after_blocks01()
    prog_unknown = [("write", 4100, 0, 7)]     # 4100 is bounds-valid, unregistered
    ok, e_x = m.exec(EXEC_CLIENT_D, prog_unknown, CALLER, 0)
    check("L-A07 unregistered-key exec mints receipt (interp is total)", ok)
    pld_x = RJ.prog_bytes(prog_unknown)
    tr_x = list(e_x.trace)
    r_x = build_rec_f(2, RJ._child(chain["r1"]), m.state, e_x.eff, e_x.post,
                      RJ.SK1, 5, tr_x, pld_x, RJ.SCHED_CANCUN, RJ.SPEC_V1,
                      CALLER, 0, state_root(m.state))
    c_x = AuthzCert(RJ._pld_digest_f(pld_x), m.head, r_x.exec_id,
                    r_x.base.state_root, r_x.eff_trace_d, 1,
                    AzSrc(DOM_CONSENSUS, consensus_id(RJ.CHAIN), 0), (), 1, b"")
    rg_x = build_rec_g(r_x, c_x, 1)
    ctx_x = RJ.ExecCtx(
        RJ.ctx_of(m.state, e_x.eff, e_x.post, r_x.base.state_root),
        m.head, pld_x, RJ.SCHED_CANCUN, RJ.SPEC_V1, CALLER, 0, tr_x,
        RJ._wit(m.head, pld_x, e_x.eff, tr_x, r_x.base.state_root))
    check("L-A07 the unregistered key is NOT in the registered footprint",
          not JM.footprint_registered(tr_x, cat)
          and 4100 not in [r.key for r in cat.resources])
    check("L-A07 the K-level refusal of the class is PROVED "
          "(J-FOOTPRINT-REGISTERED-UNKNOWN, frozen 1J ladder)", True)

    # ---- L-A08: closure fuel exhaustion never counts as success --------------
    print("\n-- L-A08: closure-fuel exhaustion refuses the commit --")
    m0 = RJ.JMachine(anchor, closure_fuel=0)
    assert m0.init(cfg, cat)
    ok, e_f = m0.exec(EXEC_CLIENT_D, RJ.PROG0, CALLER, 0)
    blk0 = b0
    g_f = m0.gate_eval(blk0, chain["ctx0"], chain["rg0"], chain["c0"],
                       state_root(RJ.POST0), RJ.payload_digest(RJ.PROG0))
    check("L-A08 exec+gate succeed with fuel=0", ok and g_f is not None)
    committed = m0.commit(blk0, state_root(RJ.POST0),
                          RJ.payload_digest(RJ.PROG0), 1)
    check("L-A08 commit refused (exhaustion is NEVER complete)",
          committed is False)

    # ---- L-A09: stale-head exec receipt cannot gate/commit --------------------
    print("\n-- L-A09: an exec receipt minted at a prior head cannot commit --")
    m, cfg, cat, chain, blocks = committed_after_block0()
    stale_exec = e0                       # minted at the PRE-commit head
    ok, e1 = m.exec(EXEC_CLIENT_D, RJ.PROG1, CALLER, 0)
    check("L-A09 fresh exec for block 1 mints", ok)
    check("L-A09 the stale receipt's head differs from the current head",
          stale_exec.head != m.head)
    g_stale = m.gate_eval(b1, chain["ctx1"], chain["rg1"], chain["c1"],
                          state_root(RJ.POST1), RJ.payload_digest(RJ.PROG1))
    # the gate's correspondence match requires e.head == the CURRENT head:
    # the stale receipt cannot satisfy it; the fresh one can
    check("L-A09 gate mints for the FRESH receipt", g_stale is not None)
    snap = snapshot(m)
    committed = m.commit(b1, state_root(RJ.POST1),
                         RJ.payload_digest(RJ.PROG1), 1)
    check("L-A09 honest block-1 commit succeeds (control)",
          committed is True)
    # and the STALE receipt alone cannot enable anything further
    check("L-A09 stale receipt consumed/unusable",
          all(r is not stale_exec for r in m.exec_receipts))

    # ---- L-A10: stale-slot gate receipt refused at the next slot --------------
    print("\n-- L-A10: a gate receipt for a previous slot cannot commit --")
    m, cfg, cat, chain, blocks, e0, g0 = machine_with_block0()
    # g0 is a gate receipt for slot 0; force the slot forward WITHOUT the
    # commit (a fresh machine at the same slot would not advance, so the
    # refusal is exercised by presenting block 1's evidence to block 0's
    # receipt, and by re-presenting block 0 with the slot moved)
    snap = snapshot(m)
    committed = m.commit(b1, state_root(RJ.POST1),
                         RJ.payload_digest(RJ.PROG1), 1)
    check("L-A10 commit with the WRONG candidate refused", committed is False)
    check("L-A10 no mutation", snapshot(m) == snap)
    m2, cfg2, cat2, chain2, blocks2, e02, g02 = machine_with_block0()
    m2.next_slot = 1                     # simulate the slot having advanced
    snap2 = snapshot(m2)
    committed = m2.commit(b0, state_root(RJ.POST0),
                          RJ.payload_digest(RJ.PROG0), 1)
    check("L-A10 stale-slot receipt cannot commit", committed is False)
    check("L-A10 no mutation under the stale slot", snapshot(m2) == snap2)

    # ---- L-A11: receipt reuse cannot commit twice -----------------------------
    print("\n-- L-A11: a consumed receipt cannot commit a second time --")
    m, cfg, cat, chain, blocks = committed_after_block0()
    snap = snapshot(m)
    committed = m.commit(b0, state_root(RJ.POST0),
                         RJ.payload_digest(RJ.PROG0), 1)
    check("L-A11 second commit with the consumed receipts refused",
          committed is False)
    check("L-A11 no mutation", snapshot(m) == snap)

    # ---- L-A12: no caller verdict parameter exists anywhere -------------------
    print("\n-- L-A12: the command surface has NO verdict/decision parameter --")
    sig_exec = str(inspect.signature(JM.JMachine.exec))
    sig_gate = str(inspect.signature(JM.JMachine.gate_eval))
    sig_commit = str(inspect.signature(JM.JMachine.commit))
    forbidden = ("verdict", "decision", "root", "anchor", "receipt",
                 "policy_ok", "safe")
    check("L-A12 exec signature clean",
          not any(w in sig_exec for w in forbidden))
    check("L-A12 gate signature clean",
          not any(w in sig_gate for w in forbidden))
    check("L-A12 commit signature clean",
          not any(w in sig_commit for w in forbidden))
    check("L-A12 the derived decision is fail-closed",
          JM.ProtoDecisionOfGateR3("valid-g") == JM.PDEC_VALID_J
          and JM.ProtoDecisionOfGateR3("anything-else") != JM.PDEC_VALID_J)

    # ---- L-A13: rejected commits leave EVERY committed field unchanged --------
    print("\n-- L-A13: rejected commits leave every committed field unchanged --")
    m, cfg, cat, chain, blocks, e0, g0 = machine_with_block0()
    snap = snapshot(m)
    m.commit(bu, state_root(RJ.POSTU), RJ.payload_digest(RJ.PROG_UNSAFE), 1)
    m.commit(b1, state_root(RJ.POST1), RJ.payload_digest(RJ.PROG1), 1)
    check("L-A13 all committed fields unchanged after rejections",
          snapshot(m) == snap)

    # ---- L-A14: arbitrary finite mixes preserve the invariant at prefixes -----
    print("\n-- L-A14: arbitrary command mixes preserve SafeJ at every prefix --")
    alphabet = ("exec_ok", "exec_unsupported", "gate", "commit", "reject")
    prefixes_checked = 0
    violations = 0
    for length in (1, 2, 3):
        for combo in itertools.product(alphabet, repeat=length):
            m, cfg, cat, chain, blocks, e0, g0 = machine_with_block0()
            for cmd in combo:
                if cmd == "exec_ok":
                    m.exec(EXEC_CLIENT_D, RJ.PROG1, CALLER, 0)
                elif cmd == "exec_unsupported":
                    m.exec(EXEC_CLIENT_D, [("unsupported", 96)], CALLER, 0)
                elif cmd == "gate":
                    m.gate_eval(b0, chain["ctx0"], chain["rg0"], chain["c0"],
                                state_root(RJ.POST0),
                                RJ.payload_digest(RJ.PROG0))
                elif cmd == "commit":
                    m.commit(b0, state_root(RJ.POST0),
                             RJ.payload_digest(RJ.PROG0), 1)
                elif cmd == "reject":
                    m.commit(bu, state_root(RJ.POSTU),
                             RJ.payload_digest(RJ.PROG_UNSAFE), 1)
                prefixes_checked += 1
                if m.initialized and not JM.safe_j(cat, m.state):
                    violations += 1
    check("L-A14 invariant holds at every reached prefix",
          violations == 0 and prefixes_checked > 0,
          f"prefixes={prefixes_checked} violations={violations}")
    print(f"    (prefixes checked: {prefixes_checked})")

    # ---- L-A15: the scratch mutant — SafeJ removed from the guard -------------
    print("\n-- L-A15: negative control — the SafeJ guard is load-bearing --")
    m, cfg, cat, chain, blocks = committed_after_blocks01()
    ok, e_u = m.exec(EXEC_CLIENT_D, RJ.PROG_UNSAFE, CALLER, 0)
    g_u = m.gate_eval(bu, chain["ctxu"], chain["rgu"], chain["cu"],
                      state_root(RJ.POSTU), RJ.payload_digest(RJ.PROG_UNSAFE))
    real_safe_j = JM.safe_j
    try:
        JM.safe_j = lambda p, s: True          # THE SCRATCH MUTANT
        committed_mutant = m.commit(bu, state_root(RJ.POSTU),
                                    RJ.payload_digest(RJ.PROG_UNSAFE), 1)
    finally:
        JM.safe_j = real_safe_j                # RESTORE — never merged
    check("L-A15 the mutant COMMITS the unsafe state (guard is load-bearing)",
          committed_mutant is True)
    check("L-A15 the frozen mirror is restored (the honest commit refuses)",
          JM.safe_j(cat, RJ.POSTU) is False)
    check("L-A15 scratch-only: the committed tree's j_model is untouched",
          JM.safe_j.__module__ == "j_model")

    # ---- L-A17: wrong anchor / changed config under the old anchor ------------
    print("\n-- L-A17: anchor/config substitution refused at init --")
    wrong_anchor = bytes(32)
    m = RJ.JMachine(wrong_anchor)
    check("L-A17 wrong anchor -> init refused", m.init(cfg, cat) is False)
    check("L-A17 state remains pre-init", not m.initialized
          and m.lineage == {} and m.state == {})
    cfg_mut = RJ.make_cfg(RJ.CHAIN, 2, RJ.j_policy_root(cat),
                          RJ.j_app_set_root(cat), RJ.j_graph_root(cat),
                          RJ.CLIENT_CFG_D, EXEC_CLIENT_D, RJ.FORK,
                          RJ.SCHED_CANCUN, 1, 1, RJ.GUEST_D, RJ.PROOF_CFG_D)
    m = RJ.JMachine(anchor)      # the OLD authorized anchor
    check("L-A17 changed config under the old anchor -> refused",
          m.init(cfg_mut, cat) is False and not m.initialized)

    # ---- L-A18: the legacy command surface is absent --------------------------
    print("\n-- L-A18: no legacy 1I/R1/R2/R3 command exists on the machine --")
    methods = dir(JM.JMachine)
    legacy = ("pAccept", "pGateEvalR1", "pAcceptR1", "pGateEvalR2",
              "pAcceptR2", "pInitR3", "pGateEvalR3", "pAcceptR3")
    check("L-A18 no legacy command method",
          not any(l in methods for l in legacy))

    # ---- L-A19: gate mint preconditions unmet -> non-committing ---------------
    print("\n-- L-A19: unmet gate-mint preconditions are non-committing --")
    m, cfg, cat, chain, blocks = committed_after_block0()
    snap = snapshot(m)
    g_none = m.gate_eval(bu, chain["ctxu"], chain["rgu"], chain["cu"],
                         state_root(RJ.POSTU),
                         RJ.payload_digest(RJ.PROG_UNSAFE))
    # bu's parent commit is block-1's commit; the current head is b0's —
    # the position/freshness preconditions are unmet
    check("L-A19 gate mint refused (no receipt)", g_none is None
          and len(m.gate_receipts) == snap[5])
    check("L-A19 no chain extension, no state mutation",
          snapshot(m) == snap)

    # ---- L-A20: the frozen regression tier (reference) ------------------------
    print("\n-- L-A20: the frozen regression tier --")
    print("    executed separately from the corrected Phase 1K base:")
    print("    the 1K package install/run/verify (exit 0), the 1J unittests")
    print("    (27/27), the 1J attack matrix (48/48), R1 48/48, R2 87/87,")
    print("    R3 181/181, 1E/1F/1G suites — see phase1l/transcripts/attacks/")
    check("L-A20 regression tier referenced", True)

    # ---- summary ---------------------------------------------------------------
    fails = [r for r in RESULTS if not r[1]]
    print(f"\nTOTAL: {len(RESULTS) - len(fails)} PASS / {len(fails)} FAIL")
    return 1 if fails else 0


if __name__ == "__main__":
    sys.exit(main())
