#!/usr/bin/env python3
# =============================================================================
# SRW3 Phase 1E — authenticated-state verifier extension
#                                  (phase1e/python/auth_verify.py)
#
# Normative spec: phase1e/semantics/MODEL.md (FROZEN), §6/§7.
#
# VerifyLineageA(recE, ctxA, tid, head) — the Phase 1D-R1 twelve-layer chain
# runs UNCHANGED on the legacy projection; the extension layers follow:
#
#   L13 STATEROOT (Mode S) : stateRoot == AuthRoot(U, presentedPost)
#                            U = canonUnion(pre, eff, presentedPost)
#   L14 ANCHOR    (Mode A) : stateRoot == anchor
#   L15 CHILDE             : childE == Keccak256(CanonCoreE)
#   "valid"
#
# Additive discipline (linCtxP precedent): the frozen LinRec / verify_lineage
# are never modified. LinRecE wraps a legacy LinRec; the legacy child keeps
# its legacy semantics (over the legacy layout); childE extends the canonical
# bytes by the stateRoot suffix:
#     CanonCoreE = CanonCore(rec) || sigLen4 || sig || stateRoot
#     childE     = Keccak256(CanonCoreE)
#
# The anchor is an EXPLICIT context input (authCtxA.anchor) standing for an
# independently published authoritative state commitment. Its provenance is
# NOT established here (ASSUMED / REQUIRES CLIENT/PROTOCOL SUPPORT — §9).
#
# Verdicts: legacy verdicts (unchanged, fire first), then
#   L13-STATEROOT / L14-ANCHOR / L15-CHILDE / "VALID-A"
# ("VALID-A" = all twelve legacy layers AND all three extension layers pass;
#  distinguishable from a legacy-only "VALID".)
# =============================================================================

from __future__ import annotations

from dataclasses import dataclass
from typing import Dict, Optional, Tuple

from lin_verify import (LinRec, LinCtx, H, i2b4, canon_core, canon_full,
                        verify_lineage)
from auth_model import (auth_root, canon_union, check_universe)


# ---------------------------------------------------------------------------
# extended record / context (strictly additive wrappers)
# ---------------------------------------------------------------------------


@dataclass(frozen=True)
class LinRecE:
    """Extended record: the frozen legacy LinRec + the two extension fields."""
    rec: LinRec
    state_root: bytes      # 32 bytes
    child_e: bytes         # 32 bytes


@dataclass(frozen=True)
class AuthCtxA:
    """Extended context: the Phase 1D-R1 LinCtx + the authoritative anchor."""
    ctx: LinCtx
    anchor: bytes          # 32 bytes (authoritative state root)


def canon_core_e(rec: LinRec, state_root: bytes) -> bytes:
    """CanonCoreE = CanonCore || sigLen4 || sig || stateRoot (strict prefix rule)."""
    return canon_core(rec) + i2b4(len(rec.sig)) + rec.sig + state_root


def build_rec_e(base: LinRec, state_root: bytes, sk_signer=None) -> LinRecE:
    """Honest extended-record construction: childE over the extended bytes.
    (The legacy fields are already built by lin_verify.build_rec.)"""
    return LinRecE(base, state_root, H(canon_core_e(base, state_root)))


# ---------------------------------------------------------------------------
# the extended verification chain
# ---------------------------------------------------------------------------


def verify_lineage_a(recE: LinRecE, ctxA: AuthCtxA, tid: int, head: bytes) -> str:
    """Returns 'VALID-A' or the first failing verdict (legacy or extension)."""
    base = verify_lineage(recE.rec, ctxA.ctx, tid, head)   # legacy 12, unchanged
    if base != "VALID":
        return base

    ctx = ctxA.ctx
    presented = ctx.presented_post

    # L13 — STATEROOT (Mode S: self-computed root over the canonical universe)
    u = canon_union(ctx.pre_state, ctx.true_effects, presented)
    refuse = check_universe(u)                     # AUTH-CAPACITY / AUTH-PADKEY
    if refuse:
        return refuse
    if recE.state_root != auth_root(u, presented):
        return "L13-STATEROOT"

    # L14 — ANCHOR (Mode A: binding to the authoritative commitment)
    if recE.state_root != ctxA.anchor:
        return "L14-ANCHOR"

    # L15 — CHILDE (the extended child commitment covers sig + stateRoot)
    if recE.child_e != H(canon_core_e(recE.rec, recE.state_root)):
        return "L15-CHILDE"

    return "VALID-A"
