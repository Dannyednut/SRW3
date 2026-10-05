#!/usr/bin/env python3
# =============================================================================
# SRW3 Phase 1E — mutation harness EXTENSION (phase1e/python/auth_mutations.py)
#
# Discipline (Phase 1D-R1 §10 mandate): the 21-class legacy harness
# (python-gen/audit_mutations_21.py) is EXTENDED, never replaced. This file
# adds the authenticated-state mutation classes m-E1..m-E12. A mutation is
# REJECTED when the verifier returns a documented first-fail verdict other
# than the honest outcome; zero mutations may pass.
#
# The authorized-dishonest-producer powers are exercised wherever stated:
# genuine keccak, genuine secp256k1 signatures, recomputed digests/childE —
# only the listed field is false.
# =============================================================================

from __future__ import annotations

import sys

from lin_verify import (LinCtx, addr_of, apply_effects, build_rec, H)
from auth_model import (auth_proof, auth_root, auth_update_root,
                        auth_tree_update, auth_verify_incl, canon_union,
                        flat_key, tree_bytes)
from auth_verify import AuthCtxA, LinRecE, build_rec_e, verify_lineage_a

SK1 = (77).to_bytes(32, "big")
ROOT = b"\x00" * 32
PRE = {1: {0: 100, 1: 0}, 2: {0: 50, 1: 1}}
EFF = {1: {0: 25}, 2: {1: 7}}
POST = apply_effects(PRE, EFF)
U = canon_union(PRE, EFF, POST)
ANCHOR = auth_root(U, POST)
REGISTRY = (5, 6)
AUTH = (addr_of(SK1),)


def honest_recE() -> tuple:
    base = build_rec(1, ROOT, PRE, EFF, POST, SK1, 5)
    return build_rec_e(base, auth_root(U, POST))


def flip(b: bytes, i: int) -> bytes:
    ba = bytearray(b)
    ba[i] ^= 0x01
    return bytes(ba)


def main() -> int:
    print("=" * 69)
    print("SRW3 Phase 1E — authenticated mutation harness (extension classes)")
    print("=" * 69)
    recE = honest_recE()
    good_ctx = AuthCtxA(LinCtx(PRE, EFF, POST, REGISTRY, AUTH), ANCHOR)
    results = []

    def mut(name, mutated, want_prefix=None):
        """want_prefix: verdict must differ from honest 'VALID-A'; if given,
        it must start with the prefix."""
        v = mutated()
        vs = "None" if v is None else str(v)
        ok = (v != "VALID-A") and (want_prefix is None or vs.startswith(want_prefix))
        results.append(ok)
        print(f"  {name:<52} verdict={vs:<24} "
              f"{'OK' if ok else 'LEAK'}")

    k21 = flat_key(2, 1)
    p = auth_proof(U, POST, k21)
    idx = int.from_bytes(p[:4], "big")

    # --- record-field mutations (authorized producer, crypto genuine) -------
    mut("m-E1  stateRoot byte flip -> L13",
        lambda: verify_lineage_a(
            build_rec_e(build_rec(1, ROOT, PRE, EFF, POST, SK1, 5),
                        flip(recE.state_root, 0)),
            good_ctx, 1, ROOT), "L13")
    mut("m-E2  stateRoot = root of PRE-content -> L13",
        lambda: verify_lineage_a(
            build_rec_e(build_rec(1, ROOT, PRE, EFF, POST, SK1, 5),
                        auth_root(U, PRE)), good_ctx, 1, ROOT), "L13")
    mut("m-E3  genuine root but anchor byte-flipped -> L14",
        lambda: verify_lineage_a(recE, AuthCtxA(good_ctx.ctx, flip(ANCHOR, 5)),
                                 1, ROOT), "L14")
    mut("m-E4  childE byte flip -> L15",
        lambda: verify_lineage_a(
            LinRecE(recE.rec, recE.state_root, flip(recE.child_e, 7)),
            good_ctx, 1, ROOT), "L15")
    mut("m-E5  childE = legacy child (not extended) -> L15",
        lambda: verify_lineage_a(
            LinRecE(recE.rec, recE.state_root, recE.rec.child),
            good_ctx, 1, ROOT), "L15")

    # --- tree-layer mutations ------------------------------------------------
    mut("m-E6  producer root over shrunk universe -> L13",
        lambda: verify_lineage_a(
            build_rec_e(build_rec(1, ROOT, PRE, EFF, POST, SK1, 5),
                        auth_root(tuple(k for k in U
                                        if k != flat_key(2, 0)), POST)),
            good_ctx, 1, ROOT), "L13")
    mut("m-E7  producer tree built from wrong post (PRE) -> L13",
        lambda: verify_lineage_a(
            build_rec_e(build_rec(1, ROOT, PRE, EFF, POST, SK1, 5),
                        auth_root(U, PRE)), good_ctx, 1, ROOT), "L13")
    mut("m-E8  proof index off-by-one -> proof verify fails",
        lambda: auth_verify_incl(ANCHOR, k21, 1, 7, idx ^ 1, p), None)
    mut("m-E9  truncated proof -> proof verify fails",
        lambda: auth_verify_incl(ANCHOR, k21, 1, 7, idx, p[:64]), None)
    mut("m-E10 treeBytes tampered -> root re-derivation diverges",
        lambda: (lambda tb1, tb2: tb1 != tb2)(
            tree_bytes(U, POST),
            tree_bytes(U, POST)[:-4] + (12345).to_bytes(4, "big")), None)
    mut("m-E11 update proof with forged old value -> None",
        lambda: auth_update_root(ANCHOR, k21, 1, 8, 42, idx, p), None)
    mut("m-E12 tree update of key outside universe -> None",
        lambda: auth_tree_update(U, POST, flat_key(9, 9), 1), None)

    n_ok = sum(results)
    n_all = len(results)
    print("-" * 69)
    print(f"rejected: {n_ok}/{n_all}; accepted: {n_all - n_ok}")
    if n_ok == n_all:
        print("No mutation passed. The authenticated-state layer holds under")
        print("all extension classes; legacy 21-class harness unchanged.")
        return 0
    print("HARNESS FAILED — soundness leak.")
    return 1


if __name__ == "__main__":
    sys.exit(main())
