#!/usr/bin/env python3
# =============================================================================
# SRW3 Phase 1D-R1 Part III — PERMANENT L7 ADVERSARIAL SUITE
# (python-gen/test_lin_verify_L7.py)
#
# Post-fix regression suite for the L7 state layer. The L7-B inputs are the
# SAME forged-record fixtures frozen in Part I (test_lin_attack_L7.py /
# transcripts/audit/phase1d_r1/l7_attack_prefix.txt) — the attack that the
# pre-fix verifier ACCEPTED. After the Part II fix (canonical finite-map
# equality post_map == composed_map), every class below must produce the
# stated verdict, permanently.
#
#   L7-A  honest exact state .................... VALID
#   L7-B  EXTRA key, fully re-signed ............ L7-STATE  (the L7 attack)
#   L7-C  missing composed key, re-signed ....... L7-STATE
#   L7-D  changed composed value, re-signed ..... L7-STATE
#   L7-E  empty maps, honest empty transition ... VALID
#   L7-F  empty composition, any entry presented  L7-STATE  (extra-key on empty)
#   L7-G  multi-account multi-slot exact ........ VALID
#   L7-H  order-permuted presentation ........... VALID  (canonical, not positional)
#   L7-I  extra key with value 0, re-signed ..... L7-STATE  (value irrelevant)
#   L7-J  extra key, stale stateD (naive) ....... L7-STATE  (digest binding)
#
# Exit 0 iff ALL verdicts match. Any deviation = verifier regression; Phase 1D
# must not close while this suite fails.
# =============================================================================

import sys
from dataclasses import replace

from lin_verify import (LinCtx, LinRec, apply_effects, build_rec, canon_kv,
                        verify_lineage, H, i2b4)

from coincurve import PrivateKey


def PrivateKey_(sk: bytes):
    return PrivateKey(sk)

SK1 = (77).to_bytes(32, "big")
SK2 = (4242).to_bytes(32, "big")
ROOT = (0).to_bytes(32, "big")

PRE = {1: {0: 100, 1: 0}, 2: {0: 50, 1: 1}}
EFFECTS = {1: {0: 25}, 2: {1: 7}}
POST = apply_effects(PRE, EFFECTS)

TID = 1
POLICY_V = 1
REGISTRY = (1, 2)
AUTH_SET = (SK1, SK2)


def auth(sk: bytes):
    from lin_verify import addr_of
    return addr_of(sk)


def forge(rec: LinRec, *, post, sk: bytes, ctx: LinCtx) -> LinRec:
    """Authorized-dishonest producer: recompute everything over an arbitrary
    presented post-state with the VALID key (same fixture builder as Part I)."""
    from lin_verify import canon_full, core_hash
    input_d = H(canon_kv(ctx.pre_state))
    effect_d = H(canon_kv(ctx.true_effects))
    state_d = H(canon_kv(post))
    ev = PrivateKey_(sk).sign_recoverable(
        H(i2b4(rec.tid) + input_d + effect_d + state_d), hasher=None)
    tmp = LinRec(rec.version, rec.parent, rec.tid, rec.appset, input_d,
                 effect_d, state_d, rec.policy_v, rec.authority, ev, b"", b"")
    sig = PrivateKey_(sk).sign_recoverable(core_hash(tmp), hasher=None)
    tmp2 = LinRec(rec.version, rec.parent, rec.tid, rec.appset, input_d,
                  effect_d, state_d, rec.policy_v, rec.authority, ev, sig, b"")
    child = H(canon_full(tmp2))
    return LinRec(rec.version, rec.parent, rec.tid, rec.appset, input_d,
                  effect_d, state_d, rec.policy_v, rec.authority, ev, sig, child)


CASES = []


def case(name, expect):
    CASES.append((name, expect))
    def deco(fn):
        fn._name = name
        fn._expect = expect
        return fn
    return deco


def main() -> int:
    print("=== SRW3 Phase 1D-R1 Part III — permanent L7 adversarial suite "
          "(POST-FIX) ===")
    print("=== L7 = digest binding + canonical map equality "
          "post_map == composed_map ===")
    print()

    from lin_verify import addr_of
    auth_set = (addr_of(SK1), addr_of(SK2))
    honest = build_rec(TID, ROOT, PRE, EFFECTS, POST, SK1, POLICY_V)
    failures = 0

    total = 0

    def run(tag, expect, verdict):
        nonlocal failures, total
        total += 1
        ok = (verdict == expect)
        print(f"[{tag}] verdict={verdict!r} expect={expect!r} "
              f"{'PASS' if ok else 'FAIL'}")
        if not ok:
            failures += 1

    # L7-A — honest exact state
    v = verify_lineage(honest, LinCtx(PRE, EFFECTS, POST, REGISTRY, auth_set),
                       TID, ROOT)
    run("L7-A", "VALID", v)

    # L7-B — THE L7 EXTRA-KEY ATTACK (Part I fixture), now MUST be rejected
    post_b = {a: dict(s) for a, s in POST.items()}
    post_b.setdefault(2, {})[9] = 999
    ctx_b = LinCtx(PRE, EFFECTS, post_b, REGISTRY, auth_set)
    forged_b = forge(honest, post=post_b, sk=SK1, ctx=ctx_b)
    v = verify_lineage(forged_b, ctx_b, TID, ROOT)
    run("L7-B", "L7-STATE", v)

    # L7-C — missing composed key, fully re-signed
    post_c = {1: {0: 25, 1: 0}, 2: {0: 50}}
    ctx_c = LinCtx(PRE, EFFECTS, post_c, REGISTRY, auth_set)
    forged_c = forge(honest, post=post_c, sk=SK1, ctx=ctx_c)
    v = verify_lineage(forged_c, ctx_c, TID, ROOT)
    run("L7-C", "L7-STATE", v)

    # L7-D — changed composed value, fully re-signed
    post_d = {1: {0: 25, 1: 0}, 2: {0: 50, 1: 9}}
    ctx_d = LinCtx(PRE, EFFECTS, post_d, REGISTRY, auth_set)
    forged_d = forge(honest, post=post_d, sk=SK1, ctx=ctx_d)
    v = verify_lineage(forged_d, ctx_d, TID, ROOT)
    run("L7-D", "L7-STATE", v)

    # L7-E — empty maps, honest empty transition
    v = verify_lineage(build_rec(0, ROOT, {}, {}, {}, SK1, POLICY_V),
                       LinCtx({}, {}, {}, REGISTRY, auth_set), 0, ROOT)
    run("L7-E", "VALID", v)

    # L7-F — empty composition, single extra entry presented, fully re-signed
    post_f = {3: {0: 1}}
    ctx_f = LinCtx({}, {}, post_f, REGISTRY, auth_set)
    empty_rec = build_rec(0, ROOT, {}, {}, {}, SK1, POLICY_V)
    forged_f = forge(empty_rec, post=post_f, sk=SK1, ctx=ctx_f)
    v = verify_lineage(forged_f, ctx_f, 0, ROOT)
    run("L7-F", "L7-STATE", v)

    # L7-G — multi-account multi-slot exact state
    pre_g = {1: {0: 1, 2: 2, 3: 3}, 2: {0: 10, 5: 50}, 7: {1: 1}}
    eff_g = {1: {2: 20}, 2: {5: 51}, 7: {1: 2, 9: 9}}
    post_g = apply_effects(pre_g, eff_g)
    rec_g = build_rec(3, ROOT, pre_g, eff_g, post_g, SK2, POLICY_V)
    v = verify_lineage(rec_g, LinCtx(pre_g, eff_g, post_g, REGISTRY, auth_set),
                       3, ROOT)
    run("L7-G", "VALID", v)

    # L7-H — same maps, different insertion order (canonical equality is
    # order-independent; canon_kv sorts)
    pre_h = {2: {5: 50, 0: 10}, 7: {1: 1}, 1: {3: 3, 2: 2, 0: 1}}
    eff_h = {7: {9: 9, 1: 2}, 1: {2: 20}, 2: {5: 51}}
    post_h = apply_effects(pre_h, eff_h)
    rec_h = build_rec(3, ROOT, pre_h, eff_h, post_h, SK2, POLICY_V)
    v = verify_lineage(rec_h, LinCtx(pre_h, eff_h, post_h, REGISTRY, auth_set),
                       3, ROOT)
    run("L7-H", "VALID", v)

    # L7-I — extra key with value 0 (SSTORE-zero), fully re-signed
    post_i = {a: dict(s) for a, s in POST.items()}
    post_i.setdefault(2, {})[9] = 0
    ctx_i = LinCtx(PRE, EFFECTS, post_i, REGISTRY, auth_set)
    forged_i = forge(honest, post=post_i, sk=SK1, ctx=ctx_i)
    v = verify_lineage(forged_i, ctx_i, TID, ROOT)
    run("L7-I", "L7-STATE", v)

    # L7-J — extra key, stale stateD (naive outsider variant)
    ctx_j = LinCtx(PRE, EFFECTS, post_b, REGISTRY, auth_set)
    v = verify_lineage(honest, ctx_j, TID, ROOT)
    run("L7-J", "L7-STATE", v)

    print()
    print(f"=== L7 ADVERSARIAL SUITE: {total - failures}/{total} PASS ===")
    if failures == 0:
        print("L7 establishes PresentedPost == Apply(PreState, TrueEffects).")
        print("The Part-I extra-key forgery (L7-B) is REJECTED. Fixture and")
        print("expectations are permanent regression baselines.")
        return 0
    print("VERIFIER REGRESSION: do not close Phase 1D while this suite fails.")
    return 1


if __name__ == "__main__":
    sys.exit(main())
