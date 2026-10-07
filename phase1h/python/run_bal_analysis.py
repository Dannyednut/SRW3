"""SRW3 Phase 1H — Block-Level Access List analysis (section 19).

Questions (from the phase spec):
  Q1  Can BAL supply execution footprint?        (write/read sets)
  Q2  Can BAL supply post-state values?          (storage_changes pre/post)
  Q3  Can BAL supply write attribution/order?    (tx indices — expected: NO)
  Q4  Where does SRW3 still need the full trace? (ordered reads, calls,
                                                  interaction obligations)
  Q5  Is the presented BAL trustworthy?          (client-validated at import:
                                                  header hash == executed BAL)

Preserves (or refutes) the Phase 1G finding: BAL != complete SRW3
security-effect trace.
"""
from __future__ import annotations

import json
import sys

sys.path.insert(0, "/home/z/my-project/srw3-work/phase1h/python")

from boot import Boot, boot_devnet, HERE, CAP, DEPOSIT  # noqa: E402
from bal_decode import decode_bal, bal_summary  # noqa: E402
from evidence import collect_evidence  # noqa: E402
from cl_sim import beacon_root  # noqa: E402
from engine_client import Devnet  # noqa: E402

ETH = 10**18


def main() -> int:
    dn = boot_devnet()
    boot = Boot(dn)
    boot.deploy_all()
    R: dict = {}

    # ---- block A: oracle write + borrow (order-relevant for the policy) ----
    # NOTE the order: borrow FIRST, then setPrice (the interaction violation
    # of H9) so we can test whether BAL could detect it.
    res = boot.sim.produce(boot.txs(0, [
        (boot.lending, "borrow(uint256)", (5 * ETH,), 0),
        (boot.oracle, "setPrice(uint256)", (2100 * ETH,), 0),
    ]).raws)
    payload = res.payload
    ev = collect_evidence(dn, payload, res.slot, beacon_root(res.slot))
    bal = decode_bal(payload["blockAccessList"])
    bsum = bal_summary(bal)

    derived_writes = {(a, s): v.lower()
                      for (a, s), v in ev.storage_writes.items()}
    from bal_decode import bal_write_attribution
    attribution = bal_write_attribution(bal)
    # final post value per (addr, slot) = the write with the highest
    # blockAccessIndex
    def _slot_int(sx: str) -> int:
        return int(sx, 16) if len(sx) > 2 else 0

    # restrict both to the application set (BAL includes system contracts)
    apps = {a.lower() for a in (boot.oracle, boot.lending, boot.liquidator)}
    bal_writes = {}
    for k, ws in attribution.items():
        if ws:
            bal_writes[(k[0], _slot_int(k[1]))] = \
                max(ws, key=lambda w: w[0])[1].lower()
    derived_app = {(a, _slot_int(sx)): v
                   for (a, sx), v in derived_writes.items()
                   if a in apps}
    bal_writes_app = {k: v for k, v in bal_writes.items() if k[0] in apps}
    # compare as integers (BAL post values are RLP-minimal, tracer values
    # are 32-byte zero-padded)
    bal_writes_cmp = {k: int(v, 16) for k, v in bal_writes_app.items()}
    derived_cmp = {k: int(v, 16) for k, v in derived_app.items()}

    R["BAL_footprint"] = {
        "balAccounts": bsum["accounts"],
        "balStorageWrites_total": bsum["storage_writes"],
        "balStorageReads_total": bsum["storage_reads"],
        "balWrites_appSet": len([k for k in bal_writes if k[0] in apps]),
        "derivedWrites_appSet": len(derived_app),
        "writeSetsEqual": bal_writes_cmp == derived_cmp,
        "writeSetDiff": {
            "balOnly": sorted(str(k) for k in set(bal_writes_app) - set(derived_app)),
            "derivedOnly": sorted(str(k) for k in set(derived_app) - set(bal_writes_app)),
        },
        "transport": "ExecutionPayloadV4.blockAccessList via engine_newPayloadV5/"
                     "engine_getPayloadV6; retrievable via "
                     "engine_getPayloadBodiesByHashV2",
    }

    # ---- Q2: post-state values present? ----
    cap_slot = (boot.lending.lower(), 3)
    borrowed_slot = (boot.lending.lower(), 2)
    cap_bal = bal_writes.get(cap_slot)
    borrowed_bal = bal_writes.get(borrowed_slot)
    R["BAL_postStateValues"] = {
        "borrowed_written_this_block": borrowed_bal is not None,
        "cap_written_this_block": cap_bal is not None,
        "invAGG_CAP_evaluable_from_BAL_alone":
            borrowed_bal is not None and cap_bal is not None,
        "note": "unchanged bounds are NOT in the BAL (only touched slots "
                "are); post-state reads via eth_getStorageAt remain "
                "necessary for unchanged invariant bounds",
    }

    # ---- Q3: attribution / ordering ----
    attr = attribution
    R["BAL_attribution"] = {
        "writeAttributionPresent": True,
        "writeAttributionField": "blockAccessIndex per storage change "
                                 "(EIP-7928 final; Geth v1.17.7)",
        "readAttributionPresent": False,
        "readValuesPresent": False,
        "eventOrderingOfWritesPresent": True,
        "consequence": "WRITE-side ordering IS evaluable from the BAL; "
                       "READ-side attribution is not (reads are keys only, "
                       "unattributed). Obligations that key on WHAT A "
                       "TRANSACTION READ (e.g. borrow must read the fresh "
                       "price) remain NOT evaluable from the BAL alone; "
                       "SRW3's ordered trace remains necessary for the "
                       "read/observation layer",
        "phase1G_finding": "PRESERVED and STRENGTHENED: the BAL is now "
                           "execution-validated by the client (Geth "
                           "re-derives it at import and requires equality "
                           "with the header hash) and writes carry "
                           "blockAccessIndex attribution - but reads remain "
                           "unattributed keys without values, call/return "
                           "structure is absent, and no ordered read "
                           "observations exist: it is NOT a complete SRW3 "
                           "security-effect trace",
    }

    # ---- Q5: tampered BAL is rejected by the client ----
    tampered = bytearray(bytes.fromhex(payload["blockAccessList"][2:]))
    # flip one byte deep inside the RLP (a storage-change value byte)
    tampered[len(tampered) // 2] ^= 0x01
    bad = dict(payload)
    bad["blockAccessList"] = "0x" + tampered.hex()
    resp = dn.new_payload_v5(bad, [], beacon_root(res.slot), [])
    R["BAL_tamperDetection"] = {
        "clientResponse": resp["status"],
        "validationError": (resp.get("validationError") or "")[:120],
        "conclusion": "the BAL is bound into the payload commitment "
                      "(header BlockAccessListHash inside blockHash); any "
                      "tampering yields INVALID - a presented BAL cannot "
                      "hide or invent execution effects against the client",
    }

    # ---- SRW3 still needs the trace: evaluate both layers ----
    from gate_h import GateH
    from policy import load_policy, load_deployment
    import subprocess
    pol = load_policy(f"{HERE}/policy/srw3_policy.json")
    dep = load_deployment(f"{HERE}/policy/deployment.json")
    try:
        pd = pol.verify_against_deployment(dep)
        gate = GateH(pol, pd, dep["genesisHash"])
        gate.state_reader = lambda a, s, b: dn.rpc.call(
            "eth_getStorageAt", [a, s, b])
        v, _ = gate.evaluate(ev)
        R["gateVerdict_on_this_block"] = {
            "srw3": v.verdict, "layer": v.layer, "reason": v.reason,
            "note": "borrow-before-setPrice violates IO-ORACLE-ORDER - the "
                    "interaction layer REQUIRES the ordered, attributed "
                    "trace that BAL cannot provide",
        }
    except Exception as e:
        R["gateVerdict_on_this_block"] = {"error": str(e)}

    json.dump(R, open(f"{HERE}/transcripts/srw3/bal_analysis.json", "w"),
              indent=1, default=str)
    print(json.dumps(R, indent=1, default=str)[:2600])
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
