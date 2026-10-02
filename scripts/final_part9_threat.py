#!/usr/bin/env python3
# =============================================================================
# SRW3 Phase 1D-R1-FINAL — Part 9: authorized-dishonest producer (re-run).
#
# Threat: a producer holding a VALID private key (valid Keccak, valid
# signatures, ability to recompute EVERY digest and choose any presented
# pre-state/effects/post-state) attempts a record with
#     PostState != Apply(PreState, TrueEffects)
# while everything else is correctly re-signed.
#
# Required result: the verifier rejects at the state-composition layer.
# This is a concrete demonstration inside the modeled verifier domain —
# NOT a general cryptographic theorem.
#
# Layers exercised: Python L7-STATE (independent verifier) and, by the same
# construction, K's invalid-state-composition verdict (Part 2 final suite,
# neg1: same forgery built by LinBuildRec with genuine crypto).
# =============================================================================
import sys

sys.path.insert(0, "/home/z/my-project/srw3-work/python-gen")
from lin_verify import (LinCtx, LinRec, H, addr_of, apply_effects, build_rec,
                        canon_kv, i2b4, verify_lineage)
from coincurve import PrivateKey

SK1 = (77).to_bytes(32, "big")
ROOT = b"\x00" * 32
OUT = "/home/z/my-project/srw3-work/transcripts/audit/phase1d_r1/final_part9_threat.txt"

PRE = {1: {0: 100, 1: 0}, 2: {0: 50, 1: 1}}
EFFECTS = {1: {0: 25}, 2: {1: 7}}
HONEST_POST = apply_effects(PRE, EFFECTS)
ATTACK_POST = {a: dict(s) for a, s in HONEST_POST.items()}
ATTACK_POST[2][9] = 999          # THE extra entry (the L7 attack)
REGISTRY = (5, 6)
AUTH = (addr_of(SK1),)

with open(OUT, "w") as f:
    def log(s=""):
        print(s)
        f.write(s + "\n")

    log("=== SRW3 Phase 1D-R1-FINAL — Part 9: AUTHORIZED-DISHONEST PRODUCER ===")
    log("=== generated: " + __import__("subprocess").run(
        ["date", "-u", "+%Y-%m-%d %H:%M:%S UTC"],
        capture_output=True, text=True).stdout.strip() + " ===")
    log("")
    log("producer powers (ALL exercised below):")
    log("  valid private key SK1 = int 77 (secp256k1, libsecp256k1 path)")
    log("  valid keccak256 (standard, multiblock-correct)")
    log("  recomputes EVERY digest from the artifacts it presents")
    log("  re-signs evidence + signature with the valid key")
    log("  chooses the presented pre-state / effects / post-state freely")
    log("")
    log("attack scenario (identical artifacts to the Part-2 K suite):")
    log(f"  PreState  (claimed) : {PRE}")
    log(f"  TrueEffects         : {EFFECTS}")
    log(f"  honest Apply        : {HONEST_POST}")
    log(f"  presented PostState : {ATTACK_POST}   (extra entry (2,9):=999)")
    log("  PostState != Apply(PreState, TrueEffects) — the ONLY falsehood;")
    log("  every digest below is GENUINELY recomputed over the forged post.")
    log("")
    rec = build_rec(1, ROOT, PRE, EFFECTS, ATTACK_POST, SK1, 5)
    log("producer output (fully valid cryptography):")
    log(f"  inputD  = {rec.input_d.hex()}  = H(canon(PreState))    genuine")
    log(f"  effectD = {rec.effect_d.hex()}  = H(canon(TrueEffects)) genuine")
    log(f"  stateD  = {rec.state_d.hex()}  = H(canon(ATTACK post)) genuine (over the FORGED post)")
    log(f"  authority = {rec.authority.hex()}  = addr(SK1)")
    log(f"  evidence  = {rec.evidence.hex()[:24]}...  valid RFC6979 sig over IntentHash")
    log(f"  sig       = {rec.sig.hex()[:24]}...  valid RFC6979 sig over CoreHash")
    log(f"  child     = {rec.child.hex()}  = H(CanonFull incl. sig) genuine")
    log("")
    ctx = LinCtx(PRE, EFFECTS, ATTACK_POST, REGISTRY, AUTH)
    verdict = verify_lineage(rec, ctx, 1, ROOT)
    log(f"independent Python verifier verdict : {verdict}")
    log("  -> rejection layer: L7 (state-composition; canonical finite-map")
    log("     equality post_map == composed_map). All L1..L6 pass — the")
    log("     producer's cryptography is PERFECT; the state correspondence")
    log("     is what fails.")
    log("")
    log("K-side counterpart (Part 2 final suite, neg1 = same construction")
    log("built by LinBuildRec with genuine crypto; see")
    log("part7_k_composition_suite_final.txt):")
    log("  pos=valid;neg1=invalid-state-composition;"
    "neg2=invalid-state-composition;neg3=invalid-state-composition")
    log("  -> the K verifier rejects the same forgery at")
    log("     invalid-state-composition (the 13th, composition-aware verdict).")
    log("")
    ok = verdict == "L7-STATE"
    log(f"RESULT: {'PASS — rejection at the state-composition layer (L7-STATE /' if ok else 'FAIL —'}"
          f"{' invalid-state-composition on the K side)' if ok else ''}")
    log("PART9_THREAT_DONE")
    f.flush()

sys.exit(0 if verdict == "L7-STATE" else 1)
