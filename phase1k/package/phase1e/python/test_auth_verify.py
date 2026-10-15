#!/usr/bin/env python3
# =============================================================================
# SRW3 Phase 1E — PERMANENT authenticated-state adversarial suite
#                                   (phase1e/python/test_auth_verify.py)
#
# Suite layout (the L7-suite precedent: every countermodel gets a permanent
# regression case; the honest non-vacuity witness is case E0):
#
#   E0  non-vacuity witness .... honest record + honest anchor -> VALID-A
#   E1  CM-E1 ... forged VALUE in an inclusion proof vs the fixed root
#   E2  CM-E2 ... tampered sibling path (one byte)
#   E3  CM-E3 ... extra key in presented post (universe grows)  -> L7 + root div
#   E4  CM-E4 ... omitted key from presented post               -> L7 + root div
#   E5  CM-E5 ... changed value in one leaf                     -> L7 + root div
#   E6  CM-E6 ... authorized-dishonest producer: stateRoot of a DIFFERENT
#                 state, all crypto genuine, childE recomputed  -> L14-ANCHOR
#   E7  CM-E7 ... hidden write outside the declared footprint, L7-consistent
#                 (eff' carries the write, post' matches), every digest
#                 genuine — the ANCHOR is what rejects          -> L14-ANCHOR
#   E8  CM-E8 ... stale anchor (previous transition's root)     -> L14-ANCHOR
#   E9  CM-E9 ... partial-proof attack: valid subset proofs are individually
#                 sound (E1 semantics) but gate acceptance is structurally
#                 impossible without the full-universe root -> gate rejects
#   U1  update: proof-based new root == tree-based new root     (AUTH-UPDATE)
#   C1  composition: two-transition chain with root threading; stale-root
#       replay across the chain boundary is rejected           (AUTH-COMMIT)
#
# Also: model-REFUSE checks (AUTH-CAPACITY, AUTH-PADKEY).
# Run:  python3 test_auth_verify.py   (exit 0 = all PASS)
# =============================================================================

from __future__ import annotations

import sys

from lin_verify import (LinCtx, LinRec, H, addr_of, apply_effects, build_rec,
                        canon_kv)
from auth_model import (DEPTH, NLEAVES, PAD_KEY, auth_proof, auth_root,
                        auth_update_root, auth_tree_update, auth_verify_incl,
                        canon_union, flat, flat_key, leaf_bytes, leaf_hash,
                        node_hash, tree_bytes, check_universe)
from auth_verify import AuthCtxA, LinRecE, build_rec_e, canon_core_e, verify_lineage_a

SK1 = (77).to_bytes(32, "big")
ROOT = b"\x00" * 32

# The Phase 1D-R1 canonical scenario (identical artifacts to the K suites).
PRE = {1: {0: 100, 1: 0}, 2: {0: 50, 1: 1}}
EFF = {1: {0: 25}, 2: {1: 7}}
POST = apply_effects(PRE, EFF)                    # honest exact post
U = canon_union(PRE, EFF, POST)
ANCHOR = auth_root(U, POST)                       # the authoritative commitment
REGISTRY = (5, 6)
AUTH = (addr_of(SK1),)

_results = []


def _case(name: str, got, want) -> None:
    ok = got == want
    _results.append(ok)
    print(f"[{name}] verdict='{got}' expect='{want}' "
          f"{'PASS' if ok else 'FAIL'}")


def _bool(name: str, got: bool, want: bool) -> None:
    _results.append(got == want)
    print(f"[{name}] got={got} expect={want} "
          f"{'PASS' if got == want else 'FAIL'}")


def honest_recE(sk=SK1, pre=PRE, eff=EFF, post=POST, tid=1, head=ROOT,
                anchor=ANCHOR) -> LinRecE:
    base = build_rec(tid, head, pre, eff, post, sk, 5)
    u = canon_union(pre, eff, post)
    sr = auth_root(u, post)
    return build_rec_e(base, sr), u


# ---------------------------------------------------------------------------
def main() -> int:
    print("=" * 69)
    print("SRW3 Phase 1E — authenticated-state adversarial suite (permanent)")
    print("=" * 69)

    recE, u = honest_recE()

    # E0 — non-vacuity witness --------------------------------------------
    _case("E0 non-vacuity", verify_lineage_a(recE, AuthCtxA(
        LinCtx(PRE, EFF, POST, REGISTRY, AUTH), ANCHOR), 1, ROOT), "VALID-A")

    idx = 3                                     # leaf of (2,1)
    k21 = flat_key(2, 1)
    p = auth_proof(U, POST, k21)

    # CM-E1 — forged VALUE in the proof ------------------------------------
    _bool("CM-E1 forged value", auth_verify_incl(
        ANCHOR, k21, 1, 8, int.from_bytes(p[:4], "big"), p), False)
    _bool("CM-E1 honest value ", auth_verify_incl(
        ANCHOR, k21, 1, 7, int.from_bytes(p[:4], "big"), p), True)

    # CM-E2 — tampered sibling path ----------------------------------------
    bad = bytearray(p)
    bad[40] ^= 0x01                              # flip one byte of sib[0]
    _bool("CM-E2 tampered path", auth_verify_incl(
        ANCHOR, k21, 1, 7, int.from_bytes(p[:4], "big"), bytes(bad)), False)

    # CM-E3 — extra key in presented post -----------------------------------
    post3 = {a: dict(s) for a, s in POST.items()}
    post3[2][9] = 999
    u3 = canon_union(PRE, EFF, post3)
    rec3 = build_rec(1, ROOT, PRE, EFF, post3, SK1, 5)
    recE3 = build_rec_e(rec3, auth_root(u3, post3))
    _case("CM-E3 extra key  ", verify_lineage_a(recE3, AuthCtxA(
        LinCtx(PRE, EFF, post3, REGISTRY, AUTH), ANCHOR), 1, ROOT), "L7-STATE")
    _bool("CM-E3 root diverges", auth_root(u3, post3) != ANCHOR, True)

    # CM-E4 — omitted key from presented post --------------------------------
    post4 = {1: {0: 25, 1: 0}, 2: {0: 50}}       # (2,1) omitted
    u4 = canon_union(PRE, EFF, post4)
    rec4 = build_rec(1, ROOT, PRE, EFF, post4, SK1, 5)
    recE4 = build_rec_e(rec4, auth_root(u4, post4))
    _case("CM-E4 omitted key ", verify_lineage_a(recE4, AuthCtxA(
        LinCtx(PRE, EFF, post4, REGISTRY, AUTH), ANCHOR), 1, ROOT), "L7-STATE")
    _bool("CM-E4 root diverges", auth_root(u4, post4) != ANCHOR, True)

    # CM-E5 — changed value in one leaf --------------------------------------
    post5 = {1: {0: 25, 1: 0}, 2: {0: 50, 1: 9}}
    u5 = canon_union(PRE, EFF, post5)
    rec5 = build_rec(1, ROOT, PRE, EFF, post5, SK1, 5)
    recE5 = build_rec_e(rec5, auth_root(u5, post5))
    _case("CM-E5 changed val ", verify_lineage_a(recE5, AuthCtxA(
        LinCtx(PRE, EFF, post5, REGISTRY, AUTH), ANCHOR), 1, ROOT), "L7-STATE")
    _bool("CM-E5 root diverges", auth_root(u5, post5) != ANCHOR, True)

    # CM-E6 — authorized-dishonest producer: foreign stateRoot ---------------
    #     all digests/signatures GENUINE over the honest artifacts; stateRoot
    #     is the root of a DIFFERENT state (here: over the PRE-state content);
    #     childE recomputed. The forged root diverges from the root the
    #     verifier recomputes over the PRESENTED post — L13 fires first
    #     (L14 is exercised by CM-E7, where the producer is root-consistent
    #     but the ANCHOR disagrees).
    other_sr = auth_root(u, PRE)
    rec6 = build_rec(1, ROOT, PRE, EFF, POST, SK1, 5)
    recE6 = build_rec_e(rec6, other_sr)
    _case("CM-E6 foreign root", verify_lineage_a(recE6, AuthCtxA(
        LinCtx(PRE, EFF, POST, REGISTRY, AUTH), ANCHOR), 1, ROOT),
        "L13-STATEROOT")
    _bool("CM-E6 forged != recomputed", other_sr != auth_root(u, POST), True)

    # CM-E7 — hidden write outside the declared footprint --------------------
    #     The producer declares eff' = EFF ∪ {(2,9):999} and post' matching —
    #     L7 holds, every digest/signature is genuine, universe grew by the
    #     hidden key. The ANCHOR (published for the honest transition) is what
    #     rejects: Level-2 binding catches what Level-1 cannot even see.
    eff7 = {1: {0: 25}, 2: {1: 7, 9: 999}}
    post7 = apply_effects(PRE, eff7)
    u7 = canon_union(PRE, eff7, post7)
    rec7 = build_rec(1, ROOT, PRE, eff7, post7, SK1, 5)
    recE7 = build_rec_e(rec7, auth_root(u7, post7))
    _case("CM-E7 hidden write", verify_lineage_a(recE7, AuthCtxA(
        LinCtx(PRE, eff7, post7, REGISTRY, AUTH), ANCHOR), 1, ROOT), "L14-ANCHOR")
    # variant: the write is NOT declared — the legacy layer rejects first
    post7b = {a: dict(s) for a, s in POST.items()}
    post7b[2][9] = 999
    rec7b = build_rec(1, ROOT, PRE, EFF, post7b, SK1, 5)
    recE7b = build_rec_e(rec7b, auth_root(canon_union(PRE, EFF, post7b), post7b))
    _case("CM-E7b undeclared  ", verify_lineage_a(recE7b, AuthCtxA(
        LinCtx(PRE, EFF, post7b, REGISTRY, AUTH), ANCHOR), 1, ROOT), "L7-STATE")

    # CM-E8 — stale anchor ----------------------------------------------------
    stale = auth_root(u, PRE)                    # some previous commitment
    _case("CM-E8 stale anchor", verify_lineage_a(recE, AuthCtxA(
        LinCtx(PRE, EFF, POST, REGISTRY, AUTH), stale), 1, ROOT), "L14-ANCHOR")

    # CM-E9 — partial-proof attack --------------------------------------------
    #     Proofs for a SUBSET of keys are individually sound (E1 semantics),
    #     but the gate's acceptance relation is the full-universe root:
    #     without the complete presented post there is no L7 evaluation and
    #     no L13/L14 match — partial coverage is structurally insufficient.
    subset = [k21, flat_key(1, 0)]
    proofs_ok = True
    for k in subset:
        pr = auth_proof(U, POST, k)
        a, s = k >> 32, k & 0xFFFFFFFF
        v = POST[a][s]
        proofs_ok &= auth_verify_incl(ANCHOR, k, 1, v,
                                      int.from_bytes(pr[:4], "big"), pr)
    _bool("CM-E9 subset proofs individually sound", proofs_ok, True)
    # the gate still demands the full map: feed it a partial post -> rejected
    partial_post = {2: {1: 7}}                   # only the proven subset's app
    rec9 = build_rec(1, ROOT, PRE, EFF, partial_post, SK1, 5)
    recE9 = build_rec_e(rec9, auth_root(U, POST))   # even with the TRUE root
    _case("CM-E9 partial gate ", verify_lineage_a(recE9, AuthCtxA(
        LinCtx(PRE, EFF, partial_post, REGISTRY, AUTH), ANCHOR), 1, ROOT),
        "L7-STATE")

    # U1 — AUTH-UPDATE: proof-based == tree-based -----------------------------
    knew = 42
    ru = auth_tree_update(U, POST, k21, knew)
    pu = auth_update_root(ANCHOR, k21, 1, 7, knew, int.from_bytes(p[:4], "big"),
                          p)
    _bool("U1  update equality", ru == pu, True)
    _bool("U1  update changes root", ru != ANCHOR, True)
    # forged old-value update proof is rejected
    _bool("U1  forged old value", auth_update_root(
        ANCHOR, k21, 1, 8, knew, int.from_bytes(p[:4], "big"), p), None)

    # C1 — AUTH-COMMIT composition: two-transition chain ----------------------
    pre2 = POST
    eff2 = {1: {0: 5}, 3: {4: 11}}
    post2 = apply_effects(pre2, eff2)
    u2 = canon_union(pre2, eff2, post2)
    anchor2 = auth_root(u2, post2)
    rec2e = honest_recE(pre=pre2, eff=eff2, post=post2, tid=2,
                        head=recE.child_e, anchor=anchor2)[0]
    _case("C1  chain step 2  ", verify_lineage_a(rec2e, AuthCtxA(
        LinCtx(pre2, eff2, post2, REGISTRY, AUTH), anchor2), 2, recE.child_e),
        "VALID-A")
    # stale-root replay across the chain boundary
    _case("C1  stale replay   ", verify_lineage_a(rec2e, AuthCtxA(
        LinCtx(pre2, eff2, post2, REGISTRY, AUTH), ANCHOR), 2, recE.child_e),
        "L14-ANCHOR")

    # model REFUSE checks ------------------------------------------------------
    _case("REFUSE capacity   ", check_universe(tuple(range(257))),
          "AUTH-CAPACITY")
    _case("REFUSE pad key     ",
          check_universe((flat_key(1, 0), PAD_KEY)), "AUTH-PADKEY")

    n_pass = sum(_results)
    n_all = len(_results)
    print("-" * 69)
    print(f"AUTHENTICATED-STATE SUITE: {n_pass}/{n_all} PASS")
    if n_pass == n_all:
        print("E0 witness ACCEPTED (non-vacuity); CM-E1..E9 REJECTED at the")
        print("documented layers; AUTH-UPDATE equality and AUTH-COMMIT chain")
        print("threading hold. Fixtures are the permanent Phase 1E baseline.")
        return 0
    print("SUITE FAILED — do not proceed with Phase 1E results.")
    return 1


if __name__ == "__main__":
    sys.exit(main())
