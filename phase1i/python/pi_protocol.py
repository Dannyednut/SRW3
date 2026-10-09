"""SRW3 Phase 1I — the Level-III protocol model (the primary target).

Spec section 3, Level III:

    protocol input -> deterministic execution -> SRW3 evaluation
        -> protocol validity predicate -> commit / reject

This module defines, executable and deterministic:

  ProtocolConfig        Pi   (level-0 authority; pi_authority.ProtocolConfig)
  PolicyCommitment      (protocol-authorized policy identity)
  ProtocolBlock         B    (candidate block/payload + its security evidence)
  ProtocolState         S    (committed chain head, lineage head, active policy)
  ExecutionResult       (Ethereum execution outcome + derived evidence)

  Valid_Exec(B)      — Ethereum execution validity (post-state binding)
  Valid_SRW3(B)      — gate verdict VALID under a validated SecurityContext
  Valid_P(B)         = Valid_Exec(B) AND Valid_SRW3(B)
  Commit_P(B,S)      = Valid_P(B) AND ParentCommitted(B) AND ContextValid(B)
                       AND PolicyValid(B) AND EvidenceAvailable(B)   [fail-closed]

  Apply(B_n, P_n)    — deterministic state transition
  fork-choice Models A / B / C  (spec section 9)

EVIDENCE-AVAILABILITY SEMANTICS (spec section 10 — the CHOSEN protocol rule,
fail-closed by default):

    evidence status   Ethereum   SRW3 decision     commitment consequence
    ---------------   --------   ----------------  -------------------------
    present+VALID     any        SRW3_VALID        eligible (commit if the
                                                   other conjuncts hold)
    present+REJECT    any        SRW3_REJECT       NOT committable (all models)
    missing           VALID      SRW3_UNKNOWN      NOT committable; NOT
                                                   SRW3-valid (never silently
                                                   valid); Model C defers,
                                                   A/B refuse
    malformed         VALID      SRW3_ERROR        fail-closed: refuse (A/B),
                                                   defer-with-quarantine (C)
    inconsistent      VALID      SRW3_ERROR        fail-closed: refuse (A/B),
                                                   defer-with-quarantine (C)
    unavailable       VALID      SRW3_ERROR        fail-closed: refuse (A/B),
                                                   defer (C); LIVENESS COST
                                                   (CM-I8)

  EvidenceMissing(B) => NOT SRW3Valid(B)  holds BY CONSTRUCTION: Valid_SRW3
  requires an evidence object with status "present" and decision VALID.

REORG/REPLAY (spec sections 12/13): evidence binds parentCommitment and
parentStateRoot; a displaced-branch (stale) evidence object fails
ParentCommitted/ContextValid on the new branch.  Evaluate() is a pure
function of (B, C, E, Pi): no wall clock, no process identity, no evaluation
order, no cache dependence; commitment records are keyed by the canonical
block commitment (1H-R1 semantic-lineage idempotence carried upward).

FORK-CHOICE MODELS (spec section 9), formalized:

  Model A (reject):            SRW3 != VALID  =>  protocol-INVALID payload.
  Model B (non-canonical):     SRW3 != VALID  =>  payload stays Ethereum-valid
                               but is INELIGIBLE for canonical head; the
                               protocol may keep it in a side branch.
  Model C (deferred):          SRW3 UNKNOWN/ERROR => block is a DEFERRED
                               candidate: never finalized/committed until a
                               decision exists; REJECT => security-invalid
                               (non-committable).

Model B alone does NOT give the central guarantee: commitment is a separate
act from head selection, and a node that commits a non-canonical block breaks
nothing in Model B's own rules — the guarantee requires SRW3 validity inside
the COMMITMENT PREDICATE (that is what Commit_P does for all models).  The
comparison suite (run_forkchoice_compare.py) quantifies this.
"""
from __future__ import annotations

import json
import os
from dataclasses import dataclass, field, replace
from typing import Optional

from pi_authority import (PolicyCommitment, ProtocolConfig, policy_valid)
from pi_canonical import (DOM_BLOCKCOMMIT, DOM_SRW3ROOT, canonical_digest)

# SRW3 decisions (Level-III vocabulary over the Phase 1H gate verdicts)
SRW3_VALID = "SRW3_VALID"
SRW3_REJECT = "SRW3_REJECT"
SRW3_UNKNOWN = "SRW3_UNKNOWN"     # no decision exists (e.g., evidence missing)
SRW3_ERROR = "SRW3_ERROR"         # adapter/evidence failure (fail-closed)

EVIDENCE_STATUSES = ("present", "missing", "malformed", "inconsistent",
                     "unavailable")

COMMIT = "COMMIT"
NONCANONICAL = "NON-CANONICAL"
DEFERRED = "DEFERRED"
REFUSED = "REFUSED"


# ---------------------------------------------------------------------------
# Protocol objects
# ---------------------------------------------------------------------------

@dataclass(frozen=True)
class SecurityContext:
    """The per-evaluation security context (Phase 1H-R1 shape, Level-III
    projection).  context_digest is recomputed, never trusted."""
    policy_version: str
    policy_digest: str
    chain_id: int
    app_set_digest: str
    graph_digest: str
    lineage_head: str
    client_execution_config: str
    client_identity: str

    def canonical_fields(self) -> dict:
        return {
            "policyVersion": self.policy_version,
            "policyDigest": self.policy_digest,
            "chainId": self.chain_id,
            "appSetDigest": self.app_set_digest,
            "interactionGraphDigest": self.graph_digest,
            "lineageHead": self.lineage_head,
            "clientExecutionConfig": self.client_execution_config,
            "clientIdentity": self.client_identity,
        }

    def context_digest(self) -> str:
        # Same canonical discipline as 1H-R1 SRW3-CONTEXT-H-V1 (recomputed at
        # validation time; SC-9 at the protocol layer).
        from pi_canonical import canonical_serialization
        from eth_utils import keccak
        can = ("SRW3-CONTEXT-H-V1\n" + "\n".join(
            f"{k}={v}" for k, v in sorted(
                ((k, str(v)) for k, v in self.canonical_fields().items()))))
        return "0x" + keccak(can.encode()).hex()


@dataclass(frozen=True)
class ExecutionResult:
    """Ethereum execution of a payload against a pre-state (spec section 4)."""
    payload_digest: str
    parent_state_root: str
    post_state_root: str
    exec_valid: bool                     # Valid_Exec
    effect_digest: str                   # execution-derived effect evidence
    bal_summary: str = ""                # access-list summary (1G BAL axis)

    def canonical_fields(self) -> dict:
        return {
            "payloadDigest": self.payload_digest,
            "parentStateRoot": self.parent_state_root,
            "postStateRoot": self.post_state_root,
            "effectDigest": self.effect_digest,
            "balSummary": self.bal_summary,
        }


@dataclass(frozen=True)
class Evidence:
    """ExecutionEvidence + SRW3 decision record for one block (spec 4)."""
    evidence_digest: str
    issuer_identity: str                 # must be the authorized client
    status: str                          # one of EVIDENCE_STATUSES
    decision: str                        # one of the SRW3_* decisions
    reason: str = ""
    gate_checks: dict = field(default_factory=dict)

    def semantic_projection(self) -> dict:
        """Semantic identity of the evidence (no observation metadata)."""
        return {
            "evidenceDigest": self.evidence_digest,
            "issuerIdentity": self.issuer_identity,
            "status": self.status,
            "decision": self.decision,
        }


@dataclass(frozen=True)
class ProtocolBlock:
    """The candidate B (spec section 4 field list).

    recorded_context_digest is the context digest RECORDED AT CONTEXT
    CONSTRUCTION TIME (the honest harness binds it into the evidence/lineage
    before evaluation).  SC-9 at the protocol layer compares this recorded
    value against recomputation from the presented context object, so a
    post-hoc context tamper cannot pass (mirrors 1H-R1 SCT-9)."""
    parent_commitment: str               # ParentCommitted(B)
    payload_digest: str
    parent_state_root: str
    post_state_root: str
    effect_digest: str
    evidence: Evidence                   # ExecutionEvidence/EffectEvidence
    context: SecurityContext             # SecurityContext
    policy_commitment_presented: str     # as claimed for this block
    recorded_context_digest: str = ""    # SC-9 anchor (empty = not recorded)
    slot: int = 0                        # protocol height of the candidate

    def block_commitment(self) -> str:
        """Canonical block commitment (the identity committed by Commit_P).

        Binds: parent commitment, payload, both state roots, effect digest,
        evidence digest, context digest, the policy commitment UNDER WHICH
        the security decision was made, and the decision itself."""
        return canonical_digest(DOM_BLOCKCOMMIT, {
            "parentCommitment": self.parent_commitment,
            "payloadDigest": self.payload_digest,
            "parentStateRoot": self.parent_state_root,
            "postStateRoot": self.post_state_root,
            "effectDigest": self.effect_digest,
            "evidenceDigest": self.evidence.evidence_digest,
            "contextDigest": self.context.context_digest(),
            "policyCommitment": self.policy_commitment_presented,
            "srw3Decision": self.evidence.decision,
            "slot": self.slot,
        })


@dataclass
class ProtocolState:
    """Committed protocol state S (spec section 4: Commitment/ForkChoice)."""
    committed_head: str                  # commitment of the committed head
    committed_chain: tuple = ()          # tuple of block commitments
    lineage_head: str = "0x" + "00" * 32
    height: int = 0
    active_policy_commitment: str = ""   # protocol-authorized (from config)
    config: ProtocolConfig | None = None
    policy_activation: tuple = ()        # ((height, commitment), ...) upgrades
    deferred: tuple = ()                 # Model C deferred candidates
    commitments: dict = field(default_factory=dict)  # commitment -> record


# ---------------------------------------------------------------------------
# Validity and commitment predicates (the central target; spec sections 2/4)
# ---------------------------------------------------------------------------

def valid_exec(B: ProtocolBlock, er: ExecutionResult,
               parent_state_root: str) -> tuple[bool, str]:
    """Valid_Exec(B): the payload executed VALIDLY against the committed
    parent state — post-state binding included (state-root binding, 1H L1)."""
    if not er.exec_valid:
        return False, "execution-invalid (client rejected payload)"
    if er.parent_state_root != parent_state_root:
        return False, "parent-state-root mismatch (stale/foreign base)"
    if B.parent_state_root != parent_state_root:
        return False, "block parent-state-root mismatch"
    if B.post_state_root != er.post_state_root:
        return False, "post-state-root mismatch (block vs execution)"
    if B.payload_digest != er.payload_digest:
        return False, "payload identity mismatch"
    if B.effect_digest != er.effect_digest:
        return False, "effect digest mismatch (block vs execution-derived)"
    return True, "execution-valid with post-state binding"


def _context_valid(B: ProtocolBlock, cfg: ProtocolConfig,
                   state: ProtocolState) -> tuple[bool, str]:
    """ContextValid(B) — SC-1..SC-9 at the protocol layer (fail-closed,
    NO substitution path; spec sections 5/6).  The authorized comparison
    values come from the PROTOCOL CONFIG (level 0), never from the context
    object itself."""
    sc = B.context
    ap = cfg.policy
    # SC-9: integrity of the supplied object itself — the digest RECORDED at
    # context-construction time must equal the recomputed canonical digest.
    if not B.recorded_context_digest:
        return False, "SC-9 context digest not recorded (unbound context)"
    if sc.context_digest() != B.recorded_context_digest:
        return False, ("SC-9 context digest integrity violated: recorded "
                       f"{B.recorded_context_digest[:18]}... != recomputed "
                       f"{sc.context_digest()[:18]}...")
    # SC-1: policy version binding (vs protocol-authorized policy object).
    if sc.policy_version != ap.policy_version:
        return False, (f"SC-1 policy version binding violated: context "
                       f"{sc.policy_version!r} != authorized "
                       f"{ap.policy_version!r}")
    # SC-2: policy content digest binding.
    if sc.policy_digest != ap.policy_digest:
        return False, (f"SC-2 policy digest binding violated: context "
                       f"{sc.policy_digest[:18]}... != deployment-pinned "
                       f"{ap.policy_digest[:18]}...")
    # SC-3: chain identity.
    if sc.chain_id != cfg.chain_id:
        return False, "SC-3 chain identity binding violated"
    # SC-4: application-set digest binding.
    if sc.app_set_digest != ap.app_set_digest:
        return False, "SC-4 application-set binding violated: context " \
                      "applicationSetDigest != digest(authorized application set)"
    # SC-5: interaction-graph digest binding.
    if sc.graph_digest != ap.graph_digest:
        return False, "SC-5 interaction-graph binding violated: context " \
                      "interactionGraphDigest != digest(authorized graph)"
    # SC-6: client execution configuration.
    if sc.client_execution_config != cfg.client_config_digest:
        return False, "SC-6 client configuration binding violated"
    # SC-7: client identity.
    if sc.client_identity != cfg.exec_client_identity:
        return False, "SC-7 client identity binding violated"
    # SC-8: lineage head binding — the context must carry the APPLICABLE
    # lineage head: the protocol lineage state AT THE BLOCK'S PARENT (for a
    # fresh block on the committed head this is the current tip; for an
    # authorized REPLAY it is the recorded pre-block lineage head — the
    # Phase 1H-R1 section-14 recipe carried to the protocol layer).
    applicable = applicable_lineage_head(state, B.parent_commitment)
    if applicable is None or sc.lineage_head != applicable:
        return False, ("SC-8 lineage-head binding violated: context "
                       f"{sc.lineage_head[:10]} != applicable "
                       f"{(applicable or 'UNBOUND')[:10]}")
    # SC-1/SC-2 again at the COMMITMENT level: the presented policy commitment
    # must equal the protocol-authorized commitment (version+digest+authority).
    ok, why = policy_valid_from_presented(B, cfg, state)
    if not ok:
        return False, why
    return True, "SC-1..SC-9 ok (SC-10: no substitution path exists)"


def applicable_lineage_head(state: ProtocolState,
                            parent_commitment: str) -> str | None:
    """The lineage head applicable to a block whose parent commitment is
    given: the committed head's lineage for a fresh block; the PARENT's own
    post-state root for a replay/reorg-candidate (the lineage state the
    parent defines).  None if the parent is not committed."""
    if parent_commitment == state.committed_head:
        return state.lineage_head
    rec = state.commitments.get(parent_commitment)
    if rec is not None:
        return rec.get("postStateRoot")
    return None


def policy_valid_from_presented(B: ProtocolBlock, cfg: ProtocolConfig,
                                state: ProtocolState) -> tuple[bool, str]:
    """PolicyValid(B): the presented commitment equals BOTH the
    protocol-authorized commitment AND the state's active commitment (which
    is derived from the config + activation history)."""
    active = state.active_policy_commitment or cfg.policy_commitment
    if B.policy_commitment_presented != cfg.policy_commitment:
        return False, ("policy commitment substitution: presented "
                       f"{B.policy_commitment_presented[:18]}... is not the "
                       "protocol-authorized commitment")
    if B.policy_commitment_presented != active:
        return False, "policy commitment does not match active protocol state"
    return True, "protocol-authorized policy commitment"


def valid_srw3(B: ProtocolBlock, cfg: ProtocolConfig,
               state: ProtocolState) -> tuple[bool, str]:
    """Valid_SRW3(B): a security decision EXISTS, the evidence is bound to
    the execution and to an authorized issuer, the decision is VALID, and
    the security context is first-class-valid.  Missing/malformed/
    inconsistent/unavailable evidence NEVER yields Valid_SRW3 (spec section
    10).  Authority is CONTEXT-DERIVED: the authorized issuer comes from the
    protocol config, never from the evidence object (1G invalid-authsrc
    discipline at the protocol layer)."""
    ev = B.evidence
    if ev.status not in ("present",):
        return False, f"evidence {ev.status}: no SRW3-valid decision exists"
    # Evidence AUTHORITY: the issuer must be the protocol-authorized
    # execution client; a self-declared authorization is inert.
    if ev.issuer_identity != cfg.exec_client_identity:
        return False, ("invalid-authsrc: evidence issuer is not the "
                       "protocol-authorized execution client")
    # Evidence BINDING: the consumed evidence must be THE execution-derived
    # effect evidence for this block (1F effect binding at the protocol layer).
    if ev.evidence_digest != B.effect_digest:
        return False, ("invalid-effbind: evidence digest is not the "
                       "execution-derived effect digest of this block")
    if ev.decision != SRW3_VALID:
        return False, f"gate decision {ev.decision} ({ev.reason})"
    ok, why = _context_valid(B, cfg, state)
    if not ok:
        return False, why
    return True, "SRW3-valid under validated security context"


def valid_P(B: ProtocolBlock, er: ExecutionResult, cfg: ProtocolConfig,
            state: ProtocolState, parent_state_root: str) -> tuple[bool, str]:
    """Valid_P(B) = Valid_Exec(B) AND Valid_SRW3(B) (spec section 4)."""
    ok_e, why_e = valid_exec(B, er, parent_state_root)
    if not ok_e:
        return False, why_e
    ok_s, why_s = valid_srw3(B, cfg, state)
    if not ok_s:
        return False, why_s
    return True, "Valid_P: execution-valid AND SRW3-valid"


def parent_committed(B: ProtocolBlock, state: ProtocolState) -> tuple[bool, str]:
    if B.parent_commitment == state.committed_head:
        return True, "parent is the committed head"
    if B.parent_commitment in state.committed_chain:
        return True, "parent is a committed ancestor (reorg candidate branch)"
    return False, (f"parent commitment {B.parent_commitment[:14]}... is not "
                   "committed (unbuilt/stale/displaced branch)")


def slot_available(B: ProtocolBlock, state: ProtocolState) -> tuple[bool, str]:
    """SlotAvailable(B) — a DOCUMENTED ADDITIONAL commitment conjunct (the
    spec's section-4 formula is explicitly non-exhaustive): two conflicting
    blocks at the same protocol slot cannot BOTH commit on the canonical
    chain (the one-block-per-slot rule; the Ethereum analog is proposer-slot
    uniqueness).  The K transition model enforces the same rule structurally
    (the accept guard pins pbSlotOf(B) ==Int N and N advances only on
    accept).  This is the surface that makes a replay of a DISPLACED block
    post-reorg impossible without a fresh proposal."""
    for bc in state.committed_chain:
        rec = state.commitments.get(bc, {})
        if rec.get("slot") == B.slot and bc != B.block_commitment():
            return False, (f"slot {B.slot} already committed on the canonical "
                           f"chain ({bc[:14]}...)")
    return True, "slot available on the canonical chain"


def commit_P(B: ProtocolBlock, er: ExecutionResult, cfg: ProtocolConfig,
             state: ProtocolState, parent_state_root: str,
             er_in_block: bool = True) -> tuple[str, dict]:
    """Commit_P(B) — THE central Phase 1I predicate.

        Commit_P(B,C,E,Pi)  =>  EthereumValid(B) AND SRW3Valid(B,C,E,Pi)

    Every conjunct is explicit and every refusal names the failed conjunct
    (spec section 7: the proof must expose every assumption).  Returns
    (COMMIT | NON-CANONICAL | DEFERRED | REFUSED, detail)."""
    checks: dict = {}
    ok, why = valid_exec(B, er, parent_state_root)
    checks["Valid_Exec"] = {"ok": ok, "why": why}
    ok, why = valid_srw3(B, cfg, state)
    checks["Valid_SRW3"] = {"ok": ok, "why": why}
    ok, why = parent_committed(B, state)
    checks["ParentCommitted"] = {"ok": ok, "why": why}
    ok, why = _context_valid(B, cfg, state)
    checks["ContextValid"] = {"ok": ok, "why": why}
    ok, why = policy_valid_from_presented(B, cfg, state)
    checks["PolicyValid"] = {"ok": ok, "why": why}
    checks["EvidenceAvailable"] = {
        "ok": B.evidence.status == "present",
        "why": f"evidence status: {B.evidence.status}"}
    ok, why = slot_available(B, state)
    checks["SlotAvailable"] = {"ok": ok, "why": why}

    hard_fail = [k for k, v in checks.items() if not v["ok"]]
    # Model C semantics live at the fork-choice layer; the COMMITMENT
    # predicate itself is model-independent (one rule, three enforcement
    # surfaces).  Deferral: the ONLY failures are the security-evaluation
    # ones (no decision exists yet) and nothing else is wrong.
    if hard_fail:
        deferred_only = (
            set(hard_fail) <= {"Valid_SRW3", "EvidenceAvailable"}
            and B.evidence.decision in (SRW3_UNKNOWN, SRW3_ERROR)
            and B.evidence.status in ("missing", "unavailable", "malformed",
                                      "inconsistent"))
        detail = {"verdict": REFUSED, "failed": hard_fail, "checks": checks,
                  "blockCommitment": B.block_commitment()}
        return (DEFERRED if deferred_only else REFUSED), detail
    detail = {"verdict": COMMIT, "failed": [], "checks": checks,
              "blockCommitment": B.block_commitment()}
    return COMMIT, detail


# ---------------------------------------------------------------------------
# Deterministic transition + commitment records (spec sections 4/13)
# ---------------------------------------------------------------------------

def apply(state: ProtocolState, B: ProtocolBlock, detail: dict) -> ProtocolState:
    """B_{n+1} = Apply(B_n, P_n): commit B (caller has run commit_P == COMMIT),
    update lineage head, append the commitment record.  Deterministic: the
    new state is a pure function of (state, B, decision)."""
    bc = B.block_commitment()
    rec = {
        "blockCommitment": bc,
        "parentCommitment": B.parent_commitment,
        "payloadDigest": B.payload_digest,
        "parentStateRoot": B.parent_state_root,
        "postStateRoot": B.post_state_root,
        "evidenceDigest": B.evidence.evidence_digest,
        "evidenceSemantic": B.evidence.semantic_projection(),
        "contextDigest": B.context.context_digest(),
        "policyCommitment": B.policy_commitment_presented,
        "srw3Decision": B.evidence.decision,
        "slot": B.slot,
        # NO wall-clock field: the commitment record is semantic identity
        # only (the Phase 1H-R1 lesson, carried to the protocol layer).
    }
    return replace(
        state,
        committed_head=bc,
        committed_chain=state.committed_chain + (bc,),
        lineage_head=B.post_state_root,       # lineage follows commitment
        height=state.height + 1,
        commitments={**state.commitments, bc: rec})


def evaluate(B: ProtocolBlock, er: ExecutionResult, cfg: ProtocolConfig,
             state: ProtocolState, parent_state_root: str) -> tuple[str, dict]:
    """Replay-semantic entry point (spec section 13): Evaluate(B,C,E,Pi) is a
    PURE function of its inputs — no wall clock, no process identity, no
    local cache, no evaluation order, no lineage observation timestamp.
    Same inputs => identical (verdict, detail)."""
    return commit_P(B, er, cfg, state, parent_state_root)


# ---------------------------------------------------------------------------
# Fork-choice models A / B / C (spec section 9)
# ---------------------------------------------------------------------------

def fork_choice(model: str, B: ProtocolBlock, er: ExecutionResult,
                cfg: ProtocolConfig, state: ProtocolState,
                parent_state_root: str) -> tuple[str, dict]:
    """Return (head-action, detail) for the candidate under the model.

    Model A: SRW3 != VALID (or evidence not present) -> protocol-INVALID:
             the payload is refused and never canonical.
    Model B: SRW3 != VALID -> the payload stays Ethereum-valid but is
             INELIGIBLE for canonical head (side-branch); the COMMITMENT
             predicate still refuses it (safety comes from Commit_P).
    Model C: SRW3 UNKNOWN/ERROR -> DEFERRED candidate (cannot finalize until
             a decision exists); SRW3 REJECT -> security-invalid
             (non-committable); VALID -> commit-eligible."""
    v, detail = commit_P(B, er, cfg, state, parent_state_root)
    if model == "A":
        return (COMMIT if v == COMMIT else REFUSED), detail
    if model == "B":
        if v == COMMIT:
            return COMMIT, detail
        # Ethereum-valid but security-ineligible: eligible-for-nothing at the
        # protocol layer; head selection filters it out.
        return NONCANONICAL, detail
    if model == "C":
        if v == COMMIT:
            return COMMIT, detail
        if detail["failed"] and set(detail["failed"]) <= {"Valid_SRW3",
                                                          "EvidenceAvailable"} \
                and B.evidence.decision in (SRW3_UNKNOWN, SRW3_ERROR):
            return DEFERRED, detail
        return REFUSED, detail
    raise ValueError(f"unknown fork-choice model: {model}")


def srw3_root(B: ProtocolBlock) -> str:
    """Candidate D of the commitment-root design (spec section 16) — the
    combined SRW3 root.  Implemented for COMPARISON; not auto-selected."""
    return canonical_digest(DOM_SRW3ROOT, {
        "parentRoot": B.parent_commitment,
        "policyCommitment": B.policy_commitment_presented,
        "contextDigest": B.context.context_digest(),
        "evidenceDigest": B.evidence.evidence_digest,
        "securityDecision": B.evidence.decision,
    })


# ---------------------------------------------------------------------------
# Reorg semantics (spec section 12)
# ---------------------------------------------------------------------------

def reorganize(state: ProtocolState,
               new_branch: tuple) -> ProtocolState:
    """A->B->C then A->B'->C': move the canonical head to a competing branch
    built on a committed ancestor.

    new_branch: ((commitment, record), ...) in chain order; every record was
    produced by apply() on its own branch (commitment records are IMMUTABLE
    and travel with the branch).

    Protocol rules exercised:
      * committed records are never rewritten (byte-stable history);
      * the lineage head FOLLOWS the new canonical tip;
      * cached decisions are NOT reused across the reorg: evidence binds
        parentCommitment, so a displaced-branch block fails ParentCommitted
        on the new branch (tested by the suites)."""
    if not new_branch:
        return state
    new_comms = dict(state.commitments)
    new_chain = list(state.committed_chain)
    parent_of_first = new_branch[0][1]["parentCommitment"]
    if parent_of_first in new_chain:
        idx = new_chain.index(parent_of_first)
        new_chain = new_chain[:idx + 1]   # drop displaced tips
    for bc, rec in new_branch:
        new_comms[bc] = rec
        new_chain.append(bc)
    new_head = new_chain[-1]
    return replace(state, committed_head=new_head,
                   committed_chain=tuple(new_chain),
                   commitments=new_comms,
                   lineage_head=new_comms[new_head]["postStateRoot"])
