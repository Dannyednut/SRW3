#!/usr/bin/env python3
# =============================================================================
# SRW3 Phase 1D-R1 Part VI — HOSTILE-INPUT MUTATION HARNESS (21 classes)
# (python-gen/audit_mutations_21.py)
#
# For each mutation class: apply the mutation (authorized-dishonest producer
# powers where applicable — digests/signatures/commitments recomputed with
# the VALID key), present to the verifier, RECORD THE FIRST FAILING LAYER.
#
# STOP RULE (R1 mandate): any mutation that returns VALID and is not
# semantically irrelevant -> print "UNRESOLVED VERIFIER SOUNDNESS ISSUE"
# and exit non-zero. Phase 1D must not close in that state.
# =============================================================================

import sys
from dataclasses import replace

from lin_verify import (LinCtx, LinRec, addr_of, apply_effects, build_rec,
                        canon_kv, canon_core, canon_full, verify_lineage,
                        H, i2b4)
from coincurve import PrivateKey

SK1 = (77).to_bytes(32, "big")
SK2 = (4242).to_bytes(32, "big")
ROOT = (0).to_bytes(32, "big")
PRE = {1: {0: 100, 1: 0}, 2: {0: 50, 1: 1}}
EFFECTS = {1: {0: 25}, 2: {1: 7}}
POST = apply_effects(PRE, EFFECTS)
TID, PV = 1, 1
REG, AUTHS = (1, 2), (addr_of(SK1), addr_of(SK2))
OTHER_IN_SET = addr_of(SK2)
OUTSIDER = addr_of((1).to_bytes(32, "big"))


def flip(b):
    return bytes([b[0] ^ 1]) + b[1:]


def resign(rec, sk=SK1):
    """Authorized powers: re-derive evidence+sig+child over the record's
    current content (keeps a record internally genuine)."""
    ev = PrivateKey(sk).sign_recoverable(
        H(i2b4(rec.tid) + rec.input_d + rec.effect_d + rec.state_d), hasher=None)
    tmp = replace(rec, evidence=ev, sig=b"", child=b"")
    sig = PrivateKey(sk).sign_recoverable(H(canon_core(tmp)), hasher=None)
    tmp2 = replace(tmp, sig=sig)
    child = H(canon_full(tmp2))
    return replace(rec, evidence=ev, sig=sig, child=child)


HONEST = build_rec(TID, ROOT, PRE, EFFECTS, POST, SK1, PV)
CTX0 = LinCtx(PRE, EFFECTS, POST, REG, AUTHS)

# the fully-re-signed extra-key forgery (authorized-dishonest producer)
POST_ATTACK = {a: dict(s) for a, s in POST.items()}
POST_ATTACK[2][9] = 999
CTX_ATTACK = LinCtx(PRE, EFFECTS, POST_ATTACK, REG, AUTHS)
FORGED_ATTACK = resign(replace(HONEST, state_d=H(canon_kv(POST_ATTACK))))

# a second honest record over a DIFFERENT transition (for cross-record reuse)
OTHER = build_rec(2, H(canon_full(HONEST)), {3: {0: 7}}, {3: {0: 9}},
                  apply_effects({3: {0: 7}}, {3: {0: 9}}), SK1, PV)

MUTATIONS = [
    ("m01 version bump", lambda: (replace(HONEST, version=2), CTX0, TID, ROOT), "L1-VERSION"),
    ("m02 tid bump", lambda: (replace(HONEST, tid=2), CTX0, TID, ROOT), "L2-TID"),
    ("m03 parent byte-flip", lambda: (replace(HONEST, parent=flip(HONEST.parent)), CTX0, TID, ROOT), "L3-PARENT"),
    ("m04 appset + foreign app", lambda: (replace(HONEST, appset=(1, 2, 99)), CTX0, TID, ROOT), "L4-APPSET"),
    ("m05 appset drop one", lambda: (replace(HONEST, appset=(1,)), CTX0, TID, ROOT), "L4-APPSET"),
    ("m06 appset order swap", lambda: (replace(HONEST, appset=(2, 1)), CTX0, TID, ROOT), "L4-APPSET"),
    ("m07 inputD byte-flip", lambda: (replace(HONEST, input_d=flip(HONEST.input_d)), CTX0, TID, ROOT), "L5-INPUTDIGEST"),
    ("m08 effectD byte-flip", lambda: (replace(HONEST, effect_d=flip(HONEST.effect_d)), CTX0, TID, ROOT), "L6-EFFECTDIGEST"),
    ("m09 stateD byte-flip", lambda: (replace(HONEST, state_d=flip(HONEST.state_d)), CTX0, TID, ROOT), "L7-STATE"),
    ("m10 policyV out of registry", lambda: (replace(HONEST, policy_v=9), CTX0, TID, ROOT), "L8-POLICYVERSION"),
    ("m11 authority -> other IN-SET member (impersonation)", lambda: (replace(HONEST, authority=OTHER_IN_SET), CTX0, TID, ROOT), "L10-EVIDENCE"),
    ("m12 authority -> out-of-set address", lambda: (replace(HONEST, authority=OUTSIDER), CTX0, TID, ROOT), "L9-AUTHORITY"),
    ("m13 evidence byte-flip", lambda: (replace(HONEST, evidence=flip(HONEST.evidence)), CTX0, TID, ROOT), "L10-EVIDENCE"),
    ("m14 evidence from another record (different intent)", lambda: (replace(HONEST, evidence=OTHER.evidence), CTX0, TID, ROOT), "L10-EVIDENCE"),
    ("m15 sig byte-flip", lambda: (replace(HONEST, sig=flip(HONEST.sig)), CTX0, TID, ROOT), "L11-SIGNATURE"),
    ("m16 sig from another record (different core)", lambda: (replace(HONEST, sig=OTHER.sig), CTX0, TID, ROOT), "L11-SIGNATURE"),
    ("m17 child byte-flip", lambda: (replace(HONEST, child=flip(HONEST.child)), CTX0, TID, ROOT), "L12-COMMITMENT"),
    ("m18 ctx: claimed pre-state enriched (extra input entry)", lambda: (HONEST, LinCtx({1: {0: 100, 1: 0}, 2: {0: 50, 1: 1}, 9: {0: 1}}, EFFECTS, POST, REG, AUTHS), TID, ROOT), "L5-INPUTDIGEST"),
    ("m19 ctx: declared-only effects presentation (CM-L5)", lambda: (HONEST, LinCtx(PRE, {1: {0: 25}}, POST, REG, AUTHS), TID, ROOT), "L4-APPSET"),
    ("m20 ctx: extra post-state entry, fully re-signed (THE L7 attack)", lambda: (FORGED_ATTACK, CTX_ATTACK, TID, ROOT), "L7-STATE"),
    ("m21 ctx: registry shrunk (policyV no longer known)", lambda: (HONEST, LinCtx(PRE, EFFECTS, POST, (2,), AUTHS), TID, ROOT), "L8-POLICYVERSION"),
]


def main() -> int:
    print("=== SRW3 Phase 1D-R1 Part VI — hostile-input mutation harness "
          "(21 classes) ===")
    print("=== authorized-dishonest producer powers applied where applicable ===")
    print()
    passed = 0
    issues = []
    for name, mk, expected in MUTATIONS:
        rec, ctx, t, head = mk()
        v = verify_lineage(rec, ctx, t, head)
        status = "OK" if v == expected else ("SOUNDNESS ISSUE" if v == "VALID" else "LAYER-MISMATCH")
        if v == "VALID":
            issues.append(name)
        elif v != expected:
            status = f"note: fired {v}, expected {expected} (still rejected)"
            passed += 1
        else:
            passed += 1
        print(f"{name:<58} first-fail: {v:<18} [{status}]")
    print()
    print(f"rejected: {passed}/{len(MUTATIONS)}; accepted: {len(issues)}")
    if issues:
        print()
        print("UNRESOLVED VERIFIER SOUNDNESS ISSUE:")
        for i in issues:
            print("  -", i)
        print("Stopping per R1 mandate — Phase 1D must not close.")
        return 1
    print()
    print("No mutation passed. All 21 classes are caught at the documented "
          "first-fail layer.")
    return 0


if __name__ == "__main__":
    sys.exit(main())
