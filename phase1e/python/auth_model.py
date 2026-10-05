#!/usr/bin/env python3
# =============================================================================
# SRW3 Phase 1E — reference authenticated-state model (phase1e/python/auth_model.py)
#
# Normative spec: phase1e/semantics/MODEL.md (FROZEN).
# This module is the Python reference implementation of the minimal
# authenticated-state model: a fixed-depth (D=8, 256-leaf) binary Merkle tree
# over the canonical key universe of an SRW3 record, with content-binding
# inclusion/non-membership proofs and proof-based updates.
#
# Layers provided (mirrored 1:1 by the K side, k/phase1e/srw3auth.k):
#   canon_union(pre, eff, post)   -> sorted flattened key universe U
#   tree_bytes(U, post)           -> full canonical tree byte string (injective)
#   auth_root(U, post)            -> 32-byte Merkle root (also: leaf/node hashes)
#   auth_proof(U, post, k)        -> 260-byte content-binding proof
#   auth_verify_incl(R, k, pres, v, idx, proof) -> Bool
#   auth_update_root(R, k, old, new, idx, proof) -> new 32-byte root (or None)
#   auth_tree_update(U, post, k, v) -> new root from the producer-side tree
#
# Encoding contract (byte-exact across Python / K / KEVM):
#   leafBytes(k, pres, v) = 0x00 || i2b4(app) || i2b4(slot) || pres || i2b4(v)
#   nodeBytes(l, r)       = 0x01 || l || r
#   treeBytes             = 0x02 || i2b4(8) || i2b4(|U|) || leafBytes*256
#   proof                 = i2b4(index) || sib[0..7] (each 32 bytes)
#   REFUSE codes: AUTH-CAPACITY (|U| > 256), AUTH-PADKEY (real key == PAD)
# =============================================================================

from __future__ import annotations

from typing import Dict, Optional, Tuple

from Crypto.Hash import keccak as _keccak

DEPTH = 8
NLEAVES = 1 << DEPTH            # 256
CAPACITY = NLEAVES              # universe capacity
PAD_KEY = (0xFFFFFFFF << 32) | 0xFFFFFFFF   # reserved pad key


def H(b: bytes) -> bytes:
    """Keccak256 (Ethereum flavor)."""
    k = _keccak.new(digest_bits=256)
    k.update(b)
    return k.digest()


def i2b4(n: int) -> bytes:
    return int(n).to_bytes(4, "big")


# ---------------------------------------------------------------------------
# keys / universe
# ---------------------------------------------------------------------------


def flat_key(app: int, slot: int) -> int:
    return (app << 32) | slot


def key_app(k: int) -> int:
    return k >> 32


def key_slot(k: int) -> int:
    return k & 0xFFFFFFFF


def flat(state: Dict[int, Dict[int, int]]) -> Dict[Tuple[int, int], int]:
    return {(a, s): v for a, slots in state.items() for s, v in slots.items()}


def flat_int(state: Dict[int, Dict[int, int]]) -> Dict[int, int]:
    """Flatten to Int (flattened) keys — the leaf-addressing form."""
    return {flat_key(a, s): v for a, slots in state.items() for s, v in slots.items()}


def canon_union(pre: Dict[int, Dict[int, int]],
                eff: Dict[int, Dict[int, int]],
                post: Dict[int, Dict[int, int]]) -> Tuple[int, ...]:
    """U = sort( keys(pre) ∪ keys(eff) ∪ keys(post) ), flattened Int keys."""
    ks = set()
    for m in (pre, eff, post):
        for a, slots in m.items():
            for s in slots:
                ks.add(flat_key(a, s))
    return tuple(sorted(ks))


def check_universe(U: Tuple[int, ...]) -> Optional[str]:
    """Model REFUSE checks (never silent)."""
    if len(U) > CAPACITY:
        return "AUTH-CAPACITY"
    for k in U:
        if k == PAD_KEY:
            return "AUTH-PADKEY"
    return None


# ---------------------------------------------------------------------------
# encodings
# ---------------------------------------------------------------------------


def leaf_bytes(k: int, pres: int, v: int) -> bytes:
    return (b"\x00" + i2b4(key_app(k)) + i2b4(key_slot(k))
            + bytes([pres]) + i2b4(v))


def node_bytes(l: bytes, r: bytes) -> bytes:
    return b"\x01" + l + r


def leaf_hash(k: int, pres: int, v: int) -> bytes:
    return H(leaf_bytes(k, pres, v))


def node_hash(l: bytes, r: bytes) -> bytes:
    return H(node_bytes(l, r))


def tree_bytes(U: Tuple[int, ...], post: Dict[int, Dict[int, int]]) -> bytes:
    """Full canonical tree byte string (injective representation)."""
    refuse = check_universe(U)
    if refuse:
        raise ValueError(refuse)
    fmap = flat_int(post)
    out = b"\x02" + i2b4(DEPTH) + i2b4(len(U))
    for i in range(NLEAVES):
        if i < len(U):
            k = U[i]
            if k in fmap:
                out += leaf_bytes(k, 1, fmap[k])
            else:
                out += leaf_bytes(k, 0, 0)
        else:
            out += leaf_bytes(PAD_KEY, 0, 0)
    return out


# ---------------------------------------------------------------------------
# tree / root / proofs
# ---------------------------------------------------------------------------


def build_levels(U: Tuple[int, ...],
                 post: Dict[int, Dict[int, int]]) -> Tuple[list, list]:
    """Returns (leafContents, levels) where leafContents[i] = (k, pres, v)
    and levels[0] = leaf hashes (256), levels[d] = 256>>d node hashes."""
    refuse = check_universe(U)
    if refuse:
        raise ValueError(refuse)
    fmap = flat_int(post)
    leaves = []
    for i in range(NLEAVES):
        if i < len(U):
            k = U[i]
            if k in fmap:
                leaves.append((k, 1, fmap[k]))
            else:
                leaves.append((k, 0, 0))
        else:
            leaves.append((PAD_KEY, 0, 0))
    lvl = [leaf_hash(k, p, v) for (k, p, v) in leaves]
    levels = [lvl]
    d = 0
    while len(levels[-1]) > 1:
        prev = levels[-1]
        nxt = []
        for i in range(0, len(prev), 2):
            nxt.append(node_hash(prev[i], prev[i + 1]))
        levels.append(nxt)
        d += 1
    return leaves, levels


def auth_root(U: Tuple[int, ...], post: Dict[int, Dict[int, int]]) -> bytes:
    _, levels = build_levels(U, post)
    return levels[-1][0]


def auth_proof(U: Tuple[int, ...],
               post: Dict[int, Dict[int, int]],
               k: int) -> Optional[bytes]:
    """Content-binding proof for key k (260 bytes) or None if k ∉ U."""
    leaves, levels = build_levels(U, post)
    idx = None
    for i, (lk, _, _) in enumerate(leaves):
        if lk == k:
            idx = i
            break
    if idx is None:
        return None
    sibs = []
    i = idx
    for d in range(DEPTH):
        lvl = levels[d]
        sib = lvl[i ^ 1]
        sibs.append(sib)
        i >>= 1
    return i2b4(idx) + b"".join(sibs)


def auth_verify_incl(R: bytes, k: int, pres: int, v: int,
                     idx: int, proof: bytes) -> bool:
    """Recompute the root from the claimed leaf content + sibling path."""
    if len(proof) != 4 + 32 * DEPTH:
        return False
    if idx >= NLEAVES or pres not in (0, 1):
        return False
    if pres == 0 and v != 0:
        return False
    sibs = [proof[4 + 32 * d:36 + 32 * d] for d in range(DEPTH)]
    h = leaf_hash(k, pres, v)
    i = idx
    for d in range(DEPTH):
        if i & 1:
            h = node_hash(sibs[d], h)
        else:
            h = node_hash(h, sibs[d])
        i >>= 1
    return h == R


def auth_tree_update(U: Tuple[int, ...],
                     post: Dict[int, Dict[int, int]],
                     k: int, v: int) -> Optional[bytes]:
    """Producer-side update: recompute the root from the updated tree.
    Returns None if k ∉ U (cannot update an unknown key's leaf)."""
    newpost = {a: dict(s) for a, s in post.items()}
    a, s = key_app(k), key_slot(k)
    if (a, s) in flat(post):
        newpost[a][s] = v
    elif k in U:
        newpost.setdefault(a, {})[s] = v
    else:
        return None
    return auth_root(U, newpost)


def auth_update_root(R: bytes, k: int, old_pres: int, old_v: int,
                     new_v: int, idx: int, proof: bytes) -> Optional[bytes]:
    """Verifier-side proof-based update: re-derive old root (must equal R),
    then re-derive the new root from the same siblings + new value.
    Returns the new root, or None when the old-root check fails."""
    if not auth_verify_incl(R, k, old_pres, old_v, idx, proof):
        return None
    if len(proof) != 4 + 32 * DEPTH:
        return None
    sibs = [proof[4 + 32 * d:36 + 32 * d] for d in range(DEPTH)]
    pres = 1
    h = leaf_hash(k, pres, new_v)
    i = idx
    for d in range(DEPTH):
        if i & 1:
            h = node_hash(sibs[d], h)
        else:
            h = node_hash(h, sibs[d])
        i >>= 1
    return h
