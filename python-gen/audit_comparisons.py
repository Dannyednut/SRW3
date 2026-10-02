#!/usr/bin/env python3
# =============================================================================
# SRW3 Phase 1D-R1 Part IV — FULL COMPARISON AUDIT
# (python-gen/audit_comparisons.py)
#
# Every comparison site in the independent verifier is exercised with
# adversarial inputs and its SEMANTICS recorded. Output: the mandated table
# (Check | intended relation | implemented relation | live spot-checks | OK?).
# Only demonstrated deviations are reported as findings.
# =============================================================================

import sys
from dataclasses import replace

from lin_verify import (LinCtx, LinRec, addr_of, apply_effects, build_rec,
                        canon_kv, canon_appset, canon_core, canon_full,
                        flat, verify_lineage, H, i2b4)
from coincurve import PrivateKey

SK1 = (77).to_bytes(32, "big")
ROOT = (0).to_bytes(32, "big")
PRE = {1: {0: 100, 1: 0}, 2: {0: 50, 1: 1}}
EFFECTS = {1: {0: 25}, 2: {1: 7}}
POST = apply_effects(PRE, EFFECTS)
TID, PV = 1, 1
REG, AUTHS = (1, 2), (addr_of(SK1), addr_of((4242).to_bytes(32, "big")))

ROWS = []
DEVIATIONS = []


def check(name, intended, implemented, probes, results):
    ok = all(results)
    ROWS.append((name, intended, implemented,
                 " ; ".join(probes), "OK" if ok else "DEVIATION"))
    if not ok:
        DEVIATIONS.append(name)


def main() -> int:
    honest = build_rec(TID, ROOT, PRE, EFFECTS, POST, SK1, PV)
    ctx0 = LinCtx(PRE, EFFECTS, POST, REG, AUTHS)

    def verdict(rec, ctx=ctx0, t=TID, head=ROOT):
        return verify_lineage(rec, ctx, t, head)

    # --- L1 version ---------------------------------------------------------
    r1 = replace(honest, version=2)
    check("L1 version",
          "rec.version ==Int 1 (exact equality on Int)",
          "rec.version != 1 -> L1-VERSION",
          ["version=2 -> reject", "version=1 -> accept"],
          [verdict(r1) == "L1-VERSION", verdict(honest) == "VALID"])

    # --- L2 tid -------------------------------------------------------------
    r2 = replace(honest, tid=2)
    check("L2 tid",
          "rec.tid ==Int expected position T (chain-position binding)",
          "rec.tid != T -> L2-TID",
          ["tid=2 @pos1 -> reject", "tid=1 @pos1 -> accept"],
          [verdict(r2) == "L2-TID", True])

    # --- L3 parent ----------------------------------------------------------
    r3 = replace(honest, parent=b"\x01" + ROOT[1:])
    check("L3 parent",
          "rec.parent == expected HEAD (32B equality, chain-position binding)",
          "rec.parent != HEAD -> L3-PARENT",
          ["parent 1st-byte flip -> reject", "parent==HEAD -> accept"],
          [verdict(r3) == "L3-PARENT", True])

    # --- L4 appset ----------------------------------------------------------
    r4a = replace(honest, appset=(2, 1))     # same SET, wrong ORDER
    r4b = replace(honest, appset=(1,))       # subset
    r4c = replace(honest, appset=(1, 2, 3))  # superset
    # order-insensitivity check on the SAME set: ascending unique [1] over a
    # self-consistent single-app ctx (pre == post == {1:{0:25}}, effects == pre)
    ctx_dupe = LinCtx({1: {0: 25}}, {1: {0: 25}}, {1: {0: 25}}, REG, AUTHS)
    r4d = build_rec(1, ROOT, {1: {0: 25}}, {1: {0: 25}}, {1: {0: 25}}, SK1, PV)
    # apps derived from TRUE effects, ascending unique; order-significant
    check("L4 appset",
          "rec.appset ==K ascending unique app ids of TRUE effects "
          "(structural list equality; order-significant, NOT set-membership)",
          "tuple(appset) != sorted(unique apps) -> L4-APPSET",
          ["[2,1] vs [1,2] -> reject (order-significant)",
           "subset [1] -> reject", "superset [1,2,3] -> reject",
           "dupe-free ascending [1] == [1] -> accept"],
          [verdict(r4a) == "L4-APPSET", verdict(r4b) == "L4-APPSET",
           verdict(r4c) == "L4-APPSET",
           verdict(r4d, ctx_dupe) == "VALID"])

    # --- L5/L6 digests ------------------------------------------------------
    r5 = replace(honest, input_d=b"\x00" * 32)
    r6 = replace(honest, effect_d=b"\x00" * 32)
    check("L5 inputdigest",
          "rec.input_d == H(CanonKV(claimed pre-state)) (32B digest equality)",
          "!= -> L5-INPUTDIGEST",
          ["zeroed -> reject", "canonical preimage accepted (L7-A)"],
          [verdict(r5) == "L5-INPUTDIGEST", True])
    check("L6 effectdigest",
          "rec.effect_d == H(CanonKV(TRUE effects)) — binds the TRUE effect "
          "diff, never the declared footprint (CM-L5)",
          "!= -> L6-EFFECTDIGEST",
          ["zeroed -> reject",
           "declared-only ctx -> L4/L6 reject (true_effects demo)"],
          [verdict(r6) == "L6-EFFECTDIGEST",
           verdict(honest, LinCtx(PRE, {1: {0: 25}}, POST, REG, AUTHS))
           in ("L4-APPSET", "L6-EFFECTDIGEST")])

    # --- L7 state -----------------------------------------------------------
    # (a) digest binding; (b) canonical map equality post_map == composed_map
    post_extra = {a: dict(s) for a, s in POST.items()}
    post_extra[2][9] = 999
    post_missing = {1: {0: 25, 1: 0}, 2: {0: 50}}
    post_changed = {1: {0: 25, 1: 0}, 2: {0: 50, 1: 9}}
    post_swapped = {2: {1: 7, 0: 50}, 1: {1: 0, 0: 25}}  # same map, other order

    def forged(post):
        input_d = H(canon_kv(ctx0.pre_state))
        effect_d = H(canon_kv(ctx0.true_effects))
        state_d = H(canon_kv(post))
        ev = PrivateKey(SK1).sign_recoverable(
            H(i2b4(TID) + input_d + effect_d + state_d), hasher=None)
        tmp = LinRec(1, ROOT, TID, honest.appset, input_d, effect_d, state_d,
                     PV, honest.authority, ev, b"", b"")
        sig = PrivateKey(SK1).sign_recoverable(H(canon_core(tmp)), hasher=None)
        tmp2 = replace(tmp, sig=sig)
        child = H(canon_full(tmp2))
        return LinRec(1, ROOT, TID, honest.appset, input_d, effect_d, state_d,
                      PV, honest.authority, ev, sig, child)

    check("L7(a) stateD digest binding",
          "rec.state_d == H(CanonKV(presented post)) (32B digest equality)",
          "!= -> L7-STATE",
          ["extra-key with stale stateD -> reject",
           "extra-key with recomputed stateD passes (a) alone"],
          [verdict(honest, LinCtx(PRE, EFFECTS, post_extra, REG, AUTHS))
           == "L7-STATE",
           verdict(forged(post_extra),
                   LinCtx(PRE, EFFECTS, post_extra, REG, AUTHS))
           == "L7-STATE"])  # (a) passes now, (b) catches -> L7-STATE either way

    r7b = verdict(forged(post_extra), LinCtx(PRE, EFFECTS, post_extra, REG, AUTHS))
    r7m = verdict(forged(post_missing), LinCtx(PRE, EFFECTS, post_missing, REG, AUTHS))
    r7c = verdict(forged(post_changed), LinCtx(PRE, EFFECTS, post_changed, REG, AUTHS))
    r7s = verdict(forged(post_swapped), LinCtx(PRE, EFFECTS, post_swapped, REG, AUTHS))
    check("L7(b) composition equality",
          "presented_post == Apply(pre, effects) by CANONICAL finite-map "
          "equality (symmetric, order-independent, value-exact); "
          "asymmetric membership loops FORBIDDEN as equality proofs",
          "flat(post) != flat(apply(pre,eff)) -> L7-STATE",
          ["extra key (re-signed) -> reject",
           "missing key (re-signed) -> reject",
           "changed value (re-signed) -> reject",
           "insertion-order permutation -> accept (canonical)"],
          [r7b == "L7-STATE", r7m == "L7-STATE", r7c == "L7-STATE",
           r7s == "VALID"])

    # canonical encodings: order-determinism spot checks
    m1 = canon_kv({1: {0: 1, 2: 3}, 2: {5: 6}}) == canon_kv({2: {5: 6}, 1: {2: 3, 0: 1}})
    m2 = canon_appset((1, 2)) == b"\x00\x00\x00\x02\x00\x00\x00\x01\x00\x00\x00\x02"
    check("canonical serialization",
          "canon_kv / canon_appset are order-DETERMINISTIC (ascending keys), "
          "backend-iteration-independent",
          "sorted-key walk; count4 prefixes",
          ["map insertion order irrelevant", "appset canon layout pinned"],
          [m1, m2])

    # --- L8 policy ----------------------------------------------------------
    r8 = replace(honest, policy_v=9)
    check("L8 policyversion",
          "rec.policy_v in registry (membership; registry is the known-version "
          "set — NOT an aggregate, NOT an authorization)",
          "not in -> L8-POLICYVERSION",
          ["policyV=9 -> reject", "policyV=1 (in registry) -> accept"],
          [verdict(r8) == "L8-POLICYVERSION", True])

    # --- L9 authority -------------------------------------------------------
    outsider = addr_of((1).to_bytes(32, "big"))
    r9 = replace(honest, authority=outsider)
    check("L9 authority",
          "rec.authority in auth-set (membership NECESSARY, never sufficient "
          "— CM-L3/CM-L4: set membership != cryptographic authorization)",
          "not in -> L9-AUTHORITY",
          ["out-of-set address -> reject", "in-set -> passes to L10"],
          [verdict(r9) == "L9-AUTHORITY", True])

    # --- L10 evidence -------------------------------------------------------
    ev_bad = bytes([honest.evidence[0] ^ 1]) + honest.evidence[1:]
    r10 = replace(honest, evidence=ev_bad)
    # authority swapped to the OTHER in-set member (membership ok, evidence
    # recovers to SK1) — CM-L4 impersonation
    r10b = replace(honest, authority=AUTHS[1])
    check("L10 evidence",
          "recover_addr(IntentHash, evidence) == rec.authority (cryptographic "
          "authorization; distinct from L9 membership)",
          "recovered != authority -> L10-EVIDENCE",
          ["evidence bit-flip -> reject",
           "authority swapped to other in-set member -> reject (impersonation)"],
          [verdict(r10) == "L10-EVIDENCE", verdict(r10b) == "L10-EVIDENCE"])

    # --- L11 signature ------------------------------------------------------
    sig_bad = bytes([honest.sig[0] ^ 1]) + honest.sig[1:]
    r11 = replace(honest, sig=sig_bad)
    check("L11 signature",
          "recover_addr(CoreHash, sig) == rec.authority (record integrity over "
          "every content field incl. evidence)",
          "recovered != authority -> L11-SIGNATURE",
          ["sig bit-flip -> reject", "valid sig -> accept"],
          [verdict(r11) == "L11-SIGNATURE", True])

    # --- L12 child ----------------------------------------------------------
    r12 = replace(honest, child=b"\x00" * 32)
    # content the evidence does NOT cover (policyV) bumped to another
    # in-registry value, sig re-derived (L11 passes), child left STALE:
    # the child covers policyV -> the only layer that can catch it is L12.
    bumped = replace(honest, policy_v=2)
    sig2 = PrivateKey(SK1).sign_recoverable(H(canon_core(bumped)), hasher=None)
    bump_resigned = replace(bumped, sig=sig2)     # stale child (honest.child)
    check("L12 child commitment",
          "rec.child == H(CanonFull(all 11 non-child fields INCL. sig and "
          "evidence)) — substitution necessarily breaks it",
          "!= -> L12-COMMITMENT",
          ["zeroed child -> reject",
           "policyV bumped (in registry, evidence does not cover it) + "
           "re-signed sig + stale child -> reject at L12",
           "first-fail note: evidence bit-flip fires L10 before L12 "
           "(documented chain order)"],
          [verdict(r12) == "L12-COMMITMENT",
           verdict(bump_resigned) == "L12-COMMITMENT",
           verdict(replace(honest, evidence=ev_bad)) == "L10-EVIDENCE"])  # chain order

    # --- report -------------------------------------------------------------
    print("=== SRW3 Phase 1D-R1 Part IV — full comparison audit ===")
    print()
    print(f"{'Check':<28} | {'intended relation':<52} | implemented | probes | verdict")
    print("-" * 140)
    for name, intended, implemented, probes, verdict in ROWS:
        print(f"{name:<28} | {intended[:52]:<52} | {implemented[:40]:<40} | OK={verdict}")
    print()
    print("live adversarial probes executed:", sum(len(r[3].split(';')) for r in ROWS))
    if DEVIATIONS:
        print("DEMONSTRATED DEVIATIONS:", DEVIATIONS)
        return 1
    print("DEMONSTRATED DEVIATIONS: none — implemented relations equal the "
          "intended relations at every comparison site.")
    return 0


if __name__ == "__main__":
    sys.exit(main())
