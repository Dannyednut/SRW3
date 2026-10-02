#!/usr/bin/env python3
# =============================================================================
# !!! HISTORICAL EVIDENCE — PRE-FIX EXPECTATIONS (Part I baseline, 444672b).
# This script re-demonstrates the defect against the PRE-FIX verifier state.
# After the Part II fix (commit history: "Part II"), T2 is rejected and this
# script's T2 expectation no longer holds against the live lin_verify.py.
# The POST-FIX permanent suite is test_lin_verify_L7.py (Part III); the
# frozen pre-fix transcript is transcripts/audit/phase1d_r1/
# l7_attack_prefix.txt. Do NOT delete this file: it is the recorded
# reproduction recipe for the L7 extra-key attack.
# =============================================================================
# SRW3 Phase 1D-R1 Part I — L7 EXTRA-KEY ATTACK REPRODUCTION (PRE-FIX EVIDENCE)
# (python-gen/test_lin_attack_L7.py)
#
# This script re-demonstrates, against the independent Python lineage verifier
# in its PRE-FIX state (frozen baseline), the soundness defect that keeps
# Phase 1D open:
#
#   The L7 state layer establishes only  Composed ⊆ PresentedPost.
#   An authorized-but-dishonest producer (valid key, valid signatures) can
#   fabricate an EXTRA post-state entry — a storage slot that is in neither
#   the pre-state nor the true effects — recompute stateD, evidence, sig and
#   child, and the verifier returns VALID for a record whose presented
#   post-state does NOT equal Apply(PreState, TrueEffects).
#
# THE FORGED RECORD AND THE ATTACK INPUTS ARE PERMANENT REGRESSION FIXTURES
# (R1 mandate: the L7 attack must never be deleted). Part II fixes L7 to
# canonical map equality; Part III freezes the post-fix adversarial suite
# where the SAME inputs MUST be rejected with reason L7-STATE.
#
# Pre-fix expectations (this file, Part I baseline):
#   T1 honest exact state ..................... VALID        (sanity)
#   T2 EXTRA KEY, fully re-signed ............. VALID   <<< THE DEFECT
#   T3 extra key, naive (stateD stale) ........ L7-STATE  (digest binding alone)
#   T4 missing composed key, re-signed ........ L7-STATE  (subset loop catches)
#   T5 changed value, re-signed ............... L7-STATE  (subset loop catches)
#
# Note the asymmetry T2 vs T4/T5: exactly the hole Composed ⊆ Post leaves.
# =============================================================================

import sys
from dataclasses import replace

from lin_verify import (LinCtx, LinRec, addr_of, apply_effects, build_rec,
                        canon_kv, verify_lineage, H, i2b4)

SK1 = (77).to_bytes(32, "big")      # LinDemoKey1 (K: Int2Bytes(32, 77, BE))
SK2 = (4242).to_bytes(32, "big")    # LinDemoKey2
ROOT = (0).to_bytes(32, "big")      # LinRoot

PRE = {1: {0: 100, 1: 0},           # app1: oracle-like balances
       2: {0: 50, 1: 1}}           # app2
EFFECTS = {1: {0: 25},              # app1.slot0 := 25 (declared)
           2: {1: 7}}               # app2.slot1 := 7  (hidden side effect)
POST = apply_effects(PRE, EFFECTS)  # honest post = PreState o TrueEffects

TID = 1
POLICY_V = 1
REGISTRY = (1, 2)
AUTH_SET = (addr_of(SK1), addr_of(SK2))
CTX_HONEST = LinCtx(PRE, EFFECTS, POST, REGISTRY, AUTH_SET)


def forge(rec: LinRec, *, post, sk: bytes, ctx: LinCtx) -> LinRec:
    """Authorized-dishonest producer powers: recompute stateD over an arbitrary
    presented post-state and re-sign everything with the VALID key. Every
    digest/signature/commitment in the forged record is cryptographically
    genuine — only the post-state's correspondence to PreState o Effects is
    false."""
    input_d = H(canon_kv(ctx.pre_state))
    effect_d = H(canon_kv(ctx.true_effects))
    state_d = H(canon_kv(post))
    auth = rec.authority
    ev = PrivateKey_(sk).sign_recoverable(
        H(i2b4(rec.tid) + input_d + effect_d + state_d), hasher=None)
    tmp = LinRec(rec.version, rec.parent, rec.tid, rec.appset, input_d,
                 effect_d, state_d, rec.policy_v, auth, ev, b"", b"")
    from lin_verify import core_hash, canon_full
    sig = PrivateKey_(sk).sign_recoverable(core_hash(tmp), hasher=None)
    tmp2 = LinRec(rec.version, rec.parent, rec.tid, rec.appset, input_d,
                  effect_d, state_d, rec.policy_v, auth, ev, sig, b"")
    child = H(canon_full(tmp2))
    return LinRec(rec.version, rec.parent, rec.tid, rec.appset, input_d,
                  effect_d, state_d, rec.policy_v, auth, ev, sig, child)


def PrivateKey_(sk: bytes):
    from coincurve import PrivateKey
    return PrivateKey(sk)


def main() -> int:
    print("=== SRW3 Phase 1D-R1 Part I — L7 extra-key attack reproduction "
          "(PRE-FIX baseline) ===")
    print("=== verifier: python-gen/lin_verify.py (independent; keccak256 + "
          "libsecp256k1) ===")
    print("=== threat model: AUTHORIZED dishonest producer (valid key SK1) ===")
    print()

    failures = 0

    # ---- T1: honest record over the exact transition outcome ---------------
    honest = build_rec(TID, ROOT, PRE, EFFECTS, POST, SK1, POLICY_V)
    v1 = verify_lineage(honest, CTX_HONEST, TID, ROOT)
    print("[T1] honest record, post == Apply(Pre, Effects)")
    print("     verdict:", v1, " expect: VALID (sanity)")
    if v1 != "VALID":
        failures += 1
    print()

    # ---- T2: THE L7 EXTRA-KEY ATTACK ---------------------------------------
    # presented post-state = honest post + fabricated slot app2.slot9 := 999
    # (in NEITHER pre-state NOR true effects). Fully re-signed with SK1.
    post_attack = {a: dict(s) for a, s in POST.items()}
    post_attack.setdefault(2, {})[9] = 999
    ctx_attack = LinCtx(PRE, EFFECTS, post_attack, REGISTRY, AUTH_SET)
    forged = forge(honest, post=post_attack, sk=SK1, ctx=ctx_attack)
    v2 = verify_lineage(forged, ctx_attack, TID, ROOT)
    print("[T2] L7 EXTRA-KEY ATTACK: presented post carries extra entry "
          "(app2, slot9) := 999")
    print("     (extra slot in neither PreState nor TrueEffects); stateD, "
          "evidence, sig, child")
    print("     recomputed with the AUTHORIZED key — every cryptographic "
          "field genuine.")
    print("     presented post :", {a: dict(s) for a, s in sorted(post_attack.items())})
    print("     Apply(Pre,Eff) :", {a: dict(s) for a, s in sorted(POST.items())})
    print("     verdict:", v2, " expect(PRE-FIX): VALID  <-- THE SOUNDNESS "
                               "DEFECT (R1 Part II fixes to L7-STATE)")
    if v2 != "VALID":
        failures += 1
    print()

    # ---- T3: same forgery but stateD NOT recomputed (naive outsider) -------
    naive = replace(honest)  # honest record fields, presented post mutated
    ctx_naive = LinCtx(PRE, EFFECTS, post_attack, REGISTRY, AUTH_SET)
    v3 = verify_lineage(naive, ctx_naive, TID, ROOT)
    print("[T3] extra key presented, stateD NOT recomputed (naive tamper)")
    print("     verdict:", v3, " expect: L7-STATE (digest binding catches "
                               "the naive variant)")
    if v3 != "L7-STATE":
        failures += 1
    print()

    # ---- T4: MISSING composed key, fully re-signed -------------------------
    post_missing = {1: {0: 25, 1: 0}, 2: {0: 50}}   # app2.slot1 := 7 absent
    ctx_missing = LinCtx(PRE, EFFECTS, post_missing, REGISTRY, AUTH_SET)
    forged_missing = forge(honest, post=post_missing, sk=SK1, ctx=ctx_missing)
    v4 = verify_lineage(forged_missing, ctx_missing, TID, ROOT)
    print("[T4] missing composed entry ((app2,slot1):=7 absent), fully re-signed")
    print("     verdict:", v4, " expect: L7-STATE (subset loop catches)")
    if v4 != "L7-STATE":
        failures += 1
    print()

    # ---- T5: CHANGED composed value, fully re-signed -----------------------
    post_changed = {1: {0: 25, 1: 0}, 2: {0: 50, 1: 9}}  # slot1 := 9 (not 7)
    ctx_changed = LinCtx(PRE, EFFECTS, post_changed, REGISTRY, AUTH_SET)
    forged_changed = forge(honest, post=post_changed, sk=SK1, ctx=ctx_changed)
    v5 = verify_lineage(forged_changed, ctx_changed, TID, ROOT)
    print("[T5] changed composed value ((app2,slot1):=9 instead of 7), fully re-signed")
    print("     verdict:", v5, " expect: L7-STATE (subset loop catches)")
    if v5 != "L7-STATE":
        failures += 1
    print()

    print("=== PRE-FIX SUMMARY ===")
    if failures == 0:
        print("REPRODUCED: the extra-key forgery (T2) is ACCEPTED by the "
              "pre-fix verifier while T4/T5 are correctly rejected —")
        print("L7 establishes Composed ⊆ Post, not Composed == Post. "
              "Phase 1D stays open; R1 Part II (exact map equality) is "
              "mandatory before close.")
        print("T2 inputs frozen as permanent regression fixture "
              "(post-fix expectation: L7-STATE).")
        return 0
    print("UNEXPECTED: pre-fix behavior deviates from the recorded defect "
          "pattern (%d mismatching case(s)) — investigate before Part II."
          % failures)
    return 1


if __name__ == "__main__":
    sys.exit(main())
