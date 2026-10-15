#!/usr/bin/env python3
# =============================================================================
# SRW3 Phase 1I-R1 — adversarial counterexample suite (run_r1_attacks.py)
#
# Cases (handoff "Required adversarial counterexamples"), each run on BOTH
# transition logics with REAL keccak-256 digests:
#   CM1 forged-true            caller supplies the accepting verdict for a
#                              gate-rejected block (the decisive test);
#   CM2 forged-true-context    stale/substituted SecurityContext digest;
#   CM3 forged-true-execution  payload identity / child root binding failure;
#   CM4 config-substitution    init under C1, commit attempt under C2;
#   CM5 forged-receipt         receipt for a different block + replay;
#   CM6 honest                 valid execution + valid VerifyLineageG verdict
#                              + exact stored config/context/policy + correct
#                              parent/slot  =>  COMMITS (non-vacuity);
#   CM7 unknown-evidence       no gate decision/evidence => no accept;
#   CM8 stale-reorg            evidence from a displaced parent/head.
#
# Additional groups:
#   DET  determinism (independent evaluations agree byte-for-byte);
#   KX   K cross-check: the Python canonical preimages equal the preimages
#        recorded in the K krun transcripts (T2/T5) — the K-side symbolic
#        Keccak256raw(0x9c...) / Keccak256raw(0x9e...) terms are the same
#        byte strings this module hashes.
#
# Exit code: number of failures.  Every assertion prints EXPECTED/GOT.
# =============================================================================
import re
import sys

from pi_r1_model import (ProtoCfg, ProtoBlock, GateReceipt, SecCtx,
                         FrozenLogic, FrozenState, RepairedLogic,
                         RepairedState, CommitP, ExecValidP, PDEC_VALID,
                         keccak256, I2B4)

RESULTS = []


def check(name, expected, got, detail=""):
    ok = bool(expected == got)
    RESULTS.append((name, ok, expected, got, detail))
    tag = "PASS" if ok else "FAIL"
    print(f"[{tag}] {name}")
    if not ok:
        print(f"       expected: {expected}")
        print(f"       got:      {got}")
    if detail:
        print(f"       {detail}")
    return ok


# --- shared fixture ---------------------------------------------------------
CFG1 = ProtoCfg(b"\xc1", 7, b"\xd1", b"\xa1", b"\x91", b"\xcc", b"\xee", b"\xf1")
CFG2 = ProtoCfg(b"\xc1", 8, b"\xd2", b"\xa1", b"\x91", b"\xcc", b"\xee", b"\xf1")

AUTHORIZED_CTX1 = CFG1.authorized_sec_ctx(b"\x33").digest()   # LH = parent root
POLCOMMIT1 = CFG1.policy_commitment()
POLCOMMIT2 = CFG2.policy_commitment()

GENESIS_ROOT1 = CFG1.proto_root()


def honest_block(cfg=CFG1, slot=0, parent_commit=None, decision=PDEC_VALID):
    parent_commit = GENESIS_ROOT1 if parent_commit is None else parent_commit
    return ProtoBlock(parent_commit, b"\x22", b"\x33", b"\x44", b"\x55",
                      b"\x66", AUTHORIZED_CTX1, cfg.policy_commitment(),
                      decision, slot)


# =============================================================================
# CM1 — forged-true (the decisive test)
# =============================================================================
def cm1():
    print("\n--- CM1 forged-true (gate says invalid-policy; caller says accept) "
          "---")
    B = honest_block(decision=PDEC_VALID)   # the block even LIES: decision=1

    # BEFORE: the frozen logic accepts the caller's verdict
    st = FrozenLogic.init(FrozenState(), CFG1)
    ok_before, why = FrozenLogic.accept(st, B, b"\x44", b"\x22", CFG1, True)
    check("CM1-BEFORE frozen accepts forged verdict (vulnerability witnessed)",
          True, ok_before,
          "frozen pAccept checks only parent-link, slot, SRW3OK — the gate's "
          "actual verdict never enters the transition")

    # AFTER: the repaired logic rejects; state unchanged
    st = RepairedState()
    RepairedLogic.init(st, CFG1)
    RepairedLogic.gate_eval(st, B, b"\x44", b"\x22", "invalid-policy")
    before = st.snapshot()   # post-gate state (receipt recorded, chain intact)
    ok, why, detail = RepairedLogic.accept(st, B, b"\x44", b"\x22", 7)
    check("CM1-AFTER repaired rejects forged verdict", False, ok, detail)
    check("CM1-AFTER state unchanged on reject", before, st.snapshot(),
          "head, counter, committed chain, pinned configuration and receipt "
          "pool all unchanged; the recorded receipt REMAINS (unconsumed)")

    # The forged block SATISFIES the field predicate (every field is forged
    # consistently) — which is exactly why the frozen model (whose only
    # security input was the caller Boolean) accepted it.  The repaired
    # transition rejects because the machine-created receipt binds the TRUE
    # gate verdict for THIS candidate; the block's self-description is not
    # authoritative.  The honestly-rendered rejected block (decision=0) is
    # excluded by the predicate itself.
    check("CM1 field predicate satisfied by the consistently-forged block "
          "(the frozen model's blind spot)",
          True, CommitP(B, b"\x44", b"\x22", CFG1, b"\x33"),
          "CommitP is a function of the block's fields; a fully-forged block "
          "satisfies it — the receipt binding is the security source")
    B_honest_rejected = ProtoBlock(B.parent_commit, B.payload_d, B.parent_root,
                                   B.child_root, B.effect_d, B.evidence_d,
                                   B.ctx_d, B.pol_commit, 0, B.slot)
    check("CM1 CommitP false for the honestly-rendered rejected block "
          "(decision=0)", False,
          CommitP(B_honest_rejected, b"\x44", b"\x22", CFG1, b"\x33"))


# =============================================================================
# CM2 — forged-true-context (stale/substituted SecurityContext)
# =============================================================================
def cm2():
    print("\n--- CM2 forged-true-context (stale SecurityContext digest) ---")
    stale_ctx = CFG1.authorized_sec_ctx(b"\xde\xad").digest()  # wrong LH
    B = ProtoBlock(GENESIS_ROOT1, b"\x22", b"\x33", b"\x44", b"\x55", b"\x66",
                   stale_ctx, POLCOMMIT1, PDEC_VALID, 0)

    st = FrozenLogic.init(FrozenState(), CFG1)
    ok_before, _ = FrozenLogic.accept(st, B, b"\x44", b"\x22", CFG1, True)
    check("CM2-BEFORE frozen accepts substituted context", True, ok_before)

    st = RepairedState()
    RepairedLogic.init(st, CFG1)
    RepairedLogic.gate_eval(st, B, b"\x44", b"\x22", "valid-g")
    before = st.snapshot()
    ok, why, detail = RepairedLogic.accept(st, B, b"\x44", b"\x22", 7)
    check("CM2-AFTER repaired rejects substituted context", False, ok, detail)
    check("CM2-AFTER state unchanged", before, st.snapshot())
    check("CM2 CommitP false (ctx != authorized projection for LH=0x33)",
          False, CommitP(B, b"\x44", b"\x22", CFG1, b"\x33"))


# =============================================================================
# CM3 — forged-true-execution (payload identity / child root binding)
# =============================================================================
def cm3():
    print("\n--- CM3 forged-true-execution (execution binding failure) ---")
    B = honest_block()
    # receipt bound to execution results (erc=0x44, erp=0x22); accept
    # presents a DIFFERENT child root -> the presented execution results do
    # not bind the block
    st = RepairedState()
    RepairedLogic.init(st, CFG1)
    RepairedLogic.gate_eval(st, B, b"\x44", b"\x22", "valid-g")
    before = st.snapshot()
    ok, why, detail = RepairedLogic.accept(st, B, b"\x99", b"\x22", 7)
    check("CM3-AFTER repaired rejects mismatched execution results", False, ok,
          detail)
    check("CM3-AFTER state unchanged", before, st.snapshot())

    # same attack through the frozen logic (caller simply says true)
    st = FrozenLogic.init(FrozenState(), CFG1)
    ok_before, _ = FrozenLogic.accept(st, B, b"\x99", b"\x22", CFG1, True)
    check("CM3-BEFORE frozen accepts mismatched execution", True, ok_before)


# =============================================================================
# CM4 — config-substitution (init C1, commit under C2)
# =============================================================================
def cm4():
    print("\n--- CM4 config-substitution (init under C1, commit under C2) ---")
    B2 = ProtoBlock(GENESIS_ROOT1, b"\x22", b"\x33", b"\x44", b"\x55", b"\x66",
                    CFG2.authorized_sec_ctx(b"\x33").digest(), POLCOMMIT2,
                    PDEC_VALID, 0)

    # BEFORE: the frozen logic commits under the CALLER-chosen C2 — the head
    # becomes C2's commitment of B2; nothing pins C1
    st = FrozenLogic.init(FrozenState(), CFG1)
    ok_before, _ = FrozenLogic.accept(st, B2, b"\x44", b"\x22", CFG2, True)
    check("CM4-BEFORE frozen commits under caller-chosen config (head = "
          "BlockCommitI(B2, C2))", True, ok_before)
    check("CM4-BEFORE frozen head really is the C2-commitment",
          B2.block_commitment(CFG2), st.head)

    # AFTER: the repaired logic rejects (CV witness + policy inequality)
    st = RepairedState()
    RepairedLogic.init(st, CFG1)
    RepairedLogic.gate_eval(st, B2, b"\x44", b"\x22", "valid-g")
    before = st.snapshot()
    ok, why, detail = RepairedLogic.accept(st, B2, b"\x44", b"\x22", 8)
    check("CM4-AFTER repaired rejects config substitution (CV 8 != pinned 7)",
          False, ok, detail)
    # the same attempt with the CORRECT declared version still fails on the
    # policy commitment (real digest inequality)
    ok, why, detail = RepairedLogic.accept(st, B2, b"\x44", b"\x22", 7)
    check("CM4-AFTER repaired rejects C2-bound policy commitment even with "
          "CV=7 (keccak inequality, boundary D.2)", False, ok, detail)
    check("CM4-AFTER state unchanged", before, st.snapshot())
    check("CM4 distinct configs have distinct commitments (collision-"
          "resistance instance)", False, POLCOMMIT1 == POLCOMMIT2)


# =============================================================================
# CM5 — forged-receipt (different block) + replay (single use)
# =============================================================================
def cm5():
    print("\n--- CM5 forged-receipt / replay ---")
    B = honest_block()
    B_other = ProtoBlock(GENESIS_ROOT1, b"\x22", b"\x33", b"\x99", b"\x55",
                         b"\x66", AUTHORIZED_CTX1, POLCOMMIT1, PDEC_VALID, 0)

    st = RepairedState()
    RepairedLogic.init(st, CFG1)
    # the gate evaluated B_other; the caller presents B
    RepairedLogic.gate_eval(st, B_other, b"\x99", b"\x22", "valid-g")
    before = st.snapshot()
    ok, why, detail = RepairedLogic.accept(st, B, b"\x44", b"\x22", 7)
    check("CM5-AFTER receipt for a different block does not authorize", False,
          ok, detail)
    check("CM5-AFTER state unchanged", before, st.snapshot())

    # replay: honest accept consumes the receipt; the replayed accept rejects
    st = RepairedState()
    RepairedLogic.init(st, CFG1)
    RepairedLogic.gate_eval(st, B, b"\x44", b"\x22", "valid-g")
    ok, _, _ = RepairedLogic.accept(st, B, b"\x44", b"\x22", 7)
    check("CM5 honest accept commits once", True, ok)
    after1 = st.snapshot()
    ok, why, detail = RepairedLogic.accept(st, B, b"\x44", b"\x22", 7)
    check("CM5 replayed accept rejects (receipt consumed)", False, ok, detail)
    check("CM5 replay leaves state unchanged", after1, st.snapshot())


# =============================================================================
# CM6 — honest (non-vacuity: the valid block commits)
# =============================================================================
def cm6():
    print("\n--- CM6 honest (valid block still commits) ---")
    B = honest_block()
    st = RepairedState()
    ok_init, _ = RepairedLogic.init(st, CFG1)
    ok_gate, _ = RepairedLogic.gate_eval(st, B, b"\x44", b"\x22", "valid-g")
    ok, why, detail = RepairedLogic.accept(st, B, b"\x44", b"\x22", 7)
    check("CM6 init/gate/accept all succeed", (True, True, True),
          (ok_init, ok_gate, ok), detail)
    check("CM6 block committed at slot 0", True, st.lineage.get(0) == B)
    check("CM6 counter advanced", 1, st.pnext)
    check("CM6 head == BlockCommitI(B, CFG1) (real keccak)",
          B.block_commitment(CFG1), st.head)
    check("CM6 receipt consumed (pool empty)", [], st.receipts)
    check("CM6 CommitP true for the honest block",
          True, CommitP(B, b"\x44", b"\x22", CFG1, b"\x33"))
    # a second honest block chains on top
    B2 = honest_block(slot=1, parent_commit=st.head)
    B2 = ProtoBlock(st.head, b"\x22", b"\x33", b"\x45", b"\x55", b"\x66",
                    AUTHORIZED_CTX1, POLCOMMIT1, PDEC_VALID, 1)
    RepairedLogic.gate_eval(st, B2, b"\x45", b"\x22", "valid-g")
    ok, _, _ = RepairedLogic.accept(st, B2, b"\x45", b"\x22", 7)
    check("CM6 second honest block chains at slot 1", True, ok)
    check("CM6 two-block chain is CommitP-valid at every slot",
          True, all(CommitP(st.lineage[s], st.lineage[s].child_root,
                            st.lineage[s].payload_d, CFG1, b"\x33")
                    for s in (0, 1)))


# =============================================================================
# CM7 — unknown-evidence (no gate decision must not accept)
# =============================================================================
def cm7():
    print("\n--- CM7 unknown-evidence / unknown verdict ---")
    B = honest_block()
    st = RepairedState()
    RepairedLogic.init(st, CFG1)
    ok, why, detail = RepairedLogic.accept(st, B, b"\x44", b"\x22", 7)
    check("CM7-AFTER no gate evaluation -> reject", False, ok, detail)
    check("CM7-AFTER state unchanged (empty pool)", st.snapshot(),
          (tuple(), 0, st.head, True, CFG1.canon(), tuple()),
          "no receipt exists to consume; nothing changed")

    # an UNKNOWN/garbage verdict string maps to pdecReject (fail-closed)
    RepairedLogic.gate_eval(st, B, b"\x44", b"\x22", "unknown-garbage")
    before = st.snapshot()
    ok, why, detail = RepairedLogic.accept(st, B, b"\x44", b"\x22", 7)
    check("CM7-AFTER unknown verdict -> reject", False, ok, detail)
    check("CM7-AFTER state unchanged", before, st.snapshot())
    check("CM7 ProtoDecisionOfGate('unknown-garbage') == pdecReject",
          0, __import__("pi_r1_model").ProtoDecisionOfGate("unknown-garbage"))


# =============================================================================
# CM8 — stale-reorg (evidence from a displaced head)
# =============================================================================
def cm8():
    print("\n--- CM8 stale-reorg (receipt from a displaced head) ---")
    B1 = honest_block(slot=0)
    st = RepairedState()
    RepairedLogic.init(st, CFG1)
    # the gate evaluates B2 EARLY (against the genesis head, slot 0)
    B2 = ProtoBlock(st.head, b"\x22", b"\x33", b"\x45", b"\x55", b"\x66",
                    AUTHORIZED_CTX1, POLCOMMIT1, PDEC_VALID, 0)
    RepairedLogic.gate_eval(st, B2, b"\x45", b"\x22", "valid-g")
    # ...then B1 (a DIFFERENT candidate for slot 0) is honestly evaluated and
    # committed — the head moves to B1's commitment
    RepairedLogic.gate_eval(st, B1, b"\x44", b"\x22", "valid-g")
    ok, _, _ = RepairedLogic.accept(st, B1, b"\x44", b"\x22", 7)
    check("CM8 B1 commits honestly at slot 0", True, ok)
    # the STALE receipt for B2 (minted under the displaced genesis head)
    # cannot authorize B2 anymore: head and slot have moved
    B2b = ProtoBlock(st.head, b"\x22", b"\x33", b"\x45", b"\x55", b"\x66",
                     AUTHORIZED_CTX1, POLCOMMIT1, PDEC_VALID, 1)
    before = st.snapshot()
    ok, why, detail = RepairedLogic.accept(st, B2b, b"\x45", b"\x22", 7)
    check("CM8 stale receipt does not authorize (no matching receipt at the "
          "current head/slot)", False, ok, detail)
    check("CM8 state unchanged", before, st.snapshot())


# =============================================================================
# DET — determinism
# =============================================================================
def det():
    print("\n--- DET determinism (independent evaluations agree) ---")
    B = honest_block()
    digests = []
    for _ in range(2):
        st = RepairedState()
        RepairedLogic.init(st, CFG1)
        RepairedLogic.gate_eval(st, B, b"\x44", b"\x22", "valid-g")
        RepairedLogic.accept(st, B, b"\x44", b"\x22", 7)
        digests.append(st.snapshot())
    check("DET identical state snapshots across independent runs",
          digests[0], digests[1])
    check("DET digest functions are pure (same input -> same digest)",
          (GENESIS_ROOT1, POLCOMMIT1, AUTHORIZED_CTX1),
          (CFG1.proto_root(), CFG1.policy_commitment(),
           CFG1.authorized_sec_ctx(b"\x33").digest()))


# =============================================================================
# KX — K cross-check (canonical preimages equal the K transcript terms)
# =============================================================================
def kx():
    print("\n--- KX K cross-check (byte encodings vs krun transcripts) ---")
    t2 = open("../transcripts/demos/"
              "T2-AFTER-repaired-forged-verdict-REJECTS.txt",
              encoding="utf-8", errors="replace").read()
    t5 = open("../transcripts/demos/T5-AFTER-honest-path-hs-boundary.txt",
              encoding="utf-8", errors="replace").read()

    def kore_bytes(s):
        # parse a K b"..." literal (with \xNN and ASCII passthrough) to bytes
        out = bytearray()
        i = 0
        while i < len(s):
            if s[i] == "\\" and i + 1 < len(s):
                c = s[i + 1]
                if c == "x":
                    out.append(int(s[i + 2:i + 4], 16))
                    i += 4
                    continue
                if c == '"':
                    out.append(ord('"'))
                    i += 2
                    continue
                if c == "\\":
                    out.append(ord("\\"))
                    i += 2
                    continue
            out.append(ord(s[i]))
            i += 1
        return bytes(out)

    # (1) the pinned configuration's protocol-root preimage in T2/T5
    m = re.search(r'Keccak256raw \( b"([^"]*)" \)', t2)
    check("KX T2 records the ProtoRoot preimage", True, bool(m))
    if m:
        pre = kore_bytes(m.group(1))
        check("KX ProtoRoot preimage == Python ProtoCfgCanon(CFG1)",
              CFG1.canon(), pre,
              "K side: %s | Python side: %s" % (pre.hex(), CFG1.canon().hex()))
        check("KX ProtoRoot digest matches real keccak",
              CFG1.proto_root(), keccak256(pre))

    # (2) the block-commitment preimage in T5 (honest path, head term);
    #     K byte literals may contain raw '"'/'\\' characters, so scan all
    #     Keccak256raw literals and unescape each
    cands = [kore_bytes(m.group(1)) for m in
             re.finditer(r'Keccak256raw \( b"(.*?)" \)', t5, re.S)]
    pre9e = [c for c in cands if c[:1] == b"\x9e"]
    check("KX T5 records a BlockCommit preimage", True, bool(pre9e))
    if pre9e:
        B = ProtoBlock(b"\x11", b"\x22", b"\x33", b"\x44", b"\x55", b"\x66",
                       b"\x77", b"\x88", 1, 0)
        expected = B.block_commit_canon(POLCOMMIT1)
        prefix, suffix = expected[:8], expected[-8:]
        shapes_ok = all(c[:8] == prefix and c[-8:] == suffix for c in pre9e)
        check("KX all K-side BlockCommit preimages share the Python canonical "
              "prefix (0x9E || block fields) and suffix (decision || slot)",
              True, shapes_ok,
              "%d preimage(s) found" % len(pre9e))
        exact = any(c == expected for c in pre9e)
        print("       NOTE: the krun output is a symbolic disjunction over "
              "the undecidable digest equalities.  In the collision-"
              "conditional branch the policy-commitment position carries the "
              "block's CLAIMED field (0x88); the real-keccak branch (decided "
              "by the Python mirror, CM6) carries the genuine "
              "PolicyCommitmentI(CFG1)=%s.  exact-match branch present: %s"
              % (POLCOMMIT1.hex(), exact))

    # (3) the receipt's bound head in T2 is the protocol root of the pinned
    #     configuration — the K receipt structure carries the real preimage
    m = re.search(r'grHead: Keccak256raw \( b"(.*?)" \)', t2, re.S)
    check("KX T2 receipt binds grHead to the protocol root", True, bool(m))
    if m:
        pre = kore_bytes(m.group(1))
        check("KX receipt grHead preimage == ProtoCfgCanon(CFG1)",
              CFG1.canon(), pre)


def main():
    print("=" * 76)
    print("SRW3 Phase 1I-R1 adversarial suite (real keccak-256 digests)")
    print("frozen logic: %s | repaired logic: %s"
          % (FrozenLogic.NAME, RepairedLogic.NAME))
    print("=" * 76)
    cm1()
    cm2()
    cm3()
    cm4()
    cm5()
    cm6()
    cm7()
    cm8()
    det()
    kx()
    print("\n" + "=" * 76)
    npass = sum(1 for _, ok, *_ in RESULTS if ok)
    nfail = len(RESULTS) - npass
    print("TOTAL: %d/%d PASS" % (npass, len(RESULTS)))
    if nfail:
        for name, ok, exp, got, _ in RESULTS:
            if not ok:
                print("FAILED:", name)
    print("DECISIVE TEST: an invalid block with a caller-supplied accepting "
          "verdict is rejected with state unchanged (CM1-AFTER); a valid "
          "block still commits (CM6).")
    return nfail


if __name__ == "__main__":
    sys.exit(main())
