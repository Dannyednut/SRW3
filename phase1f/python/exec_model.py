#!/usr/bin/env python3
"""SRW3 Phase 1F — execution-effect binding model (Python mirror).

Faithful mirror of phase1f/semantics/srw3exec.k (module SRW3EXEC) and the
normative spec phase1f/semantics/MODEL.md. The frozen layers are imported
unchanged: lin_verify (Phase 1D-R1 legacy chain) and auth_verify (Phase 1E
Level-2 chain). This module adds ONLY the Level-3 extension:

  * effect-trace vocabulary + fragment bounds          (MODEL.md §2)
  * canonical order-preserving trace encoding          (MODEL.md §3)
  * execution identity (payload/env/config/execId)     (MODEL.md §4)
  * execution witness                                  (MODEL.md §5)
  * trace semantics: writes / replay / reads / proj    (MODEL.md §6)
  * LinRecF additive record + CanonCoreF + childF      (MODEL.md §7)
  * VerifyLineageF first-fail gate (14 conjuncts)      (MODEL.md §8)

All digests are keccak256 (pycryptodome), byte-identical to the K layer's
LinH/Keccak256raw over the same preimages.
"""
from __future__ import annotations

import sys
from dataclasses import dataclass
from typing import Dict, List, Optional, Tuple

from Crypto.Hash import keccak as _keccak

sys.path.insert(0, "/home/z/my-project/srw3-kevm/python-gen")
sys.path.insert(0, "/home/z/my-project/srw3-kevm/phase1e/python")
from lin_verify import (H, LinCtx, LinRec, addr_of, build_rec, canon_kv,
                        i2b4, verify_lineage)  # noqa: E402
from auth_verify import AuthCtxA, LinRecE, canon_core_e, verify_lineage_a  # noqa: E402


def i2b8(n: int) -> bytes:
    """8-byte big-endian (ExecI2B8). Out-of-fragment values are truncated to
    the low 8 bytes (matching K's Int2Bytes on oversized arguments); such
    traces are refused by L16-EXECBOUNDS before any digest is consulted."""
    return (int(n) % (1 << 64)).to_bytes(8, "big")


def i2b1(n: int) -> bytes:
    return (int(n) % (1 << 8)).to_bytes(1, "big")


def _i2b4w(n: int) -> bytes:
    """Width-4 encoding with K-compatible truncation for out-of-bounds
    values (used only on traces the gate refuses; the legacy i2b4 raises)."""
    return (int(n) % (1 << 32)).to_bytes(4, "big")


# =============================================================================
# §2 Effect-trace vocabulary and fragment bounds
# =============================================================================

OP_READ, OP_WRITE, OP_CALL, OP_RETURN = 1, 2, 3, 4

TWO32 = 4294967296
TWO64 = 18446744073709551616


@dataclass(frozen=True)
class ExEvt:
    """exEvt(op, app, a1, a2) — Read/Write: (slot, value);
    Call: (target, value); Return: (offset, size)."""
    op: int
    app: int
    a1: int
    a2: int


def evt_bounds_ok(e: ExEvt) -> bool:
    slot_ok = (0 <= e.a1 < TWO32) if e.op in (OP_READ, OP_WRITE) \
        else (0 <= e.a1 < TWO64)
    return (e.op in (OP_READ, OP_WRITE, OP_CALL, OP_RETURN)
            and 0 <= e.app < TWO32 and slot_ok and 0 <= e.a2 < TWO64)


def bounds_ok(trace: List[ExEvt]) -> bool:
    return all(evt_bounds_ok(e) for e in trace)


# =============================================================================
# §3 Canonical order-preserving trace encoding
# =============================================================================

def evt_bytes(e: ExEvt) -> bytes:
    return i2b1(e.op) + _i2b4w(e.app) + i2b8(e.a1) + i2b8(e.a2)


def events_bytes(trace: List[ExEvt]) -> bytes:
    return b"".join(evt_bytes(e) for e in trace)


def canon_trace(trace: List[ExEvt]) -> bytes:
    """0x03 ‖ n4 ‖ EventBytes* — EXACT trace order, no sorting, no dedup."""
    return i2b1(3) + i2b4(len(trace)) + events_bytes(trace)


def trace_digest(trace: List[ExEvt]) -> bytes:
    return H(canon_trace(trace))


# =============================================================================
# §4 Execution identity
# =============================================================================

def payload_digest(payload: bytes) -> bytes:
    return H(i2b1(0x11) + payload)


def env_digest(caller: bytes, value: int) -> bytes:
    return H(i2b1(0x12) + caller + i2b8(value))


def config_digest(schedule: bytes, spec: int) -> bytes:
    return H(i2b1(0x13) + schedule + i2b4(spec))


def exec_id(parent_root: bytes, pld: bytes, cfg: bytes, env: bytes) -> bytes:
    return H(i2b1(0x1F) + parent_root + pld + cfg + env)


# fragment schedule constant: ASCII "CANCUN" zero-padded to 8 bytes
SCHED_CANCUN = b"CANCUN" + b"\x00\x00"
SPEC_V1 = 1


# =============================================================================
# §5 Execution witness
# =============================================================================

@dataclass(frozen=True)
class ExecWit:
    version: int
    parent_root: bytes
    exec_id: bytes
    payload_d: bytes
    declared_d: bytes
    trace_d: bytes
    post_root: bytes
    config_d: bytes


def wit_canon(w: ExecWit) -> bytes:
    return (i2b1(0x57) + i2b4(w.version) + w.parent_root + w.exec_id
            + w.payload_d + w.declared_d + w.trace_d + w.post_root
            + w.config_d)


def wit_digest(w: ExecWit) -> bytes:
    return H(wit_canon(w))


# =============================================================================
# §6 Trace semantics: writes / replay / reads / projection / declared
# =============================================================================

def trace_writes(trace: List[ExEvt]) -> Dict[int, Dict[int, int]]:
    """ExecTraceWrites — last write wins; other events state-silent."""
    out: Dict[int, Dict[int, int]] = {}
    for e in trace:
        if e.op == OP_WRITE:
            out.setdefault(e.app, {})[e.a1] = e.a2
    return out


def replay_map(trace: List[ExEvt], pre: Dict[int, Dict[int, int]]):
    """ExecReplayMap — the write-accumulating walk (returns a fresh map)."""
    import copy
    w = copy.deepcopy(pre)
    for e in trace:
        if e.op == OP_WRITE:
            w.setdefault(e.app, {})[e.a1] = e.a2
    return w


def reads_ok(trace: List[ExEvt], pre: Dict[int, Dict[int, int]]) -> bool:
    """ExecReadsOk — every read observation matches the replayed state."""
    import copy
    w = copy.deepcopy(pre)
    for e in trace:
        if e.op == OP_READ:
            if w.get(e.app, {}).get(e.a1, 0) != e.a2:
                return False
        elif e.op == OP_WRITE:
            w.setdefault(e.app, {})[e.a1] = e.a2
    return True


def replay_ok(pre, trace, post) -> bool:
    """ExecReplayOk — read consistency ∧ canonical post equality."""
    return reads_ok(trace, pre) and canon_kv(post) == canon_kv(replay_map(trace, pre))


def declared_ok(declared: Dict[int, Dict[int, int]], trace: List[ExEvt]) -> bool:
    """ExecDeclaredOk — THE LEVEL-3 CORE CHECK:
    H(canon(declared)) == H(canon(Writes(trace)))."""
    return H(canon_kv(declared)) == H(canon_kv(trace_writes(trace)))


def proj(trace: List[ExEvt]) -> List[ExEvt]:
    """ExecProj (π_P) — reads dropped, Write/Call/Return kept in order."""
    return [e for e in trace if e.op != OP_READ]


# =============================================================================
# §7 LinRecF additive record
# =============================================================================

@dataclass(frozen=True)
class LinRecF:
    base: LinRecE          # the Phase 1E record (LinRec + stateRoot + childE)
    exec_id: bytes
    eff_trace_d: bytes
    exec_wd: bytes
    exec_cfg_d: bytes


def canon_core_f(recf: LinRecF) -> bytes:
    """CanonCoreF = CanonCoreE ‖ execId ‖ effTraceD ‖ execWD ‖ execCfgD
    (CanonCoreE is a strict PREFIX)."""
    return (canon_core_e(recf.base.rec, recf.base.state_root)
            + recf.exec_id + recf.eff_trace_d + recf.exec_wd
            + recf.exec_cfg_d)


def child_f(recf: LinRecF) -> bytes:
    return H(canon_core_f(recf))


# =============================================================================
# §8 ExecCtx and the VerifyLineageF first-fail gate
# =============================================================================

@dataclass(frozen=True)
class ExecCtx:
    ctxa: AuthCtxA        # the Phase 1E context (incl. anchor)
    parent_root: bytes    # threaded parent state root
    payload: bytes
    schedule: bytes
    spec: int
    caller: bytes
    value: int
    trace: List[ExEvt]    # the PRESENTED ordered trace
    witness: ExecWit      # the PRESENTED witness


def build_rec_f(tid: int, head: bytes, pre, effects, post, sk: bytes, pv: int,
                trace: List[ExEvt], payload: bytes, schedule: bytes, spec: int,
                caller: bytes, value: int, parent_root: bytes) -> LinRecF:
    """ExecBuildRecF — honest construction (delegates the base to the 1E
    builder; computes the Level-3 fields exactly as srw3exec.k does)."""
    base = build_rec_e_wrap(tid, head, pre, effects, post, sk, pv)
    eid = exec_id(parent_root, payload_digest(payload),
                  config_digest(schedule, spec), env_digest(caller, value))
    td = trace_digest(trace)
    cfgd = config_digest(schedule, spec)
    wit = ExecWit(1, parent_root, eid, payload_digest(payload),
                  H(canon_kv(effects)), td, base.state_root, cfgd)
    return LinRecF(base, eid, td, wit_digest(wit), cfgd)


def build_rec_e_wrap(tid, head, pre, effects, post, sk, pv) -> LinRecE:
    """The 1E AuthBuildRecE mirror (state root over the canonical universe)."""
    from auth_model import auth_root, canon_union
    rec = build_rec(tid, head, pre, effects, post, sk, pv)
    u = canon_union(pre, effects, post)
    sr = auth_root(u, post)
    from auth_verify import build_rec_e
    return build_rec_e(rec, sr)


def verify_lineage_f(recf: LinRecF, ctx: ExecCtx, tid: int, head: bytes) -> str:
    """VerifyLineageF — first-fail; every frozen layer fires first.
    Verdict codes continue the L-numbering (L16..L21) after the 1E chain."""
    # Layers 1-7 (frozen): legacy 12 + composition + capacity/padkey +
    # state-root + anchor + childe (verify_lineage_a)
    base = verify_lineage_a(recf.base, ctx.ctxa, tid, head)
    if base != "VALID-A":
        return base

    # L16 — EXECBOUNDS (model REFUSE, explicit)
    if not bounds_ok(ctx.trace):
        return "L16-EXECBOUNDS"

    # L17 — EXECCONFIG
    if recf.exec_cfg_d != config_digest(ctx.schedule, ctx.spec):
        return "L17-EXECCONFIG"

    # L18 — EXECID (recomputation over the threaded context)
    if recf.exec_id != exec_id(ctx.parent_root, payload_digest(ctx.payload),
                               config_digest(ctx.schedule, ctx.spec),
                               env_digest(ctx.caller, ctx.value)):
        return "L18-EXECID"

    # L19 — EFFTRACE (presented-trace digest binding)
    if recf.eff_trace_d != trace_digest(ctx.trace):
        return "L19-EFFTRACE"

    # L20 — EFFDECL (THE LEVEL-3 CORE CHECK)
    declared = ctx.ctxa.ctx.true_effects
    if not declared_ok(declared, ctx.trace):
        return "L20-EFFDECL"

    # L21 — WITNESS (digest + coherence)
    w = ctx.witness
    coherent = (w.version == 1
                and wit_digest(w) == recf.exec_wd
                and w.parent_root == ctx.parent_root
                and w.exec_id == recf.exec_id
                and w.payload_d == payload_digest(ctx.payload)
                and w.declared_d == H(canon_kv(declared))
                and w.trace_d == recf.eff_trace_d
                and w.post_root == recf.base.state_root
                and w.config_d == config_digest(ctx.schedule, ctx.spec))
    if not coherent:
        return "L21-WITNESS"

    # L22 — EFFBIND (replay: read observations + exact composition)
    if not replay_ok(ctx.ctxa.ctx.pre_state, ctx.trace, ctx.ctxa.ctx.presented_post):
        return "L22-EFFBIND"

    return "VALID-F"
