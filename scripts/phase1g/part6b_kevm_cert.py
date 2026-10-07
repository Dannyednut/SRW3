#!/usr/bin/env python3
"""SRW3 Phase 1G — Part 6b: the KEVM-side authority certificate rebuilt in
Python and compared byte-for-byte with the REAL-run values (the dbg carrier
evm_authz_bytes + the commit run's linAzCertD).

Reconstruction inputs (all verified in prior phases):
  payload            = "BORROW1" (the 1F demo payload)
  caller             = LinAddrOf(LinDemoKey1) (the 1F #w3FCaller)
  declared/post/pre  = the 1F honest demo maps (FDeclHonest / post / empty pre)
  parentRoot         = AuthRootOf(union keys, PS)   (the #w3FParRoot formula)
  childRoot          = the 1F anchored state root (0a22556b...)
  effectD            = H(TraceBytes(FTraceHonest))  (the EXECUTION-derived
                       trace == the presented trace for the honest demo)
  rel/src/chain      = the adapter's Mode A certificate shape
"""
import re
import sys

sys.path.insert(0, "/home/z/my-project/srw3-kevm/python-gen")
sys.path.insert(0, "/home/z/my-project/srw3-kevm/phase1e/python")
sys.path.insert(0, "/home/z/my-project/srw3-kevm/phase1f/python")
sys.path.insert(0, "/home/z/my-project/srw3-kevm/phase1g/python")

from lin_verify import H, addr_of, canon_kv  # noqa: E402
from auth_model import auth_root, canon_union  # noqa: E402
from exec_model import (ExEvt, OP_WRITE, SCHED_CANCUN, SPEC_V1,  # noqa: E402
                        config_digest, env_digest, exec_id, payload_digest,
                        trace_digest)
from authz_model import (AuthzCert, AzSrc, AzStep, DOM_CONSENSUS,  # noqa: E402
                         DOM_EXECUTION, cert_body, cert_id, consensus_id,
                         exec_client_id)

ORACLE, LENDING, LIQ = 4097, 4098, 4099

PRE = {ORACLE: {}, LENDING: {}, LIQ: {}}
DECL = {ORACLE: {0: 100, 2: 100},
        LENDING: {0: 100, 1: 5, 2: 30, 3: 7},
        LIQ: {0: 4, 1: 100, 2: 40, 3: 7}}
POST = {ORACLE: {0: 100, 2: 100},
        LENDING: {0: 100, 1: 5, 2: 30, 3: 7},
        LIQ: {0: 4, 1: 100, 2: 40, 3: 7}}
TRACE = [ExEvt(OP_WRITE, ORACLE, 0, 100),
         ExEvt(OP_WRITE, ORACLE, 2, 100),
         ExEvt(OP_WRITE, LENDING, 0, 100),
         ExEvt(OP_WRITE, LENDING, 1, 5),
         ExEvt(OP_WRITE, LENDING, 2, 30),
         ExEvt(OP_WRITE, LENDING, 3, 7),
         ExEvt(OP_WRITE, LIQ, 0, 4),
         ExEvt(OP_WRITE, LIQ, 1, 100),
         ExEvt(OP_WRITE, LIQ, 2, 40),
         ExEvt(OP_WRITE, LIQ, 3, 7)]

PAYLOAD = bytes.fromhex("424f52524f5731")            # "BORROW1"
CALLER = addr_of((77).to_bytes(32, "big"))           # LinAddrOf(LinDemoKey1)
CHAIN = (1).to_bytes(4, "big")                       # #w3AzChainId
CHILD_ROOT = bytes.fromhex(
    "0a22556b9f074913e929db417297f15170204c20b3345e1888cf598d32b163c9")

# the dbg-carrier values from the REAL run
K_DBG = {
    "certid": "a36cfab41935f70b0c264c7f8342e1302792c8e3af870e25eaae1af0284b9fef",
    "effd": "4a3a1f19d18a750657752fac5f83501c52c1f9da8698198cc2be0ea99c5622b9",
    "presentd": "4a3a1f19d18a750657752fac5f83501c52c1f9da8698198cc2be0ea99c5622b9",
    "parentr": "42a6d8070aacb56999b6a65ff327023b23b5c3f10ad3be9607b1e00f44cb802e",
    "consensusid": "cd738dfda785ba3b3211f602a46db2f9e0888db2ba63ca4ecc43d13b2c9624e6",
    "execclientid": "e83c4e1b7f20f0ecbd8217152e844de99d91b9101efd210fa9e317bae8fec028",
}


def main():
    # the parent root per the #w3FParRoot formula (root over the union
    # universe evaluated at the PRE values)
    parent_root = auth_root(canon_union(PRE, DECL, POST), PRE)
    pd = payload_digest(PAYLOAD)
    cfgd = config_digest(SCHED_CANCUN, SPEC_V1)
    envd = env_digest(CALLER, 0)
    eid = exec_id(parent_root, pd, cfgd, envd)
    effd = trace_digest(TRACE)

    cert = AuthzCert(
        payload_d=pd, parent_root=parent_root, exec_id=eid,
        child_root=CHILD_ROOT, effect_d=effd, rel=2,
        src=AzSrc(DOM_EXECUTION, exec_client_id(CHAIN, cfgd), 1),
        chain=(AzStep(DOM_CONSENSUS, consensus_id(CHAIN), 0),),
        policy_v=1, proof_pub=b"")
    certd = cert_id(cert)

    pvals = {
        "certid": certd.hex(),
        "effd": effd.hex(),
        "presentd": trace_digest(TRACE).hex(),
        "parentr": parent_root.hex(),
        "consensusid": consensus_id(CHAIN).hex(),
        "execclientid": exec_client_id(CHAIN, cfgd).hex(),
    }

    lines = ["=== SRW3 Phase 1G — Part 6b: KEVM-SIDE AUTHORITY CERTIFICATE ===",
             "layers: Python rebuild <-> the REAL KEVM run (dbg carrier +",
             "        the commit run's linAzCertD)", ""]
    nok = 0
    for k in pvals:
        p, kv = pvals[k], K_DBG[k]
        ok = p == kv
        nok += ok
        lines.append(f"[{k}] python={p}")
        lines.append(f"[{k}] kevm  ={kv}")
        lines.append(f"[{k}] {'MATCH' if ok else '*** MISMATCH ***'}")
        lines.append("")
    # the commit run's carrier certD (correct unescape incl. \f)
    t = open("/tmp/kevm1g_evm_authz_commit.txt").read()
    m = re.search(r'linAzCertD:\s*b"((?:[^"\\]|\\.)*)"', t)
    raw = m.group(1)
    out = bytearray()
    i = 0
    while i < len(raw):
        c = raw[i]
        if c == "\\" and i + 1 < len(raw):
            n = raw[i + 1]
            mp = {"x": None, "n": 10, "t": 9, "f": 12, "r": 13, "\\": 92,
                  '"': 34}
            if n == "x":
                out.append(int(raw[i + 2:i + 4], 16)); i += 4; continue
            if n in mp:
                out.append(mp[n]); i += 2; continue
        out.append(ord(c)); i += 1
    carrier_hex = bytes(out).hex()
    ok = carrier_hex == pvals["certid"]
    nok += ok
    lines.append(f"[carrier-certd] kevm-commit={carrier_hex}")
    lines.append(f"[carrier-certd] python  ={pvals['certid']}")
    lines.append(f"[carrier-certd] {'MATCH' if ok else '*** MISMATCH ***'}")
    lines.append("")
    total = len(pvals) + 1
    lines.append(f"=== PART 6B: {nok}/{total} MATCH "
                 f"(Python rebuild <-> real KEVM run) ===")
    outp = "/home/z/my-project/srw3-kevm/phase1g/transcripts/part6b_kevm_cert.txt"
    open(outp, "w").write("\n".join(lines) + "\n")
    print("\n".join(lines))
    return 0 if nok == total else 1


if __name__ == "__main__":
    raise SystemExit(main())
