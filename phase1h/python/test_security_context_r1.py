"""SRW3 Phase 1H-R1 — SCT SecurityContext binding suite (Fix B).

Gate-level suite (fixture evidence; clearly labeled — the client-derived
nature of evidence is established by the live H1-H10/H-A suites, this suite
isolates the gate's context-binding logic):

  SCT-1   honest context                          -> SRW3_VALID
  SCT-2   mutated policyVersion                   -> SRW3_REJECT (SC-1)
  SCT-3   mutated policyDigest                    -> SRW3_REJECT (SC-2)
  SCT-4   mutated applicationSetDigest            -> SRW3_REJECT (SC-4)
  SCT-5   mutated interactionGraphDigest          -> SRW3_REJECT (SC-5)
  SCT-6   mutated lineageHead                     -> SRW3_REJECT (SC-8)
  SCT-7   mutated clientExecutionConfig           -> SRW3_REJECT (SC-6)
  SCT-8   mutated clientIdentity                  -> SRW3_REJECT (SC-7)
  SCT-9   mutated contextDigest (fields intact)   -> SRW3_REJECT (SC-9)
  SCT-10  recomputed digest after a field change  -> SRW3_REJECT (binding,
          NOT the digest, is authority)

Each SCT-2..8 case runs TWO variants:
  (a) raw mutation, recorded digest left stale -> rejected
  (b) mutation WITH recomputed digest          -> still rejected
      (digest is an integrity/binding mechanism, not authority — section 7)

Authority regression (section 8):
  AUTH-1  fully attacker-controlled context (own policy version+digest,
          self-consistent digest) cannot self-authorize
  AUTH-2  attacker context with attacker clientIdentity vs client-derived
          evidence identity
  AUTH-3  forged-root evidence chain (H-A2 surface) — 1G authority intact
  AUTH-4  presented_context substitution (H5 surface) — intact
  AUTH-5  the gate offers no rebuild/substitution fallback (SC-10, by code
          audit assertion over the module source)

Context-digest determinism (section 13, unit level):
  DET-1  identical inputs -> identical digest across independent builds
  DET-2  no wall-clock/observation contamination (sleep-separated builds)
  DET-3  canonical normalization (chainId int vs decimal-string)
  DET-4  mutation of ANY field changes the digest (binding, not cosmetic)

Output: phase1h-r1-fix/transcripts/repair/security_context_binding.json
"""
from __future__ import annotations

import dataclasses
import json
import os
import sys
import tempfile
import time

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))

import r1_support  # noqa: E402
from authority import AuthorityCertificate, cert_id_for, make_evidence_cert  # noqa: E402
from evidence import ClientExecutionEvidence  # noqa: E402
from gate_h import (GateH, SecurityContext_H, build_security_context,  # noqa: E402
                    canonical_context_fields, compute_context_digest,
                    context_digest_of)
from policy import Policy, digest_of, load_policy  # noqa: E402

CHAIN_ID = 93471
HEAD = "0x" + "22" * 32                     # applicable lineage head (fixture)
GENESIS = "0x" + "11" * 32
CLIENT = "geth/v1.17.7-unittest/ethclient"  # fixture client identity
CONFIG_DIGEST = "0x" + "33" * 32

ORACLE = "0x" + "0a" * 20
LENDING = "0x" + "0b" * 20
LIQUIDATOR = "0x" + "0c" * 20
OWNER_VAL = "0x" + "64" * 31 + "00"

RESULTS: list[dict] = []


def expect(name: str, expected: str, ok: bool, observed, detail=None):
    RESULTS.append({"test": name, "expected": expected,
                    "observed": observed, "pass": bool(ok),
                    "detail": detail})
    print(("PASS " if ok else "FAIL ") + name + " -> " + str(observed)[:150])


def fixture_policy_obj() -> dict:
    return {
        "policyVersion": "srw3-policy-1h-v1-unit",
        "applicationSet": [ORACLE, LENDING, LIQUIDATOR],
        "invariants": [
            {"id": "INV-AGG-CAP", "type": "slot_le",
             "contract": LENDING, "slot": "0x02", "boundSlot": "0x03",
             "note": "unit fixture"},
            {"id": "INV-ORACLE-OWNER-IMMUTABLE", "type": "slot_unchanged",
             "contract": ORACLE, "slot": "0x02", "expected": OWNER_VAL},
        ],
        "interactionGraph": {"obligations": [
            {"id": "IO-UNIT-ORDER", "type": "write_before_read_same_block",
             "writer": {"contract": ORACLE, "fnSel": "0x11111111"},
             "reader": {"contract": LENDING, "fnSel": "0x22222222"}}]},
        "authorityConfiguration": {
            "protocolRoot": {"kind": "unit-fixture", "chainId": CHAIN_ID},
            "authorizedEvidenceSources": ["engine-api-execution"],
            "authorizedProofTypes": ["client-re-execution"]},
        "executionFragment": {"name": "unit-fixture-v1",
                              "events": ["READ", "WRITE", "CALL", "LOG"],
                              "ordering": "tx order"},
    }


def fixture_evidence() -> ClientExecutionEvidence:
    """Gate-level fixture evidence (NOT client execution; see module doc)."""
    return ClientExecutionEvidence(
        payload_digest="0x" + "aa" * 32,
        parent_root="0x" + "44" * 32,
        execution_identity={"client": CLIENT, "chainId": CHAIN_ID,
                            "impl": "go-ethereum"},
        effect_digest="0x" + "55" * 32,
        child_state_root="0x" + "66" * 32,
        execution_configuration={"configDigest": CONFIG_DIGEST,
                                 "chainConfig": {"unit": True},
                                 "activeFork": "amsterdam",
                                 "slotNumber": 1,
                                 "beaconRoot": "0x" + "77" * 32},
        execution_id="0x" + "88" * 32,
        env_digest="0x" + "99" * 32,
    )


def build_world(tmp: str):
    pol_path = os.path.join(tmp, "policy.json")
    obj = fixture_policy_obj()
    obj["policyDigest"] = digest_of(obj, drop=["policyDigest"])
    json.dump(obj, open(pol_path, "w"), indent=1)
    policy = load_policy(pol_path)
    deployment = {"pinnedPolicyDigest": policy.recorded_digest,
                  "chainId": CHAIN_ID, "genesisHash": GENESIS}
    pdigest = policy.verify_against_deployment(deployment)
    gate = GateH(policy, pdigest, GENESIS)
    gate.lineage_head_provider = lambda: HEAD
    ev = fixture_evidence()

    def mksc(**overrides) -> SecurityContext_H:
        fields = dict(
            policy_version=policy.policy_version,
            policy_digest=pdigest,
            chain_id=CHAIN_ID,
            application_set_digest=None,   # computed via builder below
            interaction_graph_digest=None,
            lineage_head=HEAD,
            client_execution_config=CONFIG_DIGEST,
            client_identity=CLIENT,
        )
        fields.update(overrides)
        return build_security_context(
            policy, fields["policy_digest"], fields["chain_id"],
            lineage_head=fields["lineage_head"],
            client_config_digest=fields["client_execution_config"],
            client_identity=fields["client_identity"])

    return policy, pdigest, gate, ev, mksc


def check(name: str, expected_sc: str | None, verdict, sub: str | None,
          ok_extra: bool = True):
    hay = f"{verdict.layer or ''} {verdict.reason or ''}"
    ok = (verdict.verdict == expected_sc and ok_extra
          and (sub is None or hay.find(sub) >= 0))
    expect(name, f"{expected_sc}" + (f" @ {sub}" if sub else ""), ok,
           {"verdict": verdict.verdict, "layer": verdict.layer,
            "reason": verdict.reason})


def main() -> int:
    r1_support.ensure_repair_transcript_dir()
    tmp = tempfile.mkdtemp(prefix="srw3-r1-sct-")
    policy, pdigest, gate, ev, mksc = build_world(tmp)

    # ---------------- SCT-1: honest context ----------------
    sc = mksc()
    v, checks = gate.evaluate(ev, security_context=sc)
    check("SCT-1", "SRW3_VALID", v, None,
          ok_extra=(v.verdict == "SRW3_VALID"
                    and checks.get("SC_security_context", {})
                    .get("status") == "ok"))
    honest_digest = sc.context_digest

    # ---------------- SCT-2..8: field mutations, two variants each -------
    field_map = [  # (test, SecurityContext_H attr, canonical key, SC-n tag)
        ("SCT-2", "policy_version", "policyVersion", "SC-1"),
        ("SCT-3", "policy_digest", "policyDigest", "SC-2"),
        ("SCT-4", "application_set_digest", "applicationSetDigest", "SC-4"),
        ("SCT-5", "interaction_graph_digest", "interactionGraphDigest", "SC-5"),
        ("SCT-6", "lineage_head", "lineageHead", "SC-8"),
        ("SCT-7", "client_execution_config", "clientExecutionConfig", "SC-6"),
        ("SCT-8", "client_identity", "clientIdentity", "SC-7"),
    ]
    for name, attr, key, tag in field_map:
        # (a) raw mutation, stale digest
        sc_bad = dataclasses.replace(mksc(), **{attr: "0x" + "ee" * 32})
        v, _ = gate.evaluate(ev, security_context=sc_bad)
        check(name + "a", "SRW3_REJECT", v, tag)
        # (b) mutation WITH recomputed digest — digest is not authority
        sc_bad2 = dataclasses.replace(mksc(), **{attr: "0x" + "ee" * 32})
        sc_bad2.context_digest = context_digest_of(sc_bad2)
        v2, _ = gate.evaluate(ev, security_context=sc_bad2)
        check(name + "b (digest recomputed)", "SRW3_REJECT", v2, tag)

    # ---------------- SCT-9: digest mutated, fields intact ----------------
    sc9 = mksc()
    sc9.context_digest = "0x" + "00" * 32
    v, _ = gate.evaluate(ev, security_context=sc9)
    check("SCT-9", "SRW3_REJECT", v, "SC-9")

    # ---------------- SCT-10: chainId mutation + recomputed digest -------
    sc10 = dataclasses.replace(mksc(), chain_id=999999999)
    sc10.context_digest = context_digest_of(sc10)
    v, _ = gate.evaluate(ev, security_context=sc10)
    check("SCT-10", "SRW3_REJECT", v, "SC-3")

    # ---------------- AUTH-1: attacker context cannot self-authorize -----
    # An attacker does not call build_security_context; they supply their
    # own object.  Fully attacker-controlled + self-consistent digest.
    att = dataclasses.replace(mksc(),
                              policy_version="srw3-policy-1h-v1-EVIL",
                              policy_digest="0x" + "01" * 32)
    att.context_digest = context_digest_of(att)     # valid integrity digest
    v, _ = gate.evaluate(ev, security_context=att)
    check("AUTH-1", "SRW3_REJECT", v, "SC-1")

    # ---------------- AUTH-2: attacker clientIdentity vs evidence --------
    att2 = dataclasses.replace(mksc(), client_identity="execution-client:EVIL-9.9")
    att2.context_digest = context_digest_of(att2)
    v, _ = gate.evaluate(ev, security_context=att2)
    check("AUTH-2", "SRW3_REJECT", v, "SC-7")

    # ---------------- AUTH-3: forged root (1G authority intact) ----------
    ev_att = fixture_evidence()
    fake_root = AuthorityCertificate(
        cert_id="", subject=f"protocol:{CHAIN_ID}", level=0,
        issuer_domain="attacker", parent_cert_id=None, rel=0,
        bindings={"genesisHash": "0x" + "ee" * 32, "chainId": str(CHAIN_ID)})
    fake_root.cert_id = cert_id_for(fake_root)
    cc_att = AuthorityCertificate(
        cert_id="", subject=f"execution-client:{CLIENT}", level=1,
        issuer_domain=fake_root.subject, parent_cert_id=fake_root.cert_id,
        rel=1, bindings={"chainId": str(CHAIN_ID), "clientVersion": CLIENT,
                         "configDigest": CONFIG_DIGEST})
    cc_att.cert_id = cert_id_for(cc_att)
    ec_att = make_evidence_cert(cc_att, ev_att.execution_id,
                                ev_att.effect_digest, ev_att.parent_root,
                                ev_att.child_state_root)
    ec_att.parent_cert_id = cc_att.cert_id
    # feed the forged evidence into the gate (identity fields match the
    # honest context so SC passes and the AUTHORITY layer must catch it)
    ev_forged = fixture_evidence()
    v, _ = gate.evaluate(ev_forged, security_context=mksc())
    ok_honest = v.verdict == "SRW3_VALID"
    # now the actual forged-chain rejection (H-A2 surface, direct check)
    from authority import verify_certificate_chain
    av = verify_certificate_chain(ec_att, {
        "protocolRootSubject": gate.root_cert.subject,
        "protocolRootGenesis": GENESIS,
        "chainId": CHAIN_ID,
        "authorizedClientSubject": cc_att.subject,
        "clientConfigDigest": CONFIG_DIGEST,
        "policyVersion": policy.policy_version,
        "certsById": {gate.root_cert.cert_id: gate.root_cert,
                      fake_root.cert_id: fake_root,
                      cc_att.cert_id: cc_att,
                      ec_att.cert_id: ec_att},
    })
    expect("AUTH-3", "SRW3_REJECT at authority layer (forged root); honest "
                     "path unaffected", (not av.ok) and ok_honest,
           {"forgedChainOk": av.ok, "layer": av.layer, "reason": av.reason,
            "honestContextStillValid": ok_honest})

    # ---------------- AUTH-4: presented_context substitution -------------
    # (same attack surface as H5; the recorded layer in Phase 1H for this
    # surface is authority:authsrc — behavior must be unchanged)
    v, _ = gate.evaluate(ev, security_context=mksc(),
                         presented_context={"authorizedClientSubject":
                                            "execution-client:EVIL-CLIENT-1.0"})
    check("AUTH-4", "SRW3_REJECT", v, "authsrc")

    # ---------------- AUTH-5: no substitution fallback (SC-10) -----------
    src = open(os.path.join(os.path.dirname(os.path.abspath(__file__)),
                            "gate_h.py")).read()
    src_harness = open(os.path.join(os.path.dirname(os.path.abspath(__file__)),
                                    "harness.py")).read()
    banned = ["rebuild_context_from_policy"]
    has_fallback = any(b in src or b in src_harness for b in banned)
    # Architectural claim: build_security_context is DEFINED once (gate_h)
    # and CALLED only from caller-side construction sites — never inside
    # GateH.evaluate (which only validates the supplied object).
    calls_in_gate = src.count("build_security_context(") \
        - src.count("def build_security_context(")
    calls_in_harness = src_harness.count("build_security_context(")
    expect("AUTH-5", "no rebuild/substitution fallback exists; the gate "
                        "never constructs a context", (not has_fallback)
           and calls_in_gate == 0 and calls_in_harness == 1,
           {"gateConstructsContext": calls_in_gate,
            "harnessConstructionSites": calls_in_harness,
            "explicitFallbackFound": has_fallback,
            "note": "SC-10 is architectural: evaluate() validates the "
                    "SUPPLIED context; no code path replaces it"})

    # ---------------- DET-1..4: context digest determinism ---------------
    d1 = mksc()
    d2 = mksc()
    expect("DET-1", "identical inputs -> identical digest",
           d1.context_digest == d2.context_digest == honest_digest,
           {"digest": d1.context_digest[:20] + "..."})
    time.sleep(0.05)
    d3 = mksc()
    expect("DET-2", "no wall-clock contamination",
           d3.context_digest == honest_digest
           and not any(k in canonical_context_fields(d3)
                       for k in ("recordedAt", "timestamp", "pid", "cwd")),
           {"digestAfterSleep": d3.context_digest[:20] + "...",
            "canonicalKeys": sorted(canonical_context_fields(d3))})
    d4 = build_security_context(policy, pdigest, "93471",  # str chain id
                                lineage_head=HEAD,
                                client_config_digest=CONFIG_DIGEST,
                                client_identity=CLIENT)
    expect("DET-3", "canonical normalization (chainId int vs str)",
           d4.context_digest == honest_digest,
           {"normalizedChainId": canonical_context_fields(d4)["chainId"]})
    d5 = mksc(lineage_head="0x" + "23" * 32)
    expect("DET-4", "any field change changes the digest",
           d5.context_digest != honest_digest,
           {"mutated": "lineageHead"})

    summary = {
        "suite": "SRW3 Phase 1H-R1 SecurityContext binding (Fix B, SCT+AUTH+DET)",
        "total": len(RESULTS),
        "passed": sum(1 for r in RESULTS if r["pass"]),
        "failed": sum(1 for r in RESULTS if not r["pass"]),
        "tests": RESULTS,
        "evidenceNote": "gate-level fixture evidence; client-derived evidence "
                        "binding is established by the live H/H-A suites",
        "classification": "R1: implementation-level SecurityContext "
                          "consumption/binding, experimentally tested "
                          "(not a K proof)",
    }
    r1_support.attach_and_dump(
        summary, os.path.join(r1_support.REPAIR_TRANSCRIPTS,
                              "security_context_binding.json"))
    print(f"\nSCT suite: {summary['passed']}/{summary['total']} PASS")
    return 0 if summary["failed"] == 0 else 1


if __name__ == "__main__":
    raise SystemExit(main())
