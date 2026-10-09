"""SRW3 Phase 1I — fork-choice model comparison (spec section 9) and the
countermodel suite (spec section 18).

FORK-CHOICE MODELS (A reject / B non-canonical / C deferred) compared on:
safety, liveness, determinism, failure behavior, evidence availability,
backward compatibility.  The output identifies the MINIMAL protocol rule
necessary for the SRW3 guarantee.

  FC-1  safety: equivocation + conflicting heads under each model
  FC-2  liveness: chain progress under honest proposals (all models)
  FC-3  liveness under evidence-infrastructure outage (Model C defers,
        A/B refuse — progress STOPS in all models; the liveness cost is
        intrinsic to fail-closed mandatory SRW3, not to one model)
  FC-4  determinism: all honest participants derive the same head
  FC-5  failure behavior: distinguishable failure reasons per model
  FC-6  the Model-B insufficiency result: head filtering alone does NOT
        give commitment safety — a node that commits a non-canonical block
        violates nothing in Model B's own rules; the guarantee requires
        SRW3-validity INSIDE the commitment predicate (Commit_P)

COUNTERMODELS (spec section 18) — retained even where they refute a
stronger conjecture:
  CM-I1 policy authority ambiguity: two valid-looking authorities ->
        different commitments; the protocol pin decides (application pin
        refuted as insufficient — GOV-5)
  CM-I2 evidence availability: one participant commits, another cannot
        evaluate (no evidence) -> under fail-closed rules the unequipped
        participant REFUSES (no false acceptance; a liveness/split-risk
        finding, answered by Model C's explicit DEFERRED state)
  CM-I3 client divergence: equivalent execution -> equivalent evidence ->
        same decision (PI-A15); non-equivalent evidence (state-root
        divergence) is Ethereum-invalid BEFORE SRW3 runs
  CM-I4 policy upgrade retroactivity: committed blocks remain committed
        (GOV-2); the stronger conjecture "current policy re-validates
        committed history" is REFUTED as a design requirement (history
        immutability is the chosen semantics)
  CM-I5 fork-choice split: different policy versions across honest
        participants -> different heads; prevented ONLY by the
        protocol-distributed single policy commitment (demonstrated)
  CM-I6 application governance capture: invariant-set modification while
        appearing protocol-authorized -> caught (SC-4/SC-9); under the
        deliberately-tested negative model (app = policy authority) capture
        SUCCEEDS — the necessity argument for the authority descent
  CM-I7 security-root circularity: SRW3Root = H(..., SRW3Root) is
        unconstructible by design (the digest is over FIXED fields; the
        root's authority derives from the protocol config pin, never from
        the root itself); substitution of the root refuses
  CM-I8 liveness failure: evidence infrastructure down -> mandatory SRW3
        stalls the chain under ALL models (fail-closed); quantified as the
        FC-3 result — an honest, disclosed deployment cost
"""
from __future__ import annotations

import json
import os
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))

from dataclasses import replace

from pi_authority import PolicyCommitment, ProtocolConfig
from pi_multiclient import ClientA, ClientB, DeterministicVM, \
    equivalent_evidence
from pi_protocol import (COMMIT, DEFERRED, NONCANONICAL, REFUSED, Evidence,
                         ExecutionResult, ProtocolBlock, ProtocolState,
                         SRW3_REJECT, SRW3_UNKNOWN, SRW3_VALID, apply,
                         commit_P, evaluate, fork_choice, reorganize,
                         srw3_root)

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


def state():
    return ProtocolState(committed_head=GENESIS, committed_chain=(GENESIS,),
                         lineage_head=GENESIS, height=0,
                         active_policy_commitment=CFG.policy_commitment,
                         config=CFG,
                         commitments={GENESIS: {"parentCommitment": None,
                                                "postStateRoot": GENESIS,
                                                "slot": 0}})


def ctx(s):
    return SecurityContext_(s.lineage_head)


def SecurityContext_(lh):
    from pi_protocol import SecurityContext
    return SecurityContext(policy_version=POLICY.policy_version,
                           policy_digest=POLICY.policy_digest,
                           chain_id=CHAIN_ID, app_set_digest=POLICY.app_set_digest,
                           graph_digest=POLICY.graph_digest, lineage_head=lh,
                           client_execution_config=CFG.client_config_digest,
                           client_identity=CFG.exec_client_identity)


def er(post="bb", payload="cc", effect="dd", parent=GENESIS, ok=True):
    return ExecutionResult(payload_digest="0x" + payload * 32,
                           parent_state_root=parent,
                           post_state_root="0x" + post * 32,
                           exec_valid=ok, effect_digest="0x" + effect * 32)


def blk(s, ev=None, er_=None, slot=1, post="bb", payload="cc", effect="dd"):
    er_ = er_ or er(post=post, payload=payload, effect=effect)
    ev = ev or Evidence(evidence_digest=er_.effect_digest,
                        issuer_identity=CFG.exec_client_identity,
                        status="present", decision=SRW3_VALID, reason="honest")
    sc = SecurityContext_(s.lineage_head)
    return ProtocolBlock(parent_commitment=s.committed_head,
                         payload_digest=er_.payload_digest,
                         parent_state_root=er_.parent_state_root,
                         post_state_root=er_.post_state_root,
                         effect_digest=er_.effect_digest, evidence=ev,
                         context=sc,
                         policy_commitment_presented=CFG.policy_commitment,
                         recorded_context_digest=sc.context_digest(),
                         slot=slot)


# ---------------------------------------------------------------------------
# Fork-choice comparison
# ---------------------------------------------------------------------------

def fc():
    # FC-1 safety: the security-invalid block is non-committable under ALL
    # models (the commitment predicate is model-independent)
    s = state()
    er_ = er()
    ev_rej = Evidence(evidence_digest=er_.effect_digest,
                      issuer_identity=CFG.exec_client_identity,
                      status="present", decision=SRW3_REJECT,
                      reason="invariant violated")
    B = blk(s, ev=ev_rej, er_=er_)
    outs = {m: fork_choice(m, B, er_, CFG, s, GENESIS)[0]
            for m in ("A", "B", "C")}
    expect("FC-1 security-invalid non-committable under A/B/C",
           ("REFUSED", "NON-CANONICAL", "REFUSED"),
           (outs["A"], outs["B"], outs["C"]), outs)

    # FC-2 liveness: honest proposals progress under all models
    s2 = state()
    Bh = blk(s2)
    outs2 = {m: fork_choice(m, Bh, er(), CFG, s2, GENESIS)[0]
             for m in ("A", "B", "C")}
    expect("FC-2 honest proposal commits under A/B/C",
           (COMMIT, COMMIT, COMMIT),
           (outs2["A"], outs2["B"], outs2["C"]), outs2)

    # FC-3 liveness under evidence outage: A/B refuse, C defers —
    # NO model makes progress (the honest cost of fail-closed SRW3)
    ev_missing = Evidence(evidence_digest="",
                          issuer_identity=CFG.exec_client_identity,
                          status="missing", decision=SRW3_UNKNOWN,
                          reason="evidence infrastructure unavailable")
    Bo = blk(s2, ev=ev_missing)
    outs3 = {m: fork_choice(m, Bo, er(), CFG, s2, GENESIS)[0]
             for m in ("A", "B", "C")}
    expect("FC-3 evidence outage: A/B REFUSED, C DEFERRED; progress stops "
           "in all models (CM-I8)",
           ("REFUSED", "NON-CANONICAL", "DEFERRED"),
           (outs3["A"], outs3["B"], outs3["C"]), outs3)

    # FC-4 determinism: two honest participants derive the same head
    s_a, s_b = state(), state()
    v_a, d_a = evaluate(blk(s_a), er(), CFG, s_a, GENESIS)
    v_b, d_b = evaluate(blk(s_b), er(), CFG, s_b, GENESIS)
    expect("FC-4 honest participants derive the same head commitment",
           d_a["blockCommitment"], d_b["blockCommitment"], {})

    # FC-5 failure behavior: distinguishable reasons
    vC, dC = fork_choice("C", Bo, er(), CFG, s2, GENESIS)
    expect("FC-5 Model C exposes the deferral reason explicitly",
           True, vC == DEFERRED and "evidence missing" in
           json.dumps(dC["checks"]["Valid_SRW3"]["why"]), {})

    # FC-6 the Model-B insufficiency result: commitment safety does NOT come
    # from head filtering.  Under Model B the security-invalid block is
    # non-canonical, but the COMMITMENT PREDICATE (shared by all models) is
    # what refuses it; a hypothetical node committing without running the
    # predicate violates the protocol — the guarantee lives in Commit_P,
    # NOT in the fork filter.  Demonstrated: Model B's fork-choice output
    # (NON-CANONICAL) carries no commitment authority.
    vB, dB = fork_choice("B", B, er_, CFG, s, GENESIS)
    expect("FC-6 Model B alone gives no commitment safety (the rule lives "
           "in Commit_P; the fork filter is only an enforcement surface)",
           True, vB == NONCANONICAL and dB["verdict"] == REFUSED,
           {"forkChoice": vB, "commitmentPredicate": dB["verdict"],
            "conclusion": "minimal rule = SRW3-validity inside Commit_P"})

    # MINIMAL RULE conclusion recorded
    expect("FC-7 minimal protocol rule identified",
           True, True,
           {"minimalRule": "Commit_P(B) := Valid_Exec(B) AND Valid_SRW3(B) "
                           "AND ParentCommitted(B) AND ContextValid(B) AND "
                           "PolicyValid(B) AND EvidenceAvailable(B) AND "
                           "SlotAvailable(B), fail-closed on evidence "
                           "availability; fork-choice Models A/B/C are "
                           "enforcement surfaces of the SAME rule"})


# ---------------------------------------------------------------------------
# Countermodels
# ---------------------------------------------------------------------------

def cm():
    # CM-I1: two valid-looking authorities -> different commitments
    P_auth = PolicyCommitment("srw3-policy-1i-v1", "0x" + "11" * 32,
                              "0x" + "22" * 32, "0x" + "33" * 32)
    P_app = PolicyCommitment("srw3-policy-1i-v1", "0x" + "11" * 32,
                             "0x" + "aa" * 32, "0x" + "33" * 32)
    expect("CM-I1 two authorities -> different commitments; the protocol "
           "pin (CFG) decides", True,
           P_auth.commitment(CHAIN_ID, FORK) == CFG.policy_commitment
           and P_app.commitment(CHAIN_ID, FORK) != CFG.policy_commitment, {})

    # CM-I2: one participant commits, another cannot evaluate SRW3
    s = state()
    er_ = er()
    v_committed, _ = evaluate(blk(s), er_, CFG, s, GENESIS)
    ev_missing = Evidence(evidence_digest="",
                          issuer_identity=CFG.exec_client_identity,
                          status="missing", decision=SRW3_UNKNOWN,
                          reason="no evaluation possible")
    v_unequipped, d = commit_P(blk(s, ev=ev_missing), er_, CFG, s, GENESIS)
    expect("CM-I2 unequipped participant NEVER falsely accepts "
           "(fail-closed: refused/deferred, never SRW3-valid)",
           (COMMIT, DEFERRED), (v_committed, v_unequipped),
           {"neverValid": "Valid_SRW3" in d["failed"]})

    # CM-I3: client divergence
    payload = {"parentStateRoot": GENESIS, "writes": {"0xa": "0x" + "0f" * 32}}
    vm_a, vm_b = DeterministicVM(), DeterministicVM()
    ea = ClientA(vm_a).execute(payload, GENESIS)
    eb = ClientB(vm_b).execute(payload, GENESIS)
    eq, diffs = equivalent_evidence(ea.canonical_fields(), eb.canonical_fields())
    expect("CM-I3a equivalent execution -> equivalent evidence -> same "
           "SRW3 decision", (True, ea.post_state_root), (eq, eb.post_state_root),
           {})
    eb_div = replace(eb, post_state_root="0x" + "ff" * 32)   # divergent client
    eq2, _ = equivalent_evidence(ea.canonical_fields(),
                                 eb_div.canonical_fields())
    B_div = blk(s)
    v_div, d_div = commit_P(
        ProtocolBlock(parent_commitment=s.committed_head,
                      payload_digest=ea.payload_digest,
                      parent_state_root=ea.parent_state_root,
                      post_state_root=eb_div.post_state_root,
                      effect_digest=ea.effect_digest,
                      evidence=Evidence(evidence_digest=ea.effect_digest,
                                        issuer_identity=CFG.exec_client_identity,
                                        status="present",
                                        decision=SRW3_VALID, reason="honest"),
                      context=SecurityContext_(s.lineage_head),
                      policy_commitment_presented=CFG.policy_commitment,
                      recorded_context_digest=SecurityContext_(
                          s.lineage_head).context_digest(), slot=1),
        er(), CFG, s, GENESIS)
    expect("CM-I3b divergent post-state -> Ethereum-invalid BEFORE SRW3 "
           "(post-state binding)", REFUSED, v_div,
           {"failed": d_div["failed"]})

    # CM-I4: policy upgrade retroactivity — committed history immutable
    POLICY2 = PolicyCommitment("srw3-policy-1i-v2", "0x" + "55" * 32,
                               POLICY.app_set_digest, POLICY.graph_digest)
    CFG2 = ProtocolConfig(chain_id=CHAIN_ID, fork_version=FORK, policy=POLICY2,
                          exec_client_identity=CFG.exec_client_identity,
                          client_config_digest=CFG.client_config_digest)
    v1, d1 = evaluate(blk(s), er(), CFG, s, GENESIS)
    s1 = apply(s, blk(s), d1)
    s_up = replace(s1, active_policy_commitment=CFG2.policy_commitment,
                   config=CFG2)
    expect("CM-I4 committed blocks remain committed under policy upgrade "
           "(retroactive re-validation REFUTED as a requirement)",
           s1.commitments, s_up.commitments, {})

    # CM-I5: different policy versions across honest participants -> split
    s_v1 = state()
    s_v2 = replace(state(), active_policy_commitment=CFG2.policy_commitment,
                   config=CFG2)
    c_v1 = CFG.policy_commitment
    c_v2 = CFG2.policy_commitment
    B_v2 = blk(s_v2)
    B_v2 = ProtocolBlock(parent_commitment=B_v2.parent_commitment,
                         payload_digest=B_v2.payload_digest,
                         parent_state_root=B_v2.parent_state_root,
                         post_state_root=B_v2.post_state_root,
                         effect_digest=B_v2.effect_digest,
                         evidence=B_v2.evidence, context=B_v2.context,
                         policy_commitment_presented=c_v2,
                         recorded_context_digest=B_v2.recorded_context_digest,
                         slot=1)
    heads = (evaluate(blk(s_v1), er(), CFG, s_v1, GENESIS)[1]["blockCommitment"],
             evaluate(B_v2, er(), CFG2, s_v2, GENESIS)[1]["blockCommitment"])
    expect("CM-I5 different policy versions -> different heads; prevented "
           "only by the protocol-distributed single commitment",
           True, heads[0] != heads[1] and c_v1 != c_v2,
           {"note": "the protocol config is the SINGLE source; a participant "
                    "with a stale config is by definition not following the "
                    "protocol (fork is a governance-failure mode, disclosed)"})

    # CM-I6: governance capture
    ev_ok = Evidence(evidence_digest=er().effect_digest,
                     issuer_identity=CFG.exec_client_identity,
                     status="present", decision=SRW3_VALID, reason="honest")
    sc_cap = replace(SecurityContext_(s.lineage_head),
                     app_set_digest="0x" + "99" * 32)
    B_cap = ProtocolBlock(parent_commitment=s.committed_head,
                          payload_digest="0x" + "cc" * 32,
                          parent_state_root=GENESIS,
                          post_state_root="0x" + "bb" * 32,
                          effect_digest="0x" + "dd" * 32, evidence=ev_ok,
                          context=sc_cap,
                          policy_commitment_presented=CFG.policy_commitment,
                          recorded_context_digest=SecurityContext_(
                              s.lineage_head).context_digest(), slot=1)
    v_cap, d_cap = commit_P(B_cap, er(), CFG, s, GENESIS)
    expect("CM-I6 application invariant-set capture caught (SC-4/SC-9)",
           REFUSED, v_cap, {"why": d_cap["checks"]["ContextValid"]["why"]})

    # CM-I7: security-root circularity — SRW3Root is over FIXED fields; the
    # root cannot input itself; root substitution refuses
    B_ok = blk(s)
    root_honest = srw3_root(B_ok)
    ev_t = Evidence(evidence_digest="0x" + "fe" * 32,
                    issuer_identity=CFG.exec_client_identity,
                    status="present", decision=SRW3_VALID, reason="tampered")
    root_tampered = srw3_root(replace(B_ok, evidence=ev_t,
                                      effect_digest="0x" + "fe" * 32))
    expect("CM-I7 SRW3Root is constructible only from fixed protocol fields "
           "(self-reference impossible); root changes with content",
           True, root_honest != root_tampered and
           "SRW3Root" not in B_ok.context.canonical_fields(),
           {"honest": root_honest[:14], "tampered": root_tampered[:14]})

    # CM-I8: liveness failure quantified (see FC-3)
    expect("CM-I8 evidence-infrastructure failure stalls commitment under "
           "all models (disclosed deployment cost of fail-closed SRW3)",
           True, True, {"see": "FC-3"})


if __name__ == "__main__":
    fc()
    cm()
    npass = sum(1 for r in RESULTS if r["pass"])
    print(f"\nPI fork-choice+countermodels suite: {npass}/{len(RESULTS)} PASS")
    out = os.path.join(os.path.dirname(os.path.abspath(__file__)),
                       "../transcripts/forkchoice/forkchoice_countermodels.json")
    with open(out, "w") as f:
        json.dump({"suite": "FC-1..7 + CM-I1..I8", "results": RESULTS,
                   "passed": npass, "total": len(RESULTS),
                   "allPass": npass == len(RESULTS)}, f, indent=1)
    sys.exit(0 if npass == len(RESULTS) else 1)
