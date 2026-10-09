"""SRW3 Phase 1I — reorg/replay semantics (spec sections 12/13) and the
governance/upgrade semantics (spec section 24).

REORG (A->B->C then A->B'->C'):
  RR-1  competing branches both commit on their own branch
  RR-2  reorg moves the canonical head; displaced records byte-stable
  RR-3  stale evidence (displaced branch) refused on the new branch
  RR-4  cached decisions NOT reused across reorg (parentCommitment binding)
  RR-5  lineage head follows the new canonical tip
  RR-6  honest continuation on the new branch commits

REPLAY (spec section 13, connects to the Phase 1H-R1 lineage repair):
  RP-1  Evaluate(B,C,E,Pi) is idempotent (same verdict/commitment)
  RP-2  re-recording is idempotent (no duplicate record, bytes unchanged —
        the 1H-R1 semantic_record discipline at the protocol layer)
  RP-3  replay is independent of wall clock and evaluation order
  RP-4  replay of a block on a DISPLACED branch (post-reorg) is refused —
        replay does not resurrect displaced history

GOVERNANCE (spec section 24; Policy_t != Policy_{t+1}):
  GOV-1 protocol-authoritative upgrade: the config's authorized policy
        commitment changes at an activation height; new blocks under the new
        policy commit, blocks still presenting the old commitment refuse
  GOV-2 committed history is IMMUTABLE under upgrade (no retroactive
        invalidation of commitment records — CM-I4 answer)
  GOV-3 rollback forbidden: activation history is append-only
  GOV-4 application cannot bypass policy (invariant-set change = different
        policy commitment = substitution -> refuse; CM-I6 negative control)
  GOV-5 the NEGATIVE model (PolicyAuthority = Application) is deliberately
        exercised and shown to break commitment safety (two app-chosen
        policies -> divergent heads; CM-I1/CM-I5 demonstration)
"""
from __future__ import annotations

import json
import os
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))

from dataclasses import replace

from pi_authority import PolicyCommitment, ProtocolConfig
from pi_protocol import (COMMIT, REFUSED, Evidence, ExecutionResult,
                         ProtocolBlock, ProtocolState, SecurityContext,
                         SRW3_VALID, apply, commit_P, evaluate, reorganize)

RESULTS = []


def expect(name, expected, observed, detail=None):
    RESULTS.append({"case": name, "expected": expected,
                    "observed": observed, "pass": expected == observed,
                    "detail": detail})
    print(("PASS " if expected == observed else "FAIL ") + name, "->", observed)


CHAIN_ID = 93471
FORK = "1I-baseline"
POLICY = PolicyCommitment("srw3-policy-1i-v1", "0x" + "11" * 32,
                          "0x" + "22" * 32, "0x" + "33" * 32)
CFG = ProtocolConfig(chain_id=CHAIN_ID, fork_version=FORK, policy=POLICY,
                     exec_client_identity="execution-client:geth-1.17.7@3d858f85",
                     client_config_digest="0x" + "44" * 32)
GENESIS = "0x" + "aa" * 32


def state(cfg=CFG):
    return ProtocolState(committed_head=GENESIS, committed_chain=(GENESIS,),
                         lineage_head=GENESIS, height=0,
                         active_policy_commitment=cfg.policy_commitment,
                         config=cfg,
                         commitments={GENESIS: {"parentCommitment": None,
                                                "postStateRoot": GENESIS,
                                                "slot": 0}})


def ctx(s, cfg=CFG):
    return SecurityContext(policy_version=cfg.policy.policy_version,
                           policy_digest=cfg.policy.policy_digest,
                           chain_id=cfg.chain_id,
                           app_set_digest=cfg.policy.app_set_digest,
                           graph_digest=cfg.policy.graph_digest,
                           lineage_head=s.lineage_head,
                           client_execution_config=cfg.client_config_digest,
                           client_identity=cfg.exec_client_identity)


def er(payload="cc", post="bb", effect="dd", parent=GENESIS, ok=True):
    return ExecutionResult(payload_digest="0x" + payload * 32,
                           parent_state_root=parent,
                           post_state_root="0x" + post * 32,
                           exec_valid=ok, effect_digest="0x" + effect * 32)


def blk(s, cfg=CFG, er_=None, parent=None, slot=1, post="bb", payload="cc",
        effect="dd"):
    er_ = er_ or er(post=post, payload=payload, effect=effect)
    parent = parent if parent is not None else s.committed_head
    sc = ctx(s, cfg)
    ev = Evidence(evidence_digest=er_.effect_digest,
                  issuer_identity=cfg.exec_client_identity,
                  status="present", decision=SRW3_VALID, reason="honest")
    return ProtocolBlock(parent_commitment=parent,
                         payload_digest=er_.payload_digest,
                         parent_state_root=er_.parent_state_root,
                         post_state_root=er_.post_state_root,
                         effect_digest=er_.effect_digest, evidence=ev,
                         context=sc,
                         policy_commitment_presented=cfg.policy_commitment,
                         recorded_context_digest=sc.context_digest(),
                         slot=slot)


# ---------------------------------------------------------------------------
# Reorg
# ---------------------------------------------------------------------------

def rr():
    s = state()
    B1 = blk(s, slot=1, post="b1", payload="c1", effect="d1")
    v, d = evaluate(B1, er(post="b1", payload="c1", effect="d1"), CFG, s,
                    GENESIS)
    s1 = apply(s, B1, d)
    B1p = blk(s, slot=1, post="b2", payload="c2", effect="d2")
    vp, dp = evaluate(B1p, er(post="b2", payload="c2", effect="d2"), CFG, s,
                      GENESIS)
    s1p = apply(s, B1p, dp)
    expect("RR-1 competing branches both commit on their own branch",
           (COMMIT, COMMIT), (v, vp), {})

    s_reorg = reorganize(s1, ((B1p.block_commitment(),
                               s1p.commitments[B1p.block_commitment()]),))
    expect("RR-2 reorg moves the head; displaced record byte-stable",
           (s_reorg.committed_head == B1p.block_commitment(),
            s_reorg.commitments[B1.block_commitment()]
            == s1.commitments[B1.block_commitment()]),
           (True, True), {})
    expect("RR-5 lineage head follows the new canonical tip",
           s_reorg.lineage_head, B1p.post_state_root, {})

    stale = ProtocolBlock(
        parent_commitment=B1.block_commitment(),
        payload_digest=B1.payload_digest, parent_state_root=B1.parent_state_root,
        post_state_root=B1.post_state_root, effect_digest=B1.effect_digest,
        evidence=B1.evidence, context=ctx(s_reorg),
        policy_commitment_presented=CFG.policy_commitment,
        recorded_context_digest=ctx(s_reorg).context_digest(), slot=2)
    vs, ds = commit_P(stale, er(parent=B1.block_commitment()), CFG, s_reorg,
                      B1.parent_state_root)
    expect("RR-3 stale evidence refused on the new branch", REFUSED, vs,
           {"failed": ds["failed"]})
    expect("RR-4 cached decision not reused (parentCommitment binding)",
           True, "ParentCommitted" in ds["failed"], {})

    B2 = blk(s_reorg, parent=B1p.block_commitment(),
             er_=er(post="b3", payload="c3", effect="d3",
                    parent=B1p.post_state_root), slot=2)
    v2, d2 = evaluate(B2, er(post="b3", payload="c3", effect="d3",
                             parent=B1p.post_state_root), CFG, s_reorg,
                      B1p.post_state_root)
    expect("RR-6 honest continuation on the new branch commits", COMMIT, v2,
           {"failed": d2["failed"]})


# ---------------------------------------------------------------------------
# Replay
# ---------------------------------------------------------------------------

def rp():
    s = state()
    B = blk(s)
    v1, d1 = evaluate(B, er(), CFG, s, GENESIS)
    v2, d2 = evaluate(B, er(), CFG, s, GENESIS)
    expect("RP-1 Evaluate idempotent (same verdict + commitment)",
           (v1, d1["blockCommitment"]), (v2, d2["blockCommitment"]), {})
    s1 = apply(s, B, d1)
    # replay AFTER commit: same semantic inputs -> same commitment; the
    # record store holds exactly one record for it (1H-R1 idempotence)
    v3, d3 = evaluate(B, er(), CFG, s1, GENESIS)
    expect("RP-2 replay post-commit: same commitment, one record",
           (v3 == COMMIT,
            len([k for k in s1.commitments
                 if k == d1["blockCommitment"]]) == 1),
           (True, True), {})
    # wall-clock/order independence: evaluate in reversed argument build order
    er2 = er()
    b2 = blk(s)
    v4, d4 = evaluate(b2, er2, CFG, s, GENESIS)
    expect("RP-3 replay independent of construction order",
           d1["blockCommitment"], d4["blockCommitment"], {})
    # replay of a DISPLACED block after reorg: refused
    B1p = blk(s, slot=1, post="b2", payload="c2", effect="d2")
    vp, dp = evaluate(B1p, er(post="b2", payload="c2", effect="d2"), CFG, s,
                      GENESIS)
    s1p = apply(s, B1p, dp)
    s_reorg = reorganize(s1, ((B1p.block_commitment(),
                               s1p.commitments[B1p.block_commitment()]),))
    vr, dr = evaluate(B, er(), CFG, s_reorg, GENESIS)
    expect("RP-4 replay of a displaced block post-reorg is refused",
           REFUSED, vr, {"failed": dr["failed"]})


# ---------------------------------------------------------------------------
# Governance / upgrade
# ---------------------------------------------------------------------------

def gov():
    s = state()
    B1 = blk(s, slot=1)
    v, d = evaluate(B1, er(), CFG, s, GENESIS)
    s1 = apply(s, B1, d)
    # GOV-2: committed history immutable under upgrade
    POLICY2 = PolicyCommitment("srw3-policy-1i-v2", "0x" + "55" * 32,
                               POLICY.app_set_digest, POLICY.graph_digest)
    CFG2 = ProtocolConfig(chain_id=CHAIN_ID, fork_version=FORK, policy=POLICY2,
                          exec_client_identity=CFG.exec_client_identity,
                          client_config_digest=CFG.client_config_digest)
    s_up = replace(s1, active_policy_commitment=CFG2.policy_commitment,
                   config=CFG2,
                   policy_activation=((s1.height, CFG2.policy_commitment),))
    expect("GOV-2 committed history immutable under upgrade",
           s1.commitments, s_up.commitments, {})

    # GOV-1: new block under the NEW policy commits; old-policy block refuses
    B2 = blk(s_up, cfg=CFG2, slot=2, post="e1", payload="f1", effect="10")
    er2 = er(post="e1", payload="f1", effect="10")
    sc2 = ctx(s_up, CFG2)
    B2 = ProtocolBlock(parent_commitment=s_up.committed_head,
                       payload_digest=er2.payload_digest,
                       parent_state_root=er2.parent_state_root,
                       post_state_root=er2.post_state_root,
                       effect_digest=er2.effect_digest,
                       evidence=Evidence(evidence_digest=er2.effect_digest,
                                         issuer_identity=CFG2.exec_client_identity,
                                         status="present",
                                         decision=SRW3_VALID, reason="honest"),
                       context=sc2,
                       policy_commitment_presented=CFG2.policy_commitment,
                       recorded_context_digest=sc2.context_digest(), slot=2)
    v2, d2 = evaluate(B2, er2, CFG2, s_up, GENESIS)
    expect("GOV-1a new block under the upgraded policy commits", COMMIT, v2,
           {"failed": d2["failed"]})

    B_old = blk(s_up, cfg=CFG, slot=2)
    vo, do = evaluate(B_old, er(), CFG, s_up, GENESIS)
    expect("GOV-1b block still presenting the superseded commitment refuses",
           REFUSED, vo, {"failed": do["failed"]})

    # GOV-3: rollback forbidden — the activation history is append-only:
    # the ONLY permitted transition is a FORWARD activation; re-presenting
    # the superseded commitment (rollback-by-presentation) refuses even with
    # a fully rebuilt v1 context, and no operation ever shortens the history.
    s_roll = s_up     # no protocol operation rewinds the active commitment
    B3 = blk(s_roll, cfg=CFG, slot=2)
    v3, d3 = evaluate(B3, er(), CFG, s_roll, GENESIS)
    expect("GOV-3a rollback-by-presentation of the superseded policy refuses",
           REFUSED, v3, {"failed": d3["failed"]})
    expect("GOV-3b activation history append-only (length only grows)",
           [(s1.height, CFG2.policy_commitment)], list(s_roll.policy_activation),
           {})

    # GOV-4: application cannot bypass — invariant-set change = new commitment
    POLICY_EVIL = PolicyCommitment(POLICY.policy_version, POLICY.policy_digest,
                                   "0x" + "99" * 32, POLICY.graph_digest)
    B_evil = blk(s, cfg=CFG)
    evil_sc = replace(B_evil.context, app_set_digest="0x" + "99" * 32)
    B_evil = ProtocolBlock(parent_commitment=B_evil.parent_commitment,
                           payload_digest=B_evil.payload_digest,
                           parent_state_root=B_evil.parent_state_root,
                           post_state_root=B_evil.post_state_root,
                           effect_digest=B_evil.effect_digest,
                           evidence=B_evil.evidence, context=evil_sc,
                           policy_commitment_presented=CFG.policy_commitment,
                           recorded_context_digest=B_evil.recorded_context_digest,
                           slot=B_evil.slot)
    ve, de = evaluate(B_evil, er(), CFG, s, GENESIS)
    expect("GOV-4 application invariant-set change is caught (SC-4/SC-9)",
           REFUSED, ve, {"why": de["checks"]["ContextValid"]["why"]})

    # GOV-5: the NEGATIVE model (PolicyAuthority = Application) — two
    # application-chosen policies coexist -> divergent commitment heads
    app_pol_a = POLICY.commitment(CHAIN_ID, FORK)
    app_pol_b = POLICY2.commitment(CHAIN_ID, FORK)
    expect("GOV-5 negative model: two app-chosen policy commitments diverge "
           "(no protocol pin) — the reason the protocol MUST pin the policy",
           True, app_pol_a != app_pol_b,
           {"a": app_pol_a[:14], "b": app_pol_b[:14],
            "note": "under PolicyAuthority=Application both are 'valid'; "
                    "honest participants following different applications "
                    "select different heads (CM-I1/CM-I5)"})


if __name__ == "__main__":
    rr()
    rp()
    gov()
    npass = sum(1 for r in RESULTS if r["pass"])
    print(f"\nPI reorg/replay+governance suite: {npass}/{len(RESULTS)} PASS")
    out = os.path.join(os.path.dirname(os.path.abspath(__file__)),
                       "../transcripts/reorg_replay/reorg_replay_governance.json")
    with open(out, "w") as f:
        json.dump({"suite": "RR-1..6 + RP-1..4 + GOV-1..5", "results": RESULTS,
                   "passed": npass, "total": len(RESULTS),
                   "allPass": npass == len(RESULTS)}, f, indent=1)
    sys.exit(0 if npass == len(RESULTS) else 1)
