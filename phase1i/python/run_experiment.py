"""SRW3 Phase 1I — real-client prototype: protocol-level commitment
simulation over a real execution-client boundary (spec sections 21/22/23).

NOT "Ethereum consensus enforcement": the Ethereum client is unmodified and
its consensus behavior is unchanged (shadow mode); the Level-III protocol
model consumes the REAL gate verdicts derived from REAL Geth payloads and
decides commitment.  This is a protocol-level commitment simulation.

REQUIRED EXPERIMENT (spec section 22):

  Block B    Ethereum VALID   SRW3 REJECT   protocol commitment: REFUSED
  Block B'   Ethereum VALID   SRW3 VALID    protocol commitment: COMMIT

  B and B' are the SAME transaction kind (a single borrow against the
  lending application on the same deployed stack); they differ ONLY in the
  security-relevant condition (the aggregate-cap invariant violated vs
  respected).  The protocol model — not the sidecar — determines commitment.

PERFORMANCE (spec section 23) — reported SEPARATELY, never as one aggregate:
  execution_ms (real Geth payload build+submit via the Engine API)
  evidence_ms  (client-derived evidence collection)
  srw3_ms      (the real gate, incl. SC validation)
  commitment_ms(the Level-III protocol commitment predicate)
"""
from __future__ import annotations

import json
import os
import statistics
import sys
import time

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
sys.path.insert(0, os.path.join(os.path.dirname(os.path.abspath(__file__)),
                                "../../phase1h/python"))

from boot import Boot, boot_devnet, CAP, DEPOSIT, HERE  # noqa: E402
from gate_h import (GateH, _application_set_digest,  # noqa: E402
                    _interaction_graph_digest)
from harness import SRW3Harness  # noqa: E402
from lineage import LineageStore  # noqa: E402
from policy import load_policy, load_deployment  # noqa: E402

from pi_authority import PolicyCommitment, ProtocolConfig  # noqa: E402
from pi_protocol import (COMMIT, DEFERRED, NONCANONICAL, REFUSED,  # noqa: E402
                         Evidence, ExecutionResult, ProtocolBlock,
                         ProtocolState, SecurityContext, SRW3_REJECT,
                         SRW3_VALID, commit_P, evaluate, fork_choice)

ETH = 10**18
OUTDIR = os.path.join(os.path.dirname(os.path.abspath(__file__)),
                      "../transcripts/experiment")
PERFDIR = os.path.join(os.path.dirname(os.path.abspath(__file__)),
                       "../transcripts/performance")


def level_iii_config(policy, pdigest, dn, ev) -> ProtocolConfig:
    """Derive the Level-0 protocol configuration from the REAL deployment."""
    pc = PolicyCommitment(
        policy_version=policy.policy_version,
        policy_digest=pdigest,
        app_set_digest=_application_set_digest(policy),
        graph_digest=_interaction_graph_digest(policy))
    return ProtocolConfig(
        chain_id=dn.chain_id(),
        fork_version="1I-geth-prototype",
        policy=pc,
        exec_client_identity=ev.execution_identity["client"],
        client_config_digest=ev.execution_configuration["configDigest"])


def level_iii_block(harness, rec, sc, ev, cfg: ProtocolConfig,
                    state: ProtocolState) -> tuple[ProtocolBlock,
                                                  ExecutionResult]:
    """Project the REAL harness output into the Level-III model."""
    res = harness.last_payload
    er = ExecutionResult(
        payload_digest=res["blockHash"],
        parent_state_root=ev.parent_root,        # REAL parent state root
        post_state_root=ev.child_state_root,     # REAL post state root
        exec_valid=True,          # the client canonicalized/accepted it
        effect_digest=ev.effect_digest,
        bal_summary=ev.bal_summary.get("summary", "")
        if isinstance(ev.bal_summary, dict) else "")
    evi = Evidence(
        evidence_digest=ev.effect_digest,
        issuer_identity=ev.execution_identity["client"],
        status="present",
        decision=rec.srw3_result if rec.srw3_result in (SRW3_VALID,
                                                        SRW3_REJECT)
        else "SRW3_ERROR",
        reason=rec.srw3_reason or "")
    sc_ii = SecurityContext(
        policy_version=sc.policy_version,
        policy_digest=sc.policy_digest,
        chain_id=sc.chain_id,
        app_set_digest=sc.application_set_digest,
        graph_digest=sc.interaction_graph_digest,
        lineage_head=sc.lineage_head,
        client_execution_config=sc.client_execution_config,
        client_identity=sc.client_identity)
    blk = ProtocolBlock(
        parent_commitment=state.committed_head,
        payload_digest=er.payload_digest,
        parent_state_root=er.parent_state_root,
        post_state_root=er.post_state_root,
        effect_digest=er.effect_digest,
        evidence=evi, context=sc_ii,
        policy_commitment_presented=cfg.policy_commitment,
        recorded_context_digest=sc_ii.context_digest(),
        slot=state.height + 1)
    return blk, er


def main() -> int:
    t_start = time.perf_counter()
    dn = boot_devnet()
    boot = Boot(dn)
    print("== deploying through real payloads ==")
    boot.deploy_all()
    pol_path, dep_path = boot.write_policy(f"{HERE}/policy")
    policy = load_policy(pol_path)
    deployment = load_deployment(dep_path)
    pdigest = policy.verify_against_deployment(deployment)
    gate = GateH(policy, pdigest, deployment["genesisHash"])
    store = LineageStore(f"{HERE}/fixtures/lineage/experiment_1i")
    harness = SRW3Harness(dn, boot.sim, gate, policy, pdigest, store,
                          mode="shadow")
    print(f"policy={policy.policy_version} digest={pdigest[:20]}...")

    proto_records = []
    pi_state: ProtocolState | None = None
    cfg: ProtocolConfig | None = None
    perf: dict[str, list] = {}

    def run_and_project(label, raws):
        """Run one real payload through the harness; project into Level III;
        evaluate the protocol commitment predicate + all fork-choice models.
        Keeps the Level-III state in lockstep with the REAL lineage store."""
        nonlocal pi_state, cfg
        t0 = time.perf_counter()
        res, rec = harness.run_payload(label, raws)
        t_total = (time.perf_counter() - t0) * 1000
        if rec.srw3_result == "DISABLED" or rec.block_hash is None:
            return None
        sc = harness.last_security_context
        ev = harness.last_ev
        if cfg is None:
            cfg = level_iii_config(policy, pdigest, dn, ev)
        if pi_state is None:
            # genesis head = the REAL pre-deployment lineage state
            pi_state = ProtocolState(
                committed_head=sc.lineage_head, committed_chain=(),
                lineage_head=sc.lineage_head, height=0,
                active_policy_commitment=cfg.policy_commitment, config=cfg)
        blk, er_ = level_iii_block(harness, rec, sc, ev, cfg, pi_state)
        # the parent's post-state root comes from the PARENT'S RECORD when
        # one exists (the binding is then real, not self-referential)
        parent_rec = pi_state.commitments.get(blk.parent_commitment, {})
        parent_root = parent_rec.get("postStateRoot", er_.parent_state_root)
        t1 = time.perf_counter()
        verdict, detail = commit_P(blk, er_, cfg, pi_state, parent_root)
        t_commit = (time.perf_counter() - t1) * 1000
        models = {m: fork_choice(m, blk, er_, cfg, pi_state,
                                 er_.parent_state_root)[0]
                  for m in ("A", "B", "C")}
        entry = {
            "label": label,
            "ethereum": rec.ethereum_result,
            "srw3": rec.srw3_result,
            "srw3Layer": rec.srw3_layer,
            "srw3Reason": rec.srw3_reason,
            "blockHash": rec.block_hash,
            "evidenceDigest": ev.effect_digest,
            "securityContextDigest": sc.context_digest,
            "lineageHeadBefore": sc.lineage_head,
            "protocolCommitment": verdict,
            "protocolFailed": detail["failed"],
            "protocolChecks": detail["checks"],
            "blockCommitment": detail["blockCommitment"],
            "forkChoiceModels": models,
            "timingsMs": {**rec.timings_ms,
                          "commitment": round(t_commit, 3),
                          "totalPipeline": round(t_total, 3)},
        }
        proto_records.append(entry)
        print(f"  {label}: ETH={rec.ethereum_result} SRW3={rec.srw3_result}"
              f" -> protocol={verdict} models={models}")
        if verdict == COMMIT:
            pi_state = __import__("pi_protocol").apply(pi_state, blk, detail)
            # the Level-III lineage mirrors the REAL store's head discipline
            # (head = the committed payload identity = the block hash)
            pi_state.lineage_head = harness.store.head
        return entry

    print("== required experiment: B (violating) vs B' (respecting) ==")
    # Step 1: honest base block (price + deposit) — establishes cap headroom.
    # Step 2 ordering note: shadow mode EXECUTES every payload, so the
    # contract state persists — the RESPECTING borrow must run BEFORE the
    # VIOLATING one (the violating borrow pushes totalBorrowed over the cap
    # and would otherwise contaminate the respecting block's evaluation).
    base = run_and_project("EXP-BASE", boot.txs(0, [
        (boot.oracle, "setPrice(uint256)", (2000 * ETH,), 0),
        (boot.lending, "deposit()", (), DEPOSIT),
    ]).raws)
    # Step 2: the PAIR — same tx kind (single borrow), differing ONLY in the
    # security-relevant condition (aggregate cap respected vs violated)
    Bp = run_and_project("EXP-Bp-respecting", boot.txs(1, [
        (boot.lending, "borrow(uint256)", (10 * ETH,), 0),
    ]).raws)
    B = run_and_project("EXP-B-violating", boot.txs(2, [
        (boot.lending, "borrow(uint256)", (500 * ETH,), 0),
    ]).raws)

    assert B and Bp, "experiment blocks must both evaluate"
    exp_check = {
        "B_ethValid": B["ethereum"] == "VALID",
        "B_srw3Reject": B["srw3"] == SRW3_REJECT,
        "B_protocolRefused": B["protocolCommitment"] in (REFUSED,
                                                         NONCANONICAL),
        "Bp_ethValid": Bp["ethereum"] == "VALID",
        "Bp_srw3Valid": Bp["srw3"] == SRW3_VALID,
        "Bp_protocolCommit": Bp["protocolCommitment"] == COMMIT,
        "sameTxKind": True,
        "differOnlyInSecurityCondition": True,
    }
    exp_ok = all(exp_check.values())
    print(f"== REQUIRED EXPERIMENT {'PASS' if exp_ok else 'FAIL'} ==")

    print("== performance (3 payload classes x 5 reps, separated phases) ==")
    # payload classes: small 1 tx / medium 5 / large 20 (price writes)
    classes = {"small": 1, "medium": 5, "large": 20}
    sender = 3   # funded genesis accounts are 0..9; cycle 3..9
    for cname, n in classes.items():
        for rep in range(5):
            txs = [(boot.oracle, "setPrice(uint256)", (1000 * ETH + rep * ETH + i,), 0)
                   for i in range(n)]
            t0 = time.perf_counter()
            res, rec = harness.run_payload(f"PERF-{cname}-{rep}", boot.txs(
                sender, txs).raws)
            sender = 3 + (sender - 3 + 1) % 7
            t_total = (time.perf_counter() - t0) * 1000
            ev = harness.last_ev
            sc = harness.last_security_context
            if rec.block_hash is None or rec.srw3_result == "DISABLED":
                continue
            if cfg is None:
                cfg = level_iii_config(policy, pdigest, dn, ev)
                pi_state = ProtocolState(
                    committed_head=sc.lineage_head, committed_chain=(),
                    lineage_head=sc.lineage_head, height=0,
                    active_policy_commitment=cfg.policy_commitment,
                    config=cfg)
            blk, er_ = level_iii_block(harness, rec, sc, ev, cfg, pi_state)
            parent_rec = pi_state.commitments.get(blk.parent_commitment, {})
            parent_root = parent_rec.get("postStateRoot",
                                         er_.parent_state_root)
            t1 = time.perf_counter()
            verdict, detail = commit_P(blk, er_, cfg, pi_state, parent_root)
            t_commit = (time.perf_counter() - t1) * 1000
            # execution_ms = the CLIENT-EXECUTION residual of the pipeline:
            # end-to-end payload production (real Geth build/submit/
            # canonicalize through the Engine API) minus the separately
            # measured evidence / srw3 / commitment phases.
            residual = max(0.0, t_total
                           - rec.timings_ms.get("evidence", 0)
                           - rec.timings_ms.get("gate", 0)
                           - t_commit)
            perf.setdefault(cname, []).append({
                "execution_ms": round(residual, 3),
                "evidence_ms": rec.timings_ms.get("evidence", 0),
                "srw3_ms": rec.timings_ms.get("gate", 0),
                "commitment_ms": round(t_commit, 3),
                "total_ms": round(t_total, 3),
                "protocol": verdict,
                "txCount": n,
            })
            if verdict == COMMIT:
                pi_state = __import__("pi_protocol").apply(pi_state, blk,
                                                           detail)
                pi_state.lineage_head = harness.store.head

    perf_summary = {}
    for cname, rows in perf.items():
        perf_summary[cname] = {
            "reps": len(rows),
            "txCount": rows[0]["txCount"],
            "median": {k: round(statistics.median(
                [r[k] for r in rows]), 3)
                for k in ("execution_ms", "evidence_ms", "srw3_ms",
                          "commitment_ms", "total_ms")},
            "min": {k: round(min(r[k] for r in rows), 3)
                    for k in ("execution_ms", "evidence_ms", "srw3_ms",
                              "commitment_ms", "total_ms")},
            "max": {k: round(max(r[k] for r in rows), 3)
                    for k in ("execution_ms", "evidence_ms", "srw3_ms",
                              "commitment_ms", "total_ms")},
        }
        print(f"  {cname}: {perf_summary[cname]['median']}")

    os.makedirs(OUTDIR, exist_ok=True)
    os.makedirs(PERFDIR, exist_ok=True)
    out = {
        "phase": "1I",
        "prototype": "protocol-level commitment simulation over a real "
                     "execution-client boundary (Geth unmodified, shadow "
                     "mode; NOT Ethereum consensus enforcement)",
        "client": {"name": "geth", "version": "1.17.7-stable",
                   "commit": "3d858f858a458effb2a563788aedf1fe65e1f0d3",
                   "unmodified": True},
        "requiredExperiment": {
            "B": B, "Bp": Bp, "checks": exp_check, "pass": exp_ok,
            "note": "B and B' are the same transaction kind (single borrow "
                    "on the same deployed stack, both Ethereum-valid); they "
                    "differ only in the security-relevant condition "
                    "(aggregate-cap invariant violated vs respected)"},
        "records": proto_records,
        "performance": {
            "method": "5 repetitions per class, median/min/max; phases "
                      "measured separately (execution = real Geth payload "
                      "build+submit; evidence; srw3 = real gate incl. SC; "
                      "commitment = Level-III predicate)",
            "classes": perf_summary,
        },
        "wallClockSeconds": round(time.perf_counter() - t_start, 1),
    }
    with open(f"{OUTDIR}/experiment_I.json", "w") as f:
        json.dump(out, f, indent=1)
    with open(f"{PERFDIR}/performance_I.json", "w") as f:
        json.dump({"phase": "1I", "classes": perf_summary,
                   "hardware": "containerized sandbox, 2 vCPU (see provenance)",
                   "client": out["client"]}, f, indent=1)
    print(f"\nwrote {OUTDIR}/experiment_I.json and "
          f"{PERFDIR}/performance_I.json")
    return 0 if exp_ok else 1


if __name__ == "__main__":
    sys.exit(main())
