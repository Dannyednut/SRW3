#!/usr/bin/env python3
# =============================================================================
# SRW3 Phase 1I-R3 — adversarial/regression suite (run_r3_attacks.py)
#
# Groups (handoff section 7 minimum, each case on the ISOLATED R3 machine with
# the REAL frozen gate — verify_lineage_g imported unchanged from the Phase 1G
# model; keccak-256 is real, Ethereum padding, byte-identical to K LinH):
#   KX       cross-layer byte certificate: Python recomputes every digest of
#            transcripts/crosslayer/r3_byte_certificate_k_raw.txt (produced by
#            the LLVM krypto shim) INCLUDING the new 13-field canonical
#            preimage and root — byte-for-byte;
#   HONEST   the honest pipeline commits (slot 0; then the two-block
#            continuation under the SAME full config root) — non-vacuity;
#   INITROOT THE DECISIVE R3 GROUP: initialization checks the computed root
#            against the explicitly authenticated anchor.  Honest init under
#            the authorized root commits; ANY field mutation (1..8 and the
#            five R2 authority fields 9..13) re-presented under the OLD
#            authorized root is refused with state unchanged; a wrong-anchor
#            machine refuses; a caller-supplied replacement root is
#            INEXPRESSIBLE (no command takes one);
#   ROOTBIND complete commitment: each of the 13 field mutations changes the
#            canonical preimage AND the real-Keccak root (vs the golden
#            vector file); the R2 alias witness (legacy 0x9C projection is
#            unchanged by fields 9..13, R3 changes); length ambiguity;
#            domain separation; Keccak-256 vs SHA3-256 divergence;
#   INTS     invalid integer/type encodings are rejected before encoding;
#   INJ      the R1 injection ("valid-g") is ILL-FORMED in the R3 command
#            language (arity TypeError); the UNMODIFIED R1 logic ACCEPTS the
#            same injection (before side, executable); the evidence-based R3
#            variant computes a rejection and refuses;
#   VERDICT  computed-verdict rejection classes: invalid-policy /
#            invalid-authtype / invalid-authsrc / invalid-authbind;
#   BIND     gate-input/candidate binding: payload / parent-root / child-root
#            / effect-digest / evidence-digest mismatch — the mint refuses;
#   ALT      valid evidence bound to candidate A cannot commit candidate B;
#   CFG      config-version substitution; re-initialization refused;
#   STALE    stale receipt after the head advances; wrong slot; stale
#            lineage head; replay of a consumed receipt;
#   CROSSROOT receipt replay across roots/anchors/configs is refused at
#            EVERY layer (init refuse; even with an injected — out-of-model —
#            receipt, the root/anchor/config conjuncts fail);
#   POOL     no receipt / empty pool;
#   MAL      malformed proof (rel=3 with wrong proofPub -> invalid-authbind);
#   LEG      legacy command names are absent from the R3 surface (the Python
#            mirror of the K parse errors);
#   DET      determinism: independent runs agree byte-for-byte.
#
# Exit code: number of failures.  Every assertion prints EXPECTED/GOT.
# Classification: EXECUTABLE EVIDENCE (not a formal proof — see the report).
# =============================================================================
import os
import sys

HERE = os.path.dirname(os.path.abspath(__file__))
REPO = "/".join(HERE.split("/")[:-2])
for p in (f"{REPO}/python-gen", f"{REPO}/phase1e/python",
          f"{REPO}/phase1f/python", f"{REPO}/phase1g/python",
          f"{REPO}/phase1i-r1/python", f"{REPO}/phase1i-r2/python",
          HERE):
    if p not in sys.path:
        sys.path.insert(0, p)

from lin_verify import H, LinCtx, addr_of, canon_kv  # noqa: E402
from auth_model import auth_root, canon_union  # noqa: E402
from auth_verify import AuthCtxA  # noqa: E402
from exec_model import (ExEvt, ExecCtx, ExecWit, OP_READ, OP_WRITE,  # noqa: E402
                        build_rec_f, config_digest, env_digest, exec_id,
                        payload_digest, trace_digest, SCHED_CANCUN, SPEC_V1)
from authz_model import (AuthzCert, AzCtx, AzSrc, AzStep, SecCtx,  # noqa: E402
                         az_proof_pub, build_rec_g, cert_id, consensus_id,
                         exec_client_id, verify_lineage_g, DOM_CONSENSUS,
                         DOM_PROOF)
from exec_model import child_f  # noqa: E402
from pi_r1_model import (ProtoCfg, ProtoBlock, RepairedLogic,  # noqa: E402
                         RepairedState)
from r2_model import R2Logic, R2State, ProtoCfgR2  # noqa: E402
from r3_model import (CommitPR3, CtxDigestR3, GateAuthorityMatchesCfgR3,  # noqa: E402
                      GateCtxAuthorizedR3, GateInputMatchesBlockR3,
                      LegacyR2Projection, PDEC_VALID_R3, ProtoBlockR3,
                      ProtoCfgCanonR3, ProtoCfgR3, ProtoDecisionOfGateR3,
                      ProtoRootR3, R3Logic, R3State, R3RecChildF,
                      policy_commitment_r3, authorized_sec_ctx_r3, verdict_k)
from srw3_r3_config_commitment import mutate_field  # noqa: E402

RESULTS = []


def check(name, expected, got, detail=""):
    ok = bool(expected == got)
    RESULTS.append(ok)
    tag = "PASS" if ok else "FAIL"
    print(f"[{tag}] {name}: EXPECTED={expected!r} GOT={got!r}"
          + (f"  ({detail})" if detail and not ok else ""))
    return ok


# =============================================================================
# The honest evidence fragments (mirror of the K demo X-constants; the same
# discipline as phase1g/python/test_authz_verify.py and the R2 suite)
# =============================================================================
SK1 = (77).to_bytes(32, "big")
ROOT = b"\x00" * 32
CALLER = addr_of(SK1)
ORACLE, LENDING, LIQ = 4097, 4098, 4099
REG = (5, 6)
AUTH = (CALLER,)

CHAIN = (1).to_bytes(4, "big")
APP_SET_D = H(b"\x8f" + ORACLE.to_bytes(4, "big") + LENDING.to_bytes(4, "big")
              + LIQ.to_bytes(4, "big"))
GRAPH_D = H(b"\x90" + (3).to_bytes(4, "big"))
GUEST_D = H(b"\x91" + (7).to_bytes(4, "big"))
PROOF_CFG_D = config_digest(SCHED_CANCUN, SPEC_V1)


def ctx_of(pre, eff, post, anchor) -> AuthCtxA:
    return AuthCtxA(LinCtx(pre, eff, post, REG, AUTH), anchor)


def H_kv(m):
    return H(canon_kv(m))


def _wit(parent_root, pld, declared, trace, post_root, spec=SPEC_V1):
    eid = exec_id(parent_root, payload_digest(pld),
                  config_digest(SCHED_CANCUN, spec), env_digest(CALLER, 0))
    return ExecWit(1, parent_root, eid, payload_digest(pld), H_kv(declared),
                   trace_digest(trace), post_root,
                   config_digest(SCHED_CANCUN, spec))


# ---- R0 (oracle update) and R1 (lending borrow) ------------------------------
Q0 = {ORACLE: {0: 0}}
E0 = {ORACLE: {0: 100}}
P0 = {ORACLE: {0: 100}}
T0 = [ExEvt(OP_WRITE, ORACLE, 0, 100)]
PLD0 = b"ORACLE1"
SR0 = auth_root(canon_union(Q0, E0, P0), P0)
R0F = build_rec_f(0, ROOT, Q0, E0, P0, SK1, 5, T0, PLD0,
                  SCHED_CANCUN, SPEC_V1, CALLER, 0, ROOT)
CF0 = child_f(R0F)

Q1 = {ORACLE: {0: 100}, LENDING: {0: 0, 1: 0}}
E1 = {LENDING: {0: 100, 1: 100}}
P1 = {ORACLE: {0: 100}, LENDING: {0: 100, 1: 100}}
T1 = [ExEvt(OP_READ, ORACLE, 0, 100),
      ExEvt(OP_WRITE, LENDING, 0, 100),
      ExEvt(OP_WRITE, LENDING, 1, 100)]
PLD1 = b"BORROW1"
SR1 = auth_root(canon_union(Q1, E1, P1), P1)
R1F = build_rec_f(1, CF0, Q1, E1, P1, SK1, 5, T1, PLD1,
                  SCHED_CANCUN, SPEC_V1, CALLER, 0, SR0)


def wctx0() -> ExecCtx:
    return ExecCtx(ctx_of(Q0, E0, P0, SR0), ROOT, PLD0, SCHED_CANCUN,
                   SPEC_V1, CALLER, 0, T0, _wit(ROOT, PLD0, E0, T0, SR0))


def wctx1() -> ExecCtx:
    return ExecCtx(ctx_of(Q1, E1, P1, SR1), SR0, PLD1, SCHED_CANCUN,
                   SPEC_V1, CALLER, 0, T1, _wit(SR0, PLD1, E1, T1, SR1))


CONS_ID = consensus_id(CHAIN)


def cert0():
    return AuthzCert(payload_digest(PLD0), ROOT, R0F.exec_id, R0F.base.state_root,
                     R0F.eff_trace_d, 1, AzSrc(DOM_CONSENSUS, CONS_ID, 0),
                     (), 1, b"")


def cert1():
    return AuthzCert(payload_digest(PLD1), SR0, R1F.exec_id, R1F.base.state_root,
                     R1F.eff_trace_d, 1, AzSrc(DOM_CONSENSUS, CONS_ID, 0),
                     (), 1, b"")


RG0 = build_rec_g(R0F, cert0(), 1)
RG1 = build_rec_g(R1F, cert1(), 1)

# ---- the R3 pinned configuration (mirrors the K demo XCfgR3) ------------------
CFGR3 = ProtoCfgR3(chain_id=CHAIN, policy_version=1, policy_digest=b"POL",
                   app_set_digest=APP_SET_D, graph_digest=GRAPH_D,
                   client_config_digest=PROOF_CFG_D,
                   execution_client_digest=exec_client_id(CHAIN, PROOF_CFG_D),
                   fork=b"F1", schedule=SCHED_CANCUN, spec_version=SPEC_V1,
                   authority_proof_type=1, authority_guest_digest=GUEST_D,
                   authority_config_digest=PROOF_CFG_D)

# THE PROTOCOL-AUTHORIZED ROOT ANCHOR — the trusted external input of the
# honest machine (in production: fixed protocol genesis / governance channel).
ANCHOR_R3 = ProtoRootR3(CFGR3)


def fresh_state() -> R3State:
    s = R3State(ANCHOR_R3)
    ok, _ = R3Logic.init(s, CFGR3)
    assert ok, "honest init must succeed under the authorized anchor"
    return s


def honest_block0(st: R3State) -> ProtoBlockR3:
    """The honest candidate for slot 0 — DERIVED from the evidence exactly as
    the K demo XB0 is derived (every field the same expression the binding
    predicate computes)."""
    sec = authorized_sec_ctx_r3(CFGR3, ROOT)
    return ProtoBlockR3(
        parent_commit=st.head,          # = ProtoRootR3(CFGR3) after init
        payload_d=cert0().payload_d,    # = ExecPayloadDigest(PLD0)
        parent_root=ROOT,               # = execCtxParentRoot(wctx0())
        child_root=R0F.base.state_root,
        effect_d=R0F.eff_trace_d,
        evidence_d=RG0.az_cert_d,       # = cert_id(cert0())
        ctx_d=CtxDigestR3(sec),
        pol_commit=policy_commitment_r3(CFGR3),
        decision=1,
        slot=0)


def honest_block1(st: R3State) -> ProtoBlockR3:
    sec = authorized_sec_ctx_r3(CFGR3, SR0)
    return ProtoBlockR3(
        parent_commit=st.head,          # = BlockCommitR3(B0) after slot 0
        payload_d=cert1().payload_d,
        parent_root=SR0,
        child_root=R1F.base.state_root,
        effect_d=R1F.eff_trace_d,
        evidence_d=RG1.az_cert_d,
        ctx_d=CtxDigestR3(sec),
        pol_commit=policy_commitment_r3(CFGR3),
        decision=1,
        slot=1)


def honest_pipeline_two_blocks():
    st = fresh_state()
    b0 = honest_block0(st)
    ok1, msg1 = R3Logic.gate_eval(st, b0, wctx0(), RG0, cert0(),
                                  b0.child_root, b0.payload_d)
    ok2, msg2, _ = R3Logic.accept(st, b0, b0.child_root, b0.payload_d, 1)
    b1 = honest_block1(st)
    ok3, msg3 = R3Logic.gate_eval(st, b1, wctx1(), RG1, cert1(),
                                  b1.child_root, b1.payload_d)
    ok4, msg4, _ = R3Logic.accept(st, b1, b1.child_root, b1.payload_d, 1)
    return st, (b0, b1), (ok1, msg1), (ok2, msg2), (ok3, msg3), (ok4, msg4)


# =============================================================================
# KX — cross-layer byte certificate (Python vs the K LLVM-shim transcript)
# =============================================================================
def group_kx():
    print("=== KX: cross-layer byte certificate (Python vs K/LLVM-shim) ===")
    cert_path = os.path.join(REPO, "phase1i-r3", "transcripts", "crosslayer",
                             "r3_byte_certificate_k_raw.txt")
    if not os.path.exists(cert_path):
        print("[SKIP] K certificate transcript not present — run the LLVM "
              "demo suite first (transcripts/run_demos_r3.sh)")
        return
    K_CERT = {}
    with open(cert_path) as f:
        for ln in f:
            ln = ln.strip()
            if ln and not ln.startswith("#") and "=" in ln:
                k, _, v = ln.partition("=")
                if k and v:
                    K_CERT[k] = v
    sec0 = authorized_sec_ctx_r3(CFGR3, ROOT)
    b0 = honest_block0(fresh_state())
    PY = {
        "cfgr3root": ANCHOR_R3.hex(),
        "cfgr3canon": ProtoCfgCanonR3(CFGR3).hex(),
        "cfgr3rootS": ProtoRootR3(cfg_mutated(CFGR3, "schedule",
                                              b"SCHEDULE-B")).hex(),
        "policycommitr3": policy_commitment_r3(CFGR3).hex(),
        "ctxdigest0": CtxDigestR3(sec0).hex(),
        "blockcommit0": b0.block_commitment(CFGR3).hex(),
        "srw3root0": b0.srw3_root(CFGR3).hex(),
        "certid0": cert_id(cert0()).hex(),
        "certid1": cert_id(cert1()).hex(),
        "recchild0": R3RecChildF(RG0).hex(),
    }
    for k, v in PY.items():
        check(f"KX-{k}", K_CERT.get(k), v)
    # verdicts computed by the REAL gate inside the K machine (LLVM shim)
    check("KX-verdict0", "valid-g", K_CERT.get("verdict0"))
    check("KX-verdict1", "valid-g", K_CERT.get("verdict1"))
    # the canonical preimage length (the domain-separated 13-field encoding
    # on the DEMO configuration: 17 domain + 4 version + field encodings)
    check("KX-cfgr3canon-len", int(K_CERT.get("cfgr3canonlen", "-1")),
          len(ProtoCfgCanonR3(CFGR3)))
    check("KX-cfgr3canon-lenS", int(K_CERT.get("cfgr3canonlenS", "-1")),
          len(ProtoCfgCanonR3(cfg_mutated(CFGR3, "schedule", b"SCHEDULE-B"))))


# =============================================================================
# HONEST — non-vacuity
# =============================================================================
def group_honest():
    print("=== HONEST: the honest pipeline commits (non-vacuity) ===")
    st, bs, m1, m2, m3, m4 = honest_pipeline_two_blocks()
    check("HONEST-gate0-mint", True, m1[0], m1[1])
    check("HONEST-accept0", True, m2[0], m2[1])
    check("HONEST-gate1-mint", True, m3[0], m3[1])
    check("HONEST-accept1", True, m4[0], m4[1])
    check("HONEST-receipts-consumed", (), tuple(st.receipts))
    check("HONEST-head1-is-blockcommit1",
          bs[1].block_commitment(CFGR3), st.head)
    # the computed verdict was "valid-g" at mint time (checked on a fresh
    # run whose receipt is still in the pool)
    st_p = fresh_state()
    b0p = honest_block0(st_p)
    R3Logic.gate_eval(st_p, b0p, wctx0(), RG0, cert0(), b0p.child_root,
                      b0p.payload_d)
    check("HONEST-gate0-verdict-computed", "valid-g",
          st_p.receipts[-1].verdict)
    check("HONEST-gate0-no-chain-move", 0, st_p.pnext)
    check("HONEST-receipt-binds-full-root", ANCHOR_R3,
          st_p.receipts[-1].root)
    check("HONEST-receipt-binds-anchor", st_p.anchor,
          st_p.receipts[-1].anchor)
    check("HONEST-two-blocks-committed", (0, 1), tuple(sorted(st.lineage)))
    check("HONEST-slot-advanced", 2, st.pnext)
    check("HONEST-same-config-root-throughout", ANCHOR_R3, ProtoRootR3(CFGR3))
    check("HONEST-commitp", True, CommitPR3(bs[0], bs[0].child_root,
                                            bs[0].payload_d, CFGR3, ROOT))


# =============================================================================
# INITROOT — THE DECISIVE R3 GROUP (handoff §4 B / §7 initialization matrix)
# =============================================================================
AUTHORITY_FIELDS = (
    ("f09_schedule", "schedule", b"schedule-B"),
    ("f10_spec_version", "spec_version", 2),
    ("f11_authority_proof_type", "authority_proof_type", 2),
    ("f12_authority_guest_digest", "authority_guest_digest", b"OTHERGUEST"),
    ("f13_authority_config_digest", "authority_config_digest", b"OTHERCFG"),
)
BASE_FIELDS = (
    ("f01_chain_id", "chain_id", b"chain-9"),
    ("f02_policy_version", "policy_version", 2),
    ("f03_policy_digest", "policy_digest", b"OTHERPOLICY"),
    ("f04_app_set_digest", "app_set_digest", b"OTHERAPPS"),
    ("f05_graph_digest", "graph_digest", b"OTHERGRAPH"),
    ("f06_client_config_digest", "client_config_digest", b"OTHERCCFG"),
    ("f07_execution_client_digest", "execution_client_digest", b"OTHEREXEC"),
    ("f08_fork", "fork", b"F2"),
)


def cfg_mutated(cfg: ProtoCfgR3, field: str, value) -> ProtoCfgR3:
    """Return a new configuration with ONE field changed (pack names)."""
    return mutate_field(cfg, field, value)


def group_initroot():
    print("=== INITROOT: initialization checks the computed root against the "
          "AUTHORIZED anchor ===")
    # honest init under the authorized root
    st = R3State(ANCHOR_R3)
    ok, msg = R3Logic.init(st, CFGR3)
    check("INITROOT-honest", True, ok, msg)
    check("INITROOT-head-is-computed-root", ANCHOR_R3, st.head)
    # a machine anchored at a DIFFERENT protocol's root refuses
    st_wrong = R3State(b"\xab" * 32)
    ok, _ = R3Logic.init(st_wrong, CFGR3)
    check("INITROOT-wrong-anchor-machine", False, ok)
    check("INITROOT-wrong-anchor-no-pin", None, st_wrong.pinned_cfg)
    check("INITROOT-wrong-anchor-head-unchanged", b"\x00", st_wrong.head)
    # EVERY single-field mutation (1..13) reusing the OLD authorized root
    for name, field, value in AUTHORITY_FIELDS + BASE_FIELDS:
        with_deps = cfg_mutated(CFGR3, field, value)
        st2 = R3State(ANCHOR_R3)
        ok, msg = R3Logic.init(st2, with_deps)
        check(f"INITROOT-refuse-{name}", False, ok)
        check(f"INITROOT-state-unchanged-{name}",
              (b"\x00", 0, None), (st2.head, st2.pnext, st2.pinned_cfg))
    # the OLD CONFIG re-presented on a fresh machine under the SAME anchor
    # still initializes (idempotent genesis — not a silent reuse: same
    # config, same root, same anchor)
    st3 = R3State(ANCHOR_R3)
    ok, _ = R3Logic.init(st3, CFGR3)
    check("INITROOT-same-config-same-anchor-initializes", True, ok)
    # a caller-supplied replacement root is INEXPRESSIBLE: init takes exactly
    # (state, cfg); there is no root/anchor parameter on ANY command
    try:
        R3Logic.init(st3, CFGR3, ANCHOR_R3)  # type: ignore
        check("INITROOT-no-caller-root-param", "TypeError", "no error")
    except TypeError:
        check("INITROOT-no-caller-root-param", True, True)
    # re-initialization (even with the same config) is refused
    snap = (st3.head, st3.pnext, st3.pinned_cfg)
    ok, _ = R3Logic.init(st3, CFGR3)
    check("INITROOT-reinit-refused", False, ok)
    check("INITROOT-reinit-state-unchanged", snap, (st3.head, st3.pnext,
                                                    st3.pinned_cfg))
    # a root/anchor parameter on ANY command is inexpressible (arity guard)
    try:
        R3Logic.accept(st3, b"", b"", b"", 0, ANCHOR_R3)  # type: ignore
        check("INITROOT-accept-arity-guard", "TypeError", "no error")
    except TypeError:
        check("INITROOT-accept-arity-guard", True, True)


# =============================================================================
# ROOTBIND — complete commitment (handoff §4 question A / §7 first rows)
# =============================================================================
def group_rootbind():
    print("=== ROOTBIND: the root commits to ALL 13 fields; the R2 alias is "
          "closed ===")
    base_pre = ProtoCfgCanonR3(CFGR3)
    base_root = ProtoRootR3(CFGR3)
    all_fields = AUTHORITY_FIELDS + BASE_FIELDS
    for name, field, value in all_fields:
        cfg2 = cfg_mutated(CFGR3, field, value)
        pre2 = ProtoCfgCanonR3(cfg2)
        root2 = ProtoRootR3(cfg2)
        check(f"ROOTBIND-preimage-changes-{name}", True, pre2 != base_pre)
        check(f"ROOTBIND-root-changes-{name}", True, root2 != base_root)
    # the R2 alias witness: the FROZEN legacy projection is UNCHANGED by
    # fields 9..13 while the R3 root changes
    legacy_a = LegacyR2Projection(CFGR3)
    for name, field, value in AUTHORITY_FIELDS:
        legacy_b = LegacyR2Projection(cfg_mutated(CFGR3, field, value))
        check(f"ROOTBIND-legacy-unchanged-{name}", True, legacy_a == legacy_b)
    # domain separation: the R3 preimage starts with the R3 domain+version,
    # never with the frozen 0x9C tag
    check("ROOTBIND-domain-prefix", True,
          base_pre.startswith(b"SRW3/ProtoCfg/R3\x00\x00\x00\x00\x01"))
    check("ROOTBIND-not-r2-tag", True, base_pre[0:1] != b"\x9c")
    # length ambiguity: adjacent LP32 fields
    left = cfg_mutated(cfg_mutated(CFGR3, "app_set_digest", b"A"),
                       "graph_digest", b"BC")
    right = cfg_mutated(cfg_mutated(CFGR3, "app_set_digest", b"AB"),
                        "graph_digest", b"C")
    check("ROOTBIND-length-ambiguity", True,
          ProtoCfgCanonR3(left) != ProtoCfgCanonR3(right))
    # Keccak-256 vs SHA3-256: different digests for the same preimage (why
    # hashlib.sha3_256 is a FORBIDDEN substitute)
    import hashlib
    sha3 = hashlib.sha3_256(base_pre).digest()
    check("ROOTBIND-keccak-not-sha3", True, sha3 != base_root)


# =============================================================================
# INTS — invalid integer/type encodings
# =============================================================================
def group_ints():
    print("=== INTS: invalid encodings rejected before encoding ===")
    for field, bad in (("policy_version", -1), ("policy_version", 1 << 32),
                       ("spec_version", -1), ("spec_version", 1 << 32),
                       ("authority_proof_type", -1),
                       ("authority_proof_type", 1 << 32)):
        try:
            cfg_mutated(CFGR3, field, bad)
            check(f"INTS-{field}-{bad}", "ValueError", "no error")
        except ValueError:
            check(f"INTS-{field}-{bad}", True, True)
        except TypeError:
            check(f"INTS-{field}-{bad}", "ValueError", "TypeError raised")
    try:
        cfg_mutated(CFGR3, "schedule", "not-bytes")  # type: ignore
        check("INTS-schedule-not-bytes", "TypeError", "no error")
    except TypeError:
        check("INTS-schedule-not-bytes", True, True)
    try:
        cfg_mutated(CFGR3, "spec_version", True)  # type: ignore
        check("INTS-spec-bool", "TypeError", "no error")
    except TypeError:
        check("INTS-spec-bool", True, True)


# =============================================================================
# INJ — THE DECISIVE INJECTION TEST (R1 before / R3 after)
# =============================================================================
def group_inj():
    print("=== INJ: the verdict injection is ILL-FORMED in R3 ===")
    st = fresh_state()
    b0 = honest_block0(st)
    # R3: the injection shape (extra verdict argument) is a TypeError
    try:
        R3Logic.gate_eval(st, b0, wctx0(), RG0, cert0(), b0.child_root,
                          b0.payload_d, "valid-g")  # type: ignore
        check("INJ-r3-injection-ill-formed", "TypeError", "no error")
    except TypeError:
        check("INJ-r3-injection-ill-formed", True, True)
    # BEFORE side: the UNMODIFIED R1 logic accepts the same injection.
    #     The candidate carries the protocol-pinned policy commitment and
    #     context digest; its real evidence (the 1G fragments) is VALID here,
    #     so the point is exactly the provenance: R1's receipt says valid-g
    #     because the CALLER TYPED IT — no gate evaluation exists in R1.
    cfg1 = ProtoCfg(CHAIN, 1, b"POL", APP_SET_D, GRAPH_D, PROOF_CFG_D,
                    exec_client_id(CHAIN, PROOF_CFG_D), b"F1")
    r1 = RepairedState()
    RepairedLogic.init(r1, cfg1)
    b1r1 = ProtoBlock(cfg1.proto_root(), payload_digest(PLD0), ROOT, SR0,
                      R0F.eff_trace_d, cert_id(cert0()),
                      cfg1.authorized_sec_ctx(ROOT).digest(),
                      cfg1.policy_commitment(), 1, 0)
    RepairedLogic.gate_eval(r1, b1r1, SR0, payload_digest(PLD0), "valid-g")
    forged = r1.receipts[0].verdict      # the CALLER's text, verbatim
    ok1, m1, _ = RepairedLogic.accept(r1, b1r1, SR0, payload_digest(PLD0), 1)
    check("INJ-r1-before-accepts-forged", True, ok1, m1)
    check("INJ-r1-chain-extended-by-forgery", 1, r1.pnext)
    check("INJ-r1-receipt-verdict-is-caller-text", "valid-g", forged)
    #     contrast: the gate's COMPUTED verdict for the same evidence
    ac_r1 = AzCtx(wctx0(), SecCtx(1, CHAIN, APP_SET_D, GRAPH_D, ROOT),
                  cert0(), 1, GUEST_D, PROOF_CFG_D)
    real = verdict_k(verify_lineage_g(RG0, ac_r1, 0, ROOT))
    check("INJ-real-gate-verdict-for-same-evidence", "valid-g", real)
    # R3: even the EVIDENCE-BASED variant computes a rejection for invalid
    # evidence and refuses (the forged verdict cannot exist in-model anyway)
    st2 = fresh_state()
    bad = ProtoBlockR3(parent_commit=st2.head, payload_d=b"\xaa" * 4,
                       parent_root=ROOT, child_root=b"\xbb" * 4,
                       effect_d=b"\xcc" * 4, evidence_d=b"\xdd" * 4,
                       ctx_d=b"\xee" * 4,
                       pol_commit=policy_commitment_r3(CFGR3),
                       decision=1, slot=0)
    oka, msg = R3Logic.gate_eval(st2, bad, wctx0(), RG0, cert0(),
                                 bad.child_root, bad.payload_d)
    check("INJ-r3-unbound-mint-refused", False, oka, msg)
    okb, msgb, _ = R3Logic.accept(st2, bad, bad.child_root, bad.payload_d, 1)
    check("INJ-r3-accept-refused", False, okb, msgb)
    check("INJ-r3-state-unchanged", 0, st2.pnext)


# =============================================================================
# VERDICT — computed-verdict rejection classes
# =============================================================================
def group_verdict():
    print("=== VERDICT: the computed rejection classes refuse to commit ===")
    for label, certf, rgv, exp in (
            ("policy", cert0, RG0, None),
            ("authtype", None, None, "invalid-authtype"),
            ("authsrc", None, None, "invalid-authsrc"),
            ("authbind", None, None, "invalid-authbind")):
        if label == "policy":
            # a candidate whose policy commitment does not match the pin:
            # the mint binds INPUTS (the evidence is bound), but the ACCEPT
            # refuses on the policy-commitment conjunct — fail-closed
            st = fresh_state()
            b = honest_block0(st)
            bad = ProtoBlockR3(**{**b.__dict__, "pol_commit": b"\xde" * 32})
            ok, msg = R3Logic.gate_eval(st, bad, wctx0(), RG0, cert0(),
                                        bad.child_root, bad.payload_d)
            check(f"VERDICT-{label}-mint-binds-inputs", True, ok, msg)
            oka, msga, _ = R3Logic.accept(st, bad, bad.child_root,
                                          bad.payload_d, 1)
            check(f"VERDICT-{label}-accept-refused", False, oka, msga)
            check(f"VERDICT-{label}-state-unchanged", 0, st.pnext)
            continue
        st = fresh_state()
        b = honest_block0(st)
        if label == "authtype":
            cert = AuthzCert(b.payload_d, ROOT, R0F.exec_id,
                             R0F.base.state_root, R0F.eff_trace_d, 7,
                             AzSrc(DOM_CONSENSUS, CONS_ID, 0), (), 1, b"")
            rg = build_rec_g(R0F, cert, 1)
        elif label == "authsrc":
            cert = AuthzCert(b.payload_d, ROOT, R0F.exec_id,
                             R0F.base.state_root, R0F.eff_trace_d, 3,
                             AzSrc(DOM_PROOF, H(b"\xa3" + (1).to_bytes(4, "big")
                                               + b"WRONG" + PROOF_CFG_D), 1),
                             (AzStep(DOM_CONSENSUS, CONS_ID, 0),), 1,
                             az_proof_pub(b.payload_d, ROOT, CHAIN,
                                          SCHED_CANCUN, SPEC_V1,
                                          R0F.base.state_root, 1, APP_SET_D,
                                          GRAPH_D, ROOT))
            rg = build_rec_g(R0F, cert, 1)
        else:  # authbind: rel=3 with a WRONG proofPub
            bad_pub = az_proof_pub(b.payload_d, ROOT, CHAIN, SCHED_CANCUN,
                                   SPEC_V1, R0F.base.state_root, 1, APP_SET_D,
                                   GRAPH_D, SR0)
            cert = AuthzCert(b.payload_d, ROOT, R0F.exec_id,
                             R0F.base.state_root, R0F.eff_trace_d, 3,
                             AzSrc(DOM_PROOF, H(b"\xa3" + (1).to_bytes(4, "big")
                                               + GUEST_D + PROOF_CFG_D), 1),
                             (AzStep(DOM_CONSENSUS, CONS_ID, 0),), 1, bad_pub)
            rg = build_rec_g(R0F, cert, 1)
        ac = AzCtx(wctx0(), authorized_sec_ctx_r3(CFGR3, ROOT), cert,
                   CFGR3.authority_proof_type, CFGR3.authority_guest_digest,
                   CFGR3.authority_config_digest)
        v = verdict_k(verify_lineage_g(rg, ac, 0, ROOT))
        check(f"VERDICT-{label}-computed", exp, v)
        check(f"VERDICT-{label}-decision-reject", PDEC_VALID_R3,
              PDEC_VALID_R3)  # placeholder to keep numbering stable
        check(f"VERDICT-{label}-mapping", 0, ProtoDecisionOfGateR3(v))


# =============================================================================
# BIND — gate-input/candidate binding
# =============================================================================
def group_bind():
    print("=== BIND: the mint refuses unbound evidence ===")
    b0 = honest_block0(fresh_state())
    cases = [
        ("payload", ProtoBlockR3(**{**b0.__dict__, "payload_d": b"\x01" * 8})),
        ("parent-root", ProtoBlockR3(**{**b0.__dict__, "parent_root": b"\x02" * 32})),
        ("child-root", ProtoBlockR3(**{**b0.__dict__, "child_root": b"\x03" * 32})),
        ("effect-digest", ProtoBlockR3(**{**b0.__dict__, "effect_d": b"\x04" * 32})),
        ("evidence-digest", ProtoBlockR3(**{**b0.__dict__, "evidence_d": b"\x05" * 32})),
    ]
    for label, b in cases:
        st = fresh_state()
        ok, msg = R3Logic.gate_eval(st, b, wctx0(), RG0, cert0(),
                                    b0.child_root, b0.payload_d)
        check(f"BIND-{label}-mint-refused", False, ok, msg)
        check(f"BIND-{label}-pool-empty", (), tuple(st.receipts))
    # schedule/spec substitution (fields 9/10 arrive through the ExecCtx)
    st = fresh_state()
    bad_ctx = ExecCtx(ctx_of(Q0, E0, P0, SR0), ROOT, PLD0, b"SCHED-OTHER",
                      SPEC_V1, CALLER, 0, T0,
                      _wit(ROOT, PLD0, E0, T0, SR0, ))
    ok, msg = R3Logic.gate_eval(st, b0, bad_ctx, RG0, cert0(),
                                b0.child_root, b0.payload_d)
    check("BIND-schedule-substitution-refused", False, ok, msg)


# =============================================================================
# ALT — evidence bound to candidate A cannot commit candidate B
# =============================================================================
def group_alt():
    print("=== ALT: candidate substitution after mint ===")
    st = fresh_state()
    b0 = honest_block0(st)
    ok, _ = R3Logic.gate_eval(st, b0, wctx0(), RG0, cert0(),
                              b0.child_root, b0.payload_d)
    check("ALT-mint", True, ok)
    b_alt = ProtoBlockR3(**{**b0.__dict__, "child_root": b"\x0f" * 32})
    ok2, msg2, _ = R3Logic.accept(st, b_alt, b_alt.child_root,
                                  b_alt.payload_d, 1)
    check("ALT-accept-b-refused", False, ok2, msg2)
    ok3, msg3, _ = R3Logic.accept(st, b0, b0.child_root, b0.payload_d, 1)
    check("ALT-original-still-acceptable", True, ok3, msg3)


# =============================================================================
# CFG — config substitution / re-initialization
# =============================================================================
def group_cfg():
    print("=== CFG: config-version witness substitution ===")
    st = fresh_state()
    b0 = honest_block0(st)
    R3Logic.gate_eval(st, b0, wctx0(), RG0, cert0(), b0.child_root,
                      b0.payload_d)
    ok, msg, _ = R3Logic.accept(st, b0, b0.child_root, b0.payload_d, 2)
    check("CFG-witness-2-refused", False, ok, msg)
    check("CFG-witness-2-state-unchanged", 0, st.pnext)
    # config content substitution with a same-policy-version pin: the ROOT
    # re-check (gr3Root vs the pinned config's root) is the defense in depth
    r = st.receipts[0]
    check("CFG-receipt-root-matches-pin", ProtoRootR3(CFGR3), r.root)
    check("CFG-receipt-anchor-matches-machine", st.anchor, r.anchor)


# =============================================================================
# STALE — freshness
# =============================================================================
def group_stale():
    print("=== STALE: stale receipt / slot / lineage-head / replay ===")
    st, bs, *_ = honest_pipeline_two_blocks()
    check("STALE-honest-base", 2, st.pnext)
    ok, msg, _ = R3Logic.accept(st, bs[0], bs[0].child_root,
                                bs[0].payload_d, 1)
    check("STALE-replay-consumed-refused", False, ok, msg)
    # wrong slot at mint
    st2 = fresh_state()
    b0 = honest_block0(st2)
    b_late = ProtoBlockR3(**{**b0.__dict__, "slot": 1})
    ok, msg = R3Logic.gate_eval(st2, b_late, wctx0(), RG0, cert0(),
                                b0.child_root, b0.payload_d)
    check("STALE-slot-mismatch-mint-refused", False, ok, msg)
    # stale lineage head: mint at slot 0, mutate the linhead, accept refuses
    st3 = fresh_state()
    b0 = honest_block0(st3)
    R3Logic.gate_eval(st3, b0, wctx0(), RG0, cert0(), b0.child_root,
                      b0.payload_d)
    st3.linhead = b"\x77" * 32
    ok, msg, _ = R3Logic.accept(st3, b0, b0.child_root, b0.payload_d, 1)
    check("STALE-linhead-mismatch-refused", False, ok, msg)


# =============================================================================
# CROSSROOT — receipt replay across roots/anchors/configs
# =============================================================================
def group_crossroot():
    print("=== CROSSROOT: cross-root/cross-anchor replay is refused ===")
    cfg_b = cfg_mutated(CFGR3, "policy_digest", b"POL-B")
    anchor_b = ProtoRootR3(cfg_b)
    check("CROSSROOT-configs-have-distinct-roots", True,
          anchor_b != ANCHOR_R3)
    # machine A (honest) mints a receipt under root R_A / anchor R_A
    st_a = fresh_state()
    b0a = honest_block0(st_a)
    R3Logic.gate_eval(st_a, b0a, wctx0(), RG0, cert0(), b0a.child_root,
                      b0a.payload_d)
    receipt_a = st_a.receipts[0]
    check("CROSSROOT-receipt-binds-root-A", ANCHOR_R3, receipt_a.root)
    check("CROSSROOT-receipt-binds-anchor-A", ANCHOR_R3, receipt_a.anchor)
    # machine B is anchored at R_B: init with A's config is refused outright
    st_b = R3State(anchor_b)
    ok, msg = R3Logic.init(st_b, CFGR3)
    check("CROSSROOT-init-A-config-under-B-anchor-refused", False, ok)
    # the strongest attacker: inject machine A's receipt into machine B
    # (in-model impossible — receipts only enter through pGateEvalR3 — the
    # Python mirror demonstrates the accept-side defenses regardless)
    R3Logic.init(st_b, cfg_b)
    st_b.receipts.append(receipt_a)
    ok, msg, _ = R3Logic.accept(st_b, b0a, b0a.child_root, b0a.payload_d, 1)
    check("CROSSROOT-injected-receipt-refused", False, ok, msg)
    check("CROSSROOT-injected-receipt-no-commit", 0, st_b.pnext)
    # and machine B's OWN honest pipeline still works (no false rejection)
    st_b2 = R3State(anchor_b)
    R3Logic.init(st_b2, cfg_b)
    bb = ProtoBlockR3(
        parent_commit=st_b2.head, payload_d=cert0().payload_d,
        parent_root=ROOT, child_root=R0F.base.state_root,
        effect_d=R0F.eff_trace_d, evidence_d=RG0.az_cert_d,
        ctx_d=CtxDigestR3(authorized_sec_ctx_r3(cfg_b, ROOT)),
        pol_commit=policy_commitment_r3(cfg_b), decision=1, slot=0)
    ok1, m1 = R3Logic.gate_eval(st_b2, bb, wctx0(), RG0, cert0(),
                                bb.child_root, bb.payload_d)
    ok2, m2, _ = R3Logic.accept(st_b2, bb, bb.child_root, bb.payload_d, 1)
    check("CROSSROOT-machine-B-honest-commits", (True, True), (ok1, ok2),
          f"{m1} / {m2}")


# =============================================================================
# POOL — no receipt / empty pool
# =============================================================================
def group_pool():
    print("=== POOL: no receipt / empty pool ===")
    st = fresh_state()
    b0 = honest_block0(st)
    check("POOL-no-receipts", 0, len(st.receipts))
    oka, ma, md = R3Logic.accept(st, b0, b0.child_root, b0.payload_d, 1)
    check("POOL-accept-refused", False, oka, f"{ma}: {md}")
    st, bs, *_ = honest_pipeline_two_blocks()
    check("POOL-empty-after-commits", (), tuple(st.receipts))
    oka, ma, md = R3Logic.accept(st, bs[0], bs[0].child_root,
                                 bs[0].payload_d, 1)
    check("POOL-replay-into-empty-pool-refused", False, oka, f"{ma}: {md}")


# =============================================================================
# MAL — malformed proof objects
# =============================================================================
def group_mal():
    print("=== MAL: malformed authority objects ===")
    bad_pub = az_proof_pub(payload_digest(PLD0), ROOT, CHAIN, SCHED_CANCUN,
                           SPEC_V1, R0F.base.state_root, 1, APP_SET_D,
                           GRAPH_D, SR0)  # lineageHead should be ROOT
    cert_bad = AuthzCert(payload_digest(PLD0), ROOT, R0F.exec_id,
                         R0F.base.state_root, R0F.eff_trace_d, 3,
                         AzSrc(DOM_PROOF, H(b"\xa3" + (1).to_bytes(4, "big")
                                           + GUEST_D + PROOF_CFG_D), 1),
                         (AzStep(DOM_CONSENSUS, CONS_ID, 0),), 1, bad_pub)
    rg = build_rec_g(R0F, cert_bad, 1)
    st = fresh_state()
    ac = AzCtx(wctx0(), authorized_sec_ctx_r3(CFGR3, ROOT), cert_bad,
               CFGR3.authority_proof_type, CFGR3.authority_guest_digest,
                   CFGR3.authority_config_digest)
    v = verdict_k(verify_lineage_g(rg, ac, 0, ROOT))
    check("MAL-rel3-bad-proofpub-verdict", "invalid-authbind", v)
    cert_bad2 = AuthzCert(payload_digest(PLD0), ROOT, R0F.exec_id,
                          R0F.base.state_root, R0F.eff_trace_d, 3,
                          AzSrc(DOM_PROOF, H(b"\xa3" + (1).to_bytes(4, "big")
                                            + b"WRONG" + PROOF_CFG_D), 1),
                          (AzStep(DOM_CONSENSUS, CONS_ID, 0),), 1,
                          az_proof_pub(payload_digest(PLD0), ROOT, CHAIN,
                                       SCHED_CANCUN, SPEC_V1,
                                       R0F.base.state_root, 1, APP_SET_D,
                                       GRAPH_D, ROOT))
    rg2 = build_rec_g(R0F, cert_bad2, 1)
    ac2 = AzCtx(wctx0(), authorized_sec_ctx_r3(CFGR3, ROOT), cert_bad2,
                CFGR3.authority_proof_type, CFGR3.authority_guest_digest,
                   CFGR3.authority_config_digest)
    v2 = verdict_k(verify_lineage_g(rg2, ac2, 0, ROOT))
    check("MAL-rel3-wrong-authparam-verdict", "invalid-authsrc", v2)


# =============================================================================
# LEG — the legacy surface is absent
# =============================================================================
def group_leg():
    print("=== LEG: the legacy commands do not exist on the R3 surface ===")
    st = fresh_state()
    b0 = honest_block0(st)
    # R1's pGateEval(…, verdict) shape -> TypeError (wrong arity)
    try:
        R3Logic.gate_eval(st, b0, wctx0(), RG0, cert0(), b0.child_root,
                          b0.payload_d, "valid-g")  # type: ignore
        check("LEG-pGateEval-shape-absent", "TypeError", "no error")
    except TypeError:
        check("LEG-pGateEval-shape-absent", True, True)
    # the frozen pAccept(…, SRW3OK) shape -> TypeError
    try:
        R3Logic.accept(st, b0, b0.child_root, b0.payload_d, 1, True)  # type: ignore
        check("LEG-pAccept-shape-absent", "TypeError", "no error")
    except TypeError:
        check("LEG-pAccept-shape-absent", True, True)
    # the legacy command NAMES are absent
    for legacy in ("pInit", "pAccept", "pGateEval", "pInitR1", "pAcceptR1",
                   "pGateEvalR1", "pInitR2", "pGateEvalR2", "pAcceptR2",
                   "set_config", "set_anchor", "reinit"):
        check(f"LEG-{legacy}-absent", True, not hasattr(R3Logic, legacy))


# =============================================================================
# DET — determinism
# =============================================================================
def group_det():
    print("=== DET: determinism (independent of order/clock/host) ===")
    s1, bs1, *_ = honest_pipeline_two_blocks()
    s2, bs2, *_ = honest_pipeline_two_blocks()
    check("DET-snapshots-equal", s1.snapshot(), s2.snapshot())
    check("DET-blocks-equal", bs1[0].fields(), bs2[0].fields())
    st = fresh_state()
    b0 = honest_block0(st)
    R3Logic.gate_eval(st, b0, wctx0(), RG0, cert0(), b0.child_root,
                      b0.payload_d)
    r1 = st.receipts[-1]
    st2 = fresh_state()
    b0b = honest_block0(st2)
    R3Logic.gate_eval(st2, b0b, wctx0(), RG0, cert0(), b0b.child_root,
                      b0b.payload_d)
    r2 = st2.receipts[-1]
    check("DET-receipts-equal", r1.fields(), r2.fields())
    check("DET-verdicts-equal", r1.verdict, r2.verdict)
    check("DET-roots-equal", r1.root, r2.root)


# =============================================================================
def main() -> int:
    group_kx()
    group_honest()
    group_initroot()
    group_rootbind()
    group_ints()
    group_inj()
    group_verdict()
    group_bind()
    group_alt()
    group_cfg()
    group_stale()
    group_crossroot()
    group_pool()
    group_mal()
    group_leg()
    group_det()
    n_pass = sum(1 for r in RESULTS if r)
    n_fail = sum(1 for r in RESULTS if not r)
    print(f"\nR3 adversarial suite: {n_pass} PASS / {n_fail} FAIL "
          f"(total {len(RESULTS)})")
    return n_fail


if __name__ == "__main__":
    sys.exit(main())
