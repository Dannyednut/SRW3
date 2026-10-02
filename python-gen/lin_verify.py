#!/usr/bin/env python3
# =============================================================================
# SRW3 Phase 1D-R1 — INDEPENDENT Python lineage verifier (python-gen/lin_verify.py)
#
# Part I (R1 mandate): PRE-FIX BASELINE, FROZEN AS EVIDENCE OF THE L7 DEFECT.
#
# This module is an independent reimplementation of the Phase-1D lineage
# verifier (K: k/phase1d/srw3lin{,-verify}.k). It shares NO code and NO state
# with the K side: it re-derives every canonical serialization, digest and
# signature from first principles (pure Python + libsecp256k1 via coincurve,
# the same library family the K krypto shim links).
#
# Record model (12 fields, canonical order):
#   Lambda_i = < Version, ParentCommitment, TransitionId, AppSet, InputDigest,
#                EffectDigest, StateDigest, PolicyVersion, AuthorityId,
#                AuthorizationEvidence, Signature, ChildCommitment >
#   CoreHash   = Keccak256(CanonCore( ... 11 fields minus Sig, Child ... ))
#   IntentHash = Keccak256(Tid4 || InputDigest || EffectDigest || StateDigest)
#   Child      = Keccak256(CanonFull( ... 11 fields incl. Sig ... ))
#
# Verifier contract: VerifyLineage(rec, ctx, T, HEAD) -> verdict string.
# First-fail chain of 12 layers (mirrors the K verdict order):
#   L1 version | L2 tid | L3 parent | L4 appset | L5 inputdigest |
#   L6 effectdigest | L7 STATE | L8 policyversion | L9 authority |
#   L10 evidence | L11 signature | L12 commitment | VALID
#
# =============================================================================
# !!! R1 Part I — KNOWN SOUNDNESS DEFECT, PRESERVED ON PURPOSE (do NOT delete):
#
#   Layer L7 below checks the state relation
#       Composed == PreState o Effects        (composition, via subset loop)
#       stateD   == H(Canon(PresentedPost))   (digest binding)
#   but the composition direction is implemented as an ASYMMETRIC MEMBERSHIP
#   LOOP: every entry of Composed must be matched in the presented post-state,
#   while EXTRA entries of the presented post-state that are not in Composed
#   are silently accepted. L7 therefore establishes
#       Composed ⊆ Post      (NOT  Composed == Post).
#   A record whose presented post-state carries an extra entry — with stateD,
#   evidence, sig and child recomputed by the (authorized) producer — passes
#   all twelve layers. The attack reproduction lives in
#   test_lin_attack_L7.py; the transcript is frozen at
#   transcripts/audit/phase1d_r1_l7_attack_prefix.txt.
#
#   R1 Part II replaces the subset loop with canonical finite-map equality
#   (post_map == composed_map). The subset form below must remain visible in
#   git history as the recorded pre-fix state (regression provenance).
# =============================================================================
#
# Threat model note (R1): the adversary INCLUDES the authorized-but-dishonest
# record producer — anyone holding a valid signing key, able to choose
# signatures, digests, policy versions, parent and transition ids at will.
# Proof obligations are stated against THAT adversary, not against a
# bit-flipping outsider only.

from __future__ import annotations

from dataclasses import dataclass
from typing import Dict, Optional, Tuple

from Crypto.Hash import keccak as _keccak
from coincurve import PrivateKey, PublicKey

# ---------------------------------------------------------------------------
# primitives
# ---------------------------------------------------------------------------


def H(b: bytes) -> bytes:
    """Keccak256 (Ethereum flavor — same as K KRYPTO Keccak256/Keccak256raw)."""
    k = _keccak.new(digest_bits=256)
    k.update(b)
    return k.digest()


def i2b4(n: int) -> bytes:
    """Int2Bytes(4, n, BE) — the K side's I2B4."""
    return int(n).to_bytes(4, "big")


# ---------------------------------------------------------------------------
# canonical encodings (byte-identical contract with srw3lin.k)
# ---------------------------------------------------------------------------


def canon_slots(slots: Dict[int, int]) -> bytes:
    """LinCanonSlots: count4 || (slot4 || val4)*  in ascending slot order."""
    out = i2b4(len(slots))
    for s in sorted(slots):
        out += i2b4(s) + i2b4(slots[s])
    return out


def canon_kv(state: Dict[int, Dict[int, int]]) -> bytes:
    """LinCanonKV: appCount4 || (app4 || slotCount4 || (slot4 || val4)*)* ascending."""
    out = i2b4(len(state))
    for a in sorted(state):
        out += i2b4(a) + canon_slots(state[a])
    return out


def canon_appset(apps) -> bytes:
    """LinAppsCanon: count4 || app4* (ascending, deduplicated by construction)."""
    out = i2b4(len(apps))
    for a in apps:
        out += i2b4(a)
    return out


def apps_of_effects(effects: Dict[int, Dict[int, int]]) -> Tuple[int, ...]:
    """LinAppsOfMap: ascending app ids touched by the effects map."""
    return tuple(sorted(effects))


def flat(state: Dict[int, Dict[int, int]]) -> Dict[Tuple[int, int], int]:
    """Flatten app->slot->val into (app, slot) -> val."""
    return {(a, s): v for a, slots in state.items() for s, v in slots.items()}


def apply_effects(pre: Dict[int, Dict[int, int]],
                  effects: Dict[int, Dict[int, int]]) -> Dict[int, Dict[int, int]]:
    """Apply(PreState, Effects): per-slot overwrite, preserving untouched slots."""
    st: Dict[int, Dict[int, int]] = {a: dict(slots) for a, slots in pre.items()}
    for a, slots in effects.items():
        st.setdefault(a, {}).update(slots)
    return st


# ---------------------------------------------------------------------------
# the record
# ---------------------------------------------------------------------------


@dataclass(frozen=True)
class LinRec:
    version: int
    parent: bytes          # 32 bytes
    tid: int
    appset: Tuple[int, ...]
    input_d: bytes         # 32
    effect_d: bytes        # 32
    state_d: bytes         # 32
    policy_v: int
    authority: bytes       # 20
    evidence: bytes        # 65
    sig: bytes             # 65
    child: bytes           # 32


@dataclass(frozen=True)
class LinCtx:
    """The claimed artifacts that travel with the record."""
    pre_state: Dict[int, Dict[int, int]]       # declared inputs (pre-state)
    true_effects: Dict[int, Dict[int, int]]    # true effects of the transition
    presented_post: Dict[int, Dict[int, int]]  # presented post-state
    registry: Tuple[int, ...]                  # known policy versions
    auth_set: Tuple[bytes, ...]                # authority set (addresses)


def canon_core(rec: LinRec) -> bytes:
    """LinCanonCore — every content field except Signature and Child."""
    return (i2b4(rec.version) + rec.parent + i2b4(rec.tid)
            + canon_appset(rec.appset) + rec.input_d + rec.effect_d
            + rec.state_d + i2b4(rec.policy_v) + rec.authority
            + i2b4(len(rec.evidence)) + rec.evidence)


def canon_full(rec: LinRec) -> bytes:
    """LinCanonFull — CanonCore || SigLen4 || Sig (Child excluded)."""
    return canon_core(rec) + i2b4(len(rec.sig)) + rec.sig


def intent_hash(rec: LinRec) -> bytes:
    """LinIntentHash: the transition-outcome intent (what evidence commits to)."""
    return H(i2b4(rec.tid) + rec.input_d + rec.effect_d + rec.state_d)


def core_hash(rec: LinRec) -> bytes:
    """LinCoreHash: what the record signature commits to."""
    return H(canon_core(rec))


# ---------------------------------------------------------------------------
# signing side (mirror of LinBuildRec — used by the honest builder AND by the
# attack harness; the authorized-dishonest producer has exactly these powers)
# ---------------------------------------------------------------------------


def addr_of(sk: bytes) -> bytes:
    """LinAddrOf: Ethereum-style address = last 20 bytes of keccak(pubkey64)."""
    pub64 = PrivateKey(sk).public_key.format(compressed=False)[1:]
    return H(pub64)[-20:]


def _sign(msg: bytes, sk: bytes) -> bytes:
    """65-byte recoverable sig r||s||recid (libsecp256k1, RFC6979 nonces)."""
    return PrivateKey(sk).sign_recoverable(msg, hasher=None)


def build_rec(tid: int, head: bytes, pre, effects, post, sk: bytes,
              policy_v: int) -> LinRec:
    """LinBuildRec: honest record construction from a transition outcome.

    Digests bind the presented artifacts (pre-state / true effects / post);
    evidence signs the intent hash; signature signs the core hash; the child
    commitment covers all 11 non-child fields including the signature.
    """
    input_d = H(canon_kv(pre))
    effect_d = H(canon_kv(effects))
    state_d = H(canon_kv(post))
    auth = addr_of(sk)
    ev = _sign(H(i2b4(tid) + input_d + effect_d + state_d), sk)  # IntentHash
    appset = apps_of_effects(effects)
    tmp = LinRec(1, head, tid, appset, input_d, effect_d, state_d,
                 policy_v, auth, ev, b"", b"")
    sig = _sign(core_hash(tmp), sk)  # CoreHash (CanonCore excludes Sig/Child)
    tmp2 = LinRec(1, head, tid, appset, input_d, effect_d, state_d,
                  policy_v, auth, ev, sig, b"")
    child = H(canon_full(tmp2))  # CanonFull excludes Child only
    return LinRec(1, head, tid, appset, input_d, effect_d, state_d,
                  policy_v, auth, ev, sig, child)


# ---------------------------------------------------------------------------
# recover
# ---------------------------------------------------------------------------


def recover_addr(msg: bytes, sig: bytes) -> bytes:
    """LinRecoverAddr: address recovered from a 65-byte signature (or 0x0*20)."""
    if len(sig) != 65:
        return b"\x00" * 20
    try:
        pub = PublicKey.from_signature_and_message(sig, msg, hasher=None)
        return H(pub.format(compressed=False)[1:])[-20:]
    except Exception:
        return b"\x00" * 20


# ---------------------------------------------------------------------------
# the twelve-layer first-fail verification chain
# ---------------------------------------------------------------------------


def verify_lineage(rec: LinRec, ctx: LinCtx, tid: int, head: bytes) -> str:
    """Returns 'VALID' or the first failing layer code (L<i>-<FIELD>)."""

    def fail(code: str) -> str:
        return code

    # L1 — version
    if rec.version != 1:
        return fail("L1-VERSION")
    # L2 — transition id (chain position binding)
    if rec.tid != tid:
        return fail("L2-TID")
    # L3 — parent commitment (chain position binding)
    if rec.parent != head:
        return fail("L3-PARENT")
    # L4 — appset must be the ascending app ids of the TRUE effects
    if tuple(rec.appset) != apps_of_effects(ctx.true_effects):
        return fail("L4-APPSET")
    # L5 — input digest binds the declared inputs (pre-state)
    if rec.input_d != H(canon_kv(ctx.pre_state)):
        return fail("L5-INPUTDIGEST")
    # L6 — effect digest binds the TRUE effects
    if rec.effect_d != H(canon_kv(ctx.true_effects)):
        return fail("L6-EFFECTDIGEST")
    # L7 — STATE (see the frozen-defect notice at the top of this file)
    l7 = _layer_L7_state(rec, ctx)
    if l7 is not None:
        return fail(l7)
    # L8 — policy version must be known to the registry
    if rec.policy_v not in ctx.registry:
        return fail("L8-POLICYVERSION")
    # L9 — authority set membership (necessary, NEVER sufficient)
    if rec.authority not in ctx.auth_set:
        return fail("L9-AUTHORITY")
    # L10 — cryptographic authorization: evidence recovers to AuthorityId
    if rec.authority != recover_addr(intent_hash(rec), rec.evidence):
        return fail("L10-EVIDENCE")
    # L11 — record signature recovers to AuthorityId
    if rec.authority != recover_addr(core_hash(rec), rec.sig):
        return fail("L11-SIGNATURE")
    # L12 — child commitment covers all 11 non-child fields (incl. Sig)
    if rec.child != H(canon_full(rec)):
        return fail("L12-COMMITMENT")
    return "VALID"


def _layer_L7_state(rec: LinRec, ctx: LinCtx) -> Optional[str]:
    """L7 state layer — PRE-FIX BASELINE WITH THE FROZEN SUBSET DEFECT.

    (a) digest binding : stateD == H(Canon(PresentedPost))         [exact]
    (b) composition    : Composed == PreState o Effects, checked as
                         an ASYMMETRIC membership loop over Composed —
                         establishes Composed ⊆ Post, NOT Composed == Post.

    Returns None when the layer passes, else "L7-STATE".
    """
    presented = ctx.presented_post

    # (a) stateD commits to the presented post-state
    if rec.state_d != H(canon_kv(presented)):
        return "L7-STATE"

    # (b) every entry of Composed must appear in the presented post-state
    composed = apply_effects(ctx.pre_state, ctx.true_effects)
    flat_post = flat(presented)
    for key, val in flat(composed).items():
        if flat_post.get(key) != val:
            return "L7-STATE"

    # (c) R1 FROZEN DEFECT: the reverse direction is missing. Entries of the
    #     presented post-state that are NOT in Composed are never rejected.
    #     R1 Part II replaces this layer with canonical map equality
    #     (post_map == composed_map).
    return None
