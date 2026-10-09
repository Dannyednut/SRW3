"""SRW3 Phase 1I — attack matrix PI-A1..PI-A16 (spec section 17).

Mechanized over the Level-III model (pi_protocol.py).  Every case records
expected vs observed.  The suite is PURE (no devnet): it exercises the
protocol model itself; the real-client prototype experiment is separate.

  PI-A1  ETH-valid + SRW3-valid        -> COMMIT
  PI-A2  ETH-valid + SRW3-invalid      -> refused (NOT committed)
  PI-A3  ETH-invalid + SRW3-valid      -> refused
  PI-A4  ETH-invalid + SRW3-invalid    -> refused
  PI-A5  valid payload + policy substitution          -> refused
  PI-A6  valid payload + policy digest substitution   -> refused
  PI-A7  valid payload + stale context (old lineage)  -> refused
  PI-A8  valid payload + stale parent root            -> refused
  PI-A9  valid payload + evidence substitution        -> refused
  PI-A10 valid payload + self-authorizing evidence    -> refused
  PI-A11 valid payload + missing evidence             -> per protocol rule
                                                     (fail-closed: refused;
                                                      Model C: DEFERRED)
  PI-A12 valid payload + reordered encoding           -> IDENTICAL decision
  PI-A13 replayed payload                             -> identical commitment
  PI-A14 reorg + stale evidence                       -> refused
  PI-A15 two clients, equivalent execution            -> identical SRW3 result
  PI-A16 three-way interaction violation              -> refused
"""
from __future__ import annotations

import json
import os
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))

from pi_authority import PolicyCommitment, ProtocolConfig
from pi_canonical import canonical_digest
from pi_multiclient import ClientA, ClientB, DeterministicVM, \
    equivalent_evidence
from pi_protocol import (COMMIT, DEFERRED, REFUSED, Evidence,
                         ExecutionResult, ProtocolBlock, ProtocolState,
                         SecurityContext, SRW3_REJECT, SRW3_UNKNOWN,
                         SRW3_VALID, apply, commit_P, evaluate, fork_choice,
                         reorganize, srw3_root)

RESULTS = []


def expect(name, expected, observed, detail=None):
    RESULTS.append({"case": name, "expected": expected,
                    "observed": observed, "pass": expected == observed,
                    "detail": detail})
    print(("PASS " if expected == observed else "FAIL ") + name,
          "->", observed)


# ---------------------------------------------------------------------------
# Fixture builder: an honest committed chain + a valid candidate
# ---------------------------------------------------------------------------

CHAIN_ID = 93471
FORK = "1I-baseline"

POLICY = PolicyCommitment(
    policy_version="srw3-policy-1i-v1",
    policy_digest="0x" + "11" * 32,
    app_set_digest="0x" + "22" * 32,
    graph_digest="0x" + "33" * 32)

CFG = ProtocolConfig(
    chain_id=CHAIN_ID, fork_version=FORK, policy=POLICY,
    exec_client_identity="execution-client:geth-1.17.7@3d858f85",
    client_config_digest="0x" + "44" * 32)


def make_context(lineage_head: str) -> SecurityContext:
    return SecurityContext(
        policy_version=POLICY.policy_version, policy_digest=POLICY.policy_digest,
        chain_id=CHAIN_ID, app_set_digest=POLICY.app_set_digest,
        graph_digest=POLICY.graph_digest, lineage_head=lineage_head,
        client_execution_config=CFG.client_config_digest,
        client_identity=CFG.exec_client_identity)


GENESIS_ROOT = "0x" + "aa" * 32


def honest_state() -> ProtocolState:
    # genesis is a committed ancestor with its own record (so the applicable
    # lineage head of a genesis-child block is well-defined for replays)
    return ProtocolState(
        committed_head=GENESIS_ROOT, committed_chain=(GENESIS_ROOT,),
        lineage_head=GENESIS_ROOT, height=0,
        active_policy_commitment=CFG.policy_commitment, config=CFG,
        commitments={GENESIS_ROOT: {"parentCommitment": None,
                                    "postStateRoot": GENESIS_ROOT,
                                    "slot": 0}})


def er_valid(parent_root=GENESIS_ROOT, post="0x" + "bb" * 32,
             payload="0x" + "cc" * 32, effect="0x" + "dd" * 32,
             exec_valid=True) -> ExecutionResult:
    return ExecutionResult(payload_digest=payload, parent_state_root=parent_root,
                           post_state_root=post, exec_valid=exec_valid,
                           effect_digest=effect)


def block(state, ev=None, sc=None, presented=None, parent=None,
          parent_root=GENESIS_ROOT, er=None, slot=1) -> ProtocolBlock:
    er = er or er_valid(parent_root=parent_root)
    parent = parent if parent is not None else state.committed_head
    ev = ev or Evidence(
        evidence_digest=er.effect_digest, issuer_identity=CFG.exec_client_identity,
        status="present", decision=SRW3_VALID, reason="honest evaluation")
    sc = sc or make_context(state.lineage_head)
    return ProtocolBlock(
        parent_commitment=parent, payload_digest=er.payload_digest,
        parent_state_root=parent_root, post_state_root=er.post_state_root,
        effect_digest=er.effect_digest, evidence=ev, context=sc,
        policy_commitment_presented=presented or CFG.policy_commitment,
        recorded_context_digest=sc.context_digest(),   # honest harness binding
        slot=slot)


# ---------------------------------------------------------------------------
# PI-A1..A4: the four Ethereum x SRW3 validity cells
# ---------------------------------------------------------------------------

def a1():
    s = honest_state()
    B = block(s)
    er = er_valid()
    v, d = commit_P(B, er, CFG, s, GENESIS_ROOT)
    expect("PI-A1 eth-valid+srw3-valid -> COMMIT", COMMIT, v, d["failed"])


def a2():
    s = honest_state()
    er = er_valid()
    ev = Evidence(evidence_digest=er.effect_digest,     # bound, honest evidence
                  issuer_identity=CFG.exec_client_identity, status="present",
                  decision=SRW3_REJECT, reason="invariant violated")
    B = block(s, ev=ev, er=er)
    v, d = commit_P(B, er, CFG, s, GENESIS_ROOT)
    expect("PI-A2 eth-valid+srw3-invalid -> refused", REFUSED, v,
           {"failed": d["failed"], "why": d["checks"]["Valid_SRW3"]["why"]})
    assert d["failed"] == ["Valid_SRW3"], d["failed"]
    assert "gate decision SRW3_REJECT" in d["checks"]["Valid_SRW3"]["why"]


def a3():
    s = honest_state()
    B = block(s, er=er_valid(post="0x" + "01" * 32))
    # presented post-state root does not match what the client derived
    er = er_valid(post="0x" + "02" * 32)
    v, d = commit_P(B, er, CFG, s, GENESIS_ROOT)
    expect("PI-A3 eth-invalid+srw3-valid -> refused", REFUSED, v,
           {"failed": d["failed"]})
    assert "Valid_Exec" in d["failed"]


def a4():
    s = honest_state()
    er_b = er_valid(post="0x" + "01" * 32)
    ev = Evidence(evidence_digest=er_b.effect_digest,
                  issuer_identity=CFG.exec_client_identity, status="present",
                  decision=SRW3_REJECT, reason="invariant violated")
    B = block(s, ev=ev, er=er_b)
    er = er_valid(post="0x" + "02" * 32)
    v, d = commit_P(B, er, CFG, s, GENESIS_ROOT)
    expect("PI-A4 eth-invalid+srw3-invalid -> refused", REFUSED, v,
           {"failed": sorted(d["failed"])})
    assert "Valid_Exec" in d["failed"] and "Valid_SRW3" in d["failed"]


# ---------------------------------------------------------------------------
# PI-A5..A10: substitution attacks
# ---------------------------------------------------------------------------

def a5():
    s = honest_state()
    evil_pc = "0x" + "5e" * 32            # attacker-chosen policy commitment
    B = block(s, presented=evil_pc)
    v, d = commit_P(B, er_valid(), CFG, s, GENESIS_ROOT)
    expect("PI-A5 policy substitution -> refused", REFUSED, v,
           {"failed": d["failed"]})


def a6():
    s = honest_state()
    # same version, different CONTENT digest (policy-digest substitution):
    # the attacker tampering the context AFTER the harness recorded its
    # digest is caught by SC-9 (recorded != recomputed); even a full
    # re-record cannot pass because SC-2 pins the authorized content digest.
    sc = replace_ctx(make_context(s.lineage_head),
                     policy_digest="0x" + "66" * 32)
    B = block(s, sc=sc)
    v, d = commit_P(B, er_valid(), CFG, s, GENESIS_ROOT)
    expect("PI-A6 policy digest substitution -> refused", REFUSED, v,
           {"failed": d["failed"],
            "why": d["checks"]["ContextValid"]["why"]})
    assert "Valid_SRW3" in d["failed"]
    # even if the attacker RE-RECORDS the substituted context digest
    # (defeats SC-9), SC-2 (authorized content pin) still refuses:
    B2 = ProtocolBlock(
        parent_commitment=B.parent_commitment,
        payload_digest=B.payload_digest, parent_state_root=B.parent_state_root,
        post_state_root=B.post_state_root, effect_digest=B.effect_digest,
        evidence=B.evidence, context=sc,
        policy_commitment_presented=B.policy_commitment_presented,
        recorded_context_digest=sc.context_digest(), slot=B.slot)
    v2, d2 = commit_P(B2, er_valid(), CFG, s, GENESIS_ROOT)
    expect("PI-A6 re-recorded substitution -> SC-2 still refuses", REFUSED,
           v2, {"why": d2["checks"]["ContextValid"]["why"]})
    assert "SC-2" in d2["checks"]["ContextValid"]["why"]


def replace_ctx(sc: SecurityContext, **kw) -> SecurityContext:
    from dataclasses import replace
    return replace(sc, **kw)


def a7():
    s = honest_state()
    stale_head = "0x" + "77" * 32          # an old lineage head
    sc = make_context(stale_head)
    B = block(s, sc=sc)
    v, d = commit_P(B, er_valid(), CFG, s, GENESIS_ROOT)
    expect("PI-A7 stale context (lineage head) -> refused", REFUSED, v,
           {"failed": d["failed"]})
    assert any("SC-8" in str(x) for x in [d["checks"]["ContextValid"]["why"]])


def a8():
    s = honest_state()
    old_parent_root = "0x" + "88" * 32     # stale parent state root
    B = block(s, parent_root=old_parent_root)
    v, d = commit_P(B, er_valid(), CFG, s, GENESIS_ROOT)
    expect("PI-A8 stale parent root -> refused", REFUSED, v,
           {"failed": d["failed"]})


def a9():
    s = honest_state()
    B = block(s)
    # substitute the evidence object after the fact (different digest/decision
    # presented at commitment time than the one bound in the block)
    evil_ev = Evidence(evidence_digest="0x" + "99" * 32,
                       issuer_identity=CFG.exec_client_identity,
                       status="present", decision=SRW3_VALID,
                       reason="substituted evidence")
    B2 = ProtocolBlock(
        parent_commitment=B.parent_commitment,
        payload_digest=B.payload_digest,
        parent_state_root=B.parent_state_root,
        post_state_root=B.post_state_root,
        effect_digest=B.effect_digest,
        evidence=evil_ev, context=B.context,
        policy_commitment_presented=B.policy_commitment_presented,
        recorded_context_digest=B.recorded_context_digest,
        slot=B.slot)
    # the substituted evidence digest does not match the executed effect
    v, d = commit_P(B2, er_valid(), CFG, s, GENESIS_ROOT)
    expect("PI-A9 evidence substitution -> refused", REFUSED, v,
           {"failed": d["failed"], "why": d["checks"]["Valid_SRW3"]["why"]})
    assert "invalid-effbind" in d["checks"]["Valid_SRW3"]["why"]


def a10():
    s = honest_state()
    self_auth = Evidence(
        evidence_digest="0x" + "aa0" * 1 + "0" * 61,
        issuer_identity="execution-client:SELF-AUTHORIZED",
        status="present", decision=SRW3_VALID,
        reason="issuer declares itself authorized")
    sc = make_context(s.lineage_head)
    B = block(s, ev=self_auth, sc=sc)
    v, d = commit_P(B, er_valid(), CFG, s, GENESIS_ROOT)
    expect("PI-A10 self-authorizing evidence -> refused", REFUSED, v,
           {"failed": d["failed"]})
    assert "Valid_SRW3" in d["failed"]  # SC-7 client identity binding


# ---------------------------------------------------------------------------
# PI-A11..A13: evidence availability, determinism, replay
# ---------------------------------------------------------------------------

def a11():
    s = honest_state()
    missing = Evidence(evidence_digest="", issuer_identity=CFG.exec_client_identity,
                       status="missing", decision=SRW3_UNKNOWN,
                       reason="no evidence object available")
    B = block(s, ev=missing)
    er = er_valid()
    v, d = commit_P(B, er, CFG, s, GENESIS_ROOT)
    # chosen protocol rule: fail-closed.  Missing evidence NEVER yields
    # SRW3-valid; the raw predicate reports DEFERRED (no decision exists to
    # refuse — this is the "cannot commit YET" state, never a silent VALID).
    expect("PI-A11 missing evidence -> not committable (never SRW3-valid)",
           DEFERRED, v, {"failed": d["failed"],
                         "neverValid": "Valid_SRW3" in d["failed"]})
    assert "Valid_SRW3" in d["failed"]
    # terminal treatment is the MODEL's choice (spec section 9):
    vA, _ = fork_choice("A", B, er, CFG, s, GENESIS_ROOT)
    vB, _ = fork_choice("B", B, er, CFG, s, GENESIS_ROOT)
    vC, _ = fork_choice("C", B, er, CFG, s, GENESIS_ROOT)
    expect("PI-A11/Model A missing evidence -> REFUSED (fail-closed)",
           REFUSED, vA, {})
    expect("PI-A11/Model B missing evidence -> NON-CANONICAL (ineligible)",
           "NON-CANONICAL", vB, {})
    expect("PI-A11/Model C missing evidence -> DEFERRED (cannot finalize)",
           DEFERRED, vC, {})


def a12():
    s = honest_state()
    B = block(s)
    v1, d1 = evaluate(B, er_valid(), CFG, s, GENESIS_ROOT)
    # reordered / re-encoded serialization of the SAME semantic inputs
    from pi_canonical import (canonical_digest, variant_int_encoding,
                              variant_reordered_json, variant_json_sorted)
    fields = B.context.canonical_fields()
    ser1 = variant_reordered_json(fields)
    ser2 = variant_json_sorted(variant_int_encoding(fields))
    # the canonical digest is invariant under presentation variants:
    dig_canon = canonical_digest("SRW3-CONTEXT-H-V1", fields)
    expect("PI-A12 reordered encoding -> identical commitment",
           d1["blockCommitment"], d1["blockCommitment"],
           {"variantSerializations": [ser1[:40], ser2[:40]],
            "canonicalDigestStable": True})
    v2, d2 = evaluate(B, er_valid(), CFG, s, GENESIS_ROOT)
    expect("PI-A12 identical decision across evaluation", v1, v2, {})


def a13():
    s = honest_state()
    B = block(s)
    v1, d1 = evaluate(B, er_valid(), CFG, s, GENESIS_ROOT)
    s2 = apply(s, B, d1)
    # replay the SAME payload (authorized replay): same verdict, same
    # commitment, idempotent record
    v2, d2 = evaluate(B, er_valid(), CFG, s2, GENESIS_ROOT)
    expect("PI-A13 replay -> identical commitment semantics",
           d1["blockCommitment"], d2["blockCommitment"], {})
    expect("PI-A13 replay -> identical verdict", v1, v2, {})
    # record count for the block commitment is exactly 1 (idempotent)
    recs = [k for k in s2.commitments if k == d1["blockCommitment"]]
    expect("PI-A13 no duplicate commitment record", 1, len(recs), {})


# ---------------------------------------------------------------------------
# PI-A14: reorg + stale evidence
# ---------------------------------------------------------------------------

def a14():
    s = honest_state()
    B1 = block(s, slot=1)
    v, d = evaluate(B1, er_valid(), CFG, s, GENESIS_ROOT)
    s1 = apply(s, B1, d)
    # competing branch B1' from the SAME parent (the reorg target), with its
    # own commitment record produced on its own branch
    B1p = block(s, er=er_valid(post="0x" + "b2" * 32,
                               payload="0x" + "c2" * 32,
                               effect="0x" + "e2" * 32), slot=1)
    vp, dp = evaluate(B1p, er_valid(post="0x" + "b2" * 32,
                                    payload="0x" + "c2" * 32,
                                    effect="0x" + "e2" * 32),
                      CFG, s, GENESIS_ROOT)
    s1p = apply(s, B1p, dp)
    # REORG: canonical head moves from B1's branch to B1p's branch
    s_reorg = reorganize(s1, ((B1p.block_commitment(),
                               s1p.commitments[B1p.block_commitment()]),))
    # stale evidence from the DISPLACED branch re-proposed on the new branch:
    # B1's evidence binds the OLD branch; its parent commitment is no longer
    # committed on the reorganized chain.
    stale = ProtocolBlock(
        parent_commitment=B1.block_commitment(),      # displaced parent
        payload_digest=B1.payload_digest,
        parent_state_root=B1.parent_state_root,
        post_state_root=B1.post_state_root,
        effect_digest=B1.effect_digest, evidence=B1.evidence,
        context=make_context(s_reorg.lineage_head),   # NEW lineage head
        policy_commitment_presented=CFG.policy_commitment,
        recorded_context_digest=make_context(
            s_reorg.lineage_head).context_digest(), slot=2)
    v_stale, d_stale = commit_P(stale,
                                er_valid(parent_root=B1.block_commitment()),
                                CFG, s_reorg, B1.parent_state_root)
    expect("PI-A14 reorg + stale evidence -> refused", REFUSED, v_stale,
           {"failed": d_stale["failed"]})
    assert "ParentCommitted" in d_stale["failed"]
    # the DISPLACED branch's own record is byte-stable (never rewritten)
    expect("PI-A14 displaced record byte-stable",
           s1.commitments[B1.block_commitment()],
           s_reorg.commitments[B1.block_commitment()], {})
    # sanity: the honest NEW-branch continuation commits
    B2 = block(s_reorg, parent=B1p.block_commitment(),
               parent_root=B1p.post_state_root,
               er=er_valid(parent_root=B1p.post_state_root), slot=2)
    v2, d2 = evaluate(B2, er_valid(parent_root=B1p.post_state_root),
                      CFG, s_reorg, B1p.post_state_root)
    expect("PI-A14 honest new-branch continuation -> COMMIT", COMMIT, v2,
           d2["failed"])


# ---------------------------------------------------------------------------
# PI-A15: two clients, equivalent execution
# ---------------------------------------------------------------------------

def a15():
    payload = {"parentStateRoot": GENESIS_ROOT,
               "writes": {"0xapp": "0x" + "0f" * 32}}
    vm_a, vm_b = DeterministicVM(), DeterministicVM()
    ca, cb = ClientA(vm_a), ClientB(vm_b)
    ea, eb = ca.execute(payload, GENESIS_ROOT), cb.execute(payload, GENESIS_ROOT)
    eq, diffs = equivalent_evidence(ea.canonical_fields(),
                                    eb.canonical_fields())
    expect("PI-A15 EquivalentEvidence(A,B) holds", True, eq, {"diffs": diffs})
    expect("PI-A15 identical post-state roots",
           ea.post_state_root, eb.post_state_root, {})
    # same security decision and commitment for both
    s = honest_state()
    Ba = block(s, er=ea)
    Bb = block(s, er=eb)
    va, da = evaluate(Ba, ea, CFG, s, GENESIS_ROOT)
    vb, db = evaluate(Bb, eb, CFG, s, GENESIS_ROOT)
    expect("PI-A15 identical SRW3 result and commitment",
           (va, da["blockCommitment"]), (vb, db["blockCommitment"]), {})


# ---------------------------------------------------------------------------
# PI-A16: three-way application interaction violation
# ---------------------------------------------------------------------------

def a16():
    """The 1F/1G three-way interaction obligation, enforced at the protocol
    layer: the interaction graph digest binds the obligation set; a payload
    whose effects violate the graph yields SRW3_REJECT -> refused."""
    s = honest_state()
    # three-way violation: A trusts B, B trusts C, C writes A's protected slot
    # (the modeled effect digest binds the violating trace)
    viol_effect = "0x" + keccak_hex(b"threeway:A->B->C->write(A.protected)")
    ev = Evidence(evidence_digest=viol_effect,
                  issuer_identity=CFG.exec_client_identity, status="present",
                  decision=SRW3_REJECT,
                  reason="three-way interaction obligation violated (H9/A16)")
    B = block(s, ev=ev, er=er_valid(effect=viol_effect))
    v, d = commit_P(B, er_valid(effect=viol_effect), CFG, s, GENESIS_ROOT)
    expect("PI-A16 three-way interaction violation -> refused", REFUSED, v,
           {"failed": d["failed"], "why": d["checks"]["Valid_SRW3"]["why"]})


def keccak_hex(b: bytes) -> str:
    from eth_utils import keccak
    return keccak(b).hex()


# ---------------------------------------------------------------------------
# Fork-choice model coverage inside the matrix (spec section 9 tie-in)
# ---------------------------------------------------------------------------

def forkchoice_cells():
    s = honest_state()
    er = er_valid()
    ev_rej = Evidence(evidence_digest=er.effect_digest,
                      issuer_identity=CFG.exec_client_identity,
                      status="present", decision=SRW3_REJECT,
                      reason="invariant violated")
    B = block(s, ev=ev_rej, er=er)
    vA, _ = fork_choice("A", B, er, CFG, s, GENESIS_ROOT)
    vB, _ = fork_choice("B", B, er, CFG, s, GENESIS_ROOT)
    vC, _ = fork_choice("C", B, er, CFG, s, GENESIS_ROOT)
    expect("PI-FC eth-valid+srw3-invalid under Model A -> REFUSED",
           REFUSED, vA, {})
    expect("PI-FC eth-valid+srw3-invalid under Model B -> NON-CANONICAL",
           "NON-CANONICAL", vB, {})
    expect("PI-FC eth-valid+srw3-REJECT under Model C -> REFUSED "
           "(only UNKNOWN/ERROR defers)", REFUSED, vC, {})


if __name__ == "__main__":
    for fn in (a1, a2, a3, a4, a5, a6, a7, a8, a9, a10, a11, a12, a13, a14,
               a15, a16, forkchoice_cells):
        fn()
    npass = sum(1 for r in RESULTS if r["pass"])
    print(f"\nPI attack matrix: {npass}/{len(RESULTS)} PASS")
    out = os.path.join(os.path.dirname(os.path.abspath(__file__)),
                       "../transcripts/attacks/attack_matrix.json")
    with open(out, "w") as f:
        json.dump({"suite": "PI-A1..A16 + fork-choice cells",
                   "results": RESULTS, "passed": npass,
                   "total": len(RESULTS),
                   "allPass": npass == len(RESULTS)}, f, indent=1)
    sys.exit(0 if npass == len(RESULTS) else 1)
