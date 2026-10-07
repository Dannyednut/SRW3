#!/usr/bin/env python3
"""SRW3 Phase 1G — cross-layer byte consistency (Part 6).

Compares the AUTHORITY-layer byte certificate across Python <-> K-abstract
(llvm, real krypto):
  certbody0, certid0, consensusid, execclientid, proofsysid, policyauthid,
  proofpub3, childg0, canoncoreg0, bal3canon
The K values are recorded verbatim by part4 (xbytes) into
transcripts/part4_xbytes_raw.txt; this script recomputes the Python
reference (phase1g/python) and asserts byte equality.
"""
import re
import sys

sys.path.insert(0, "/home/z/my-project/srw3-kevm/python-gen")
sys.path.insert(0, "/home/z/my-project/srw3-kevm/phase1e/python")
sys.path.insert(0, "/home/z/my-project/srw3-kevm/phase1f/python")
sys.path.insert(0, "/home/z/my-project/srw3-kevm/phase1g/python")

RAW = "/home/z/my-project/srw3-kevm/phase1g/transcripts/part4_xbytes_raw.txt"
OUT = "/home/z/my-project/srw3-kevm/phase1g/transcripts/part6_crosslayer_bytes.txt"


def kvals_from_raw():
    t = open(RAW).read()
    m = re.search(r'"([^"]*)"', t)
    kv = {}
    for pair in m.group(1).split(","):
        k, _, v = pair.partition("=")
        kv[k] = v
    return kv


def pvals():
    import test_authz_verify as T
    from authz_model import (canon_core_g, cert_body, cert_id, child_g,
                             consensus_id, exec_client_id, policy_auth_id,
                             proof_sys_id, bal_canon)
    return {
        "certbody0": cert_body(T.cert0()).hex(),
        "certid0": cert_id(T.cert0()).hex(),
        "consensusid": T.CONS_ID.hex(),
        "execclientid": T.EXEC_ID_AUTH.hex(),
        "proofsysid": T.PROOF_ID_AUTH.hex(),
        "policyauthid": policy_auth_id(1).hex(),
        "proofpub3": T.cert3().proof_pub.hex(),
        "childg0": child_g(T.R0F, cert_id(T.cert0()), 1).hex(),
        "canoncoreg0": canon_core_g(T.R0F, cert_id(T.cert0()), 1).hex(),
        "bal3canon": bal_canon(T.BAL3).hex(),
    }


def main():
    kv = kvals_from_raw()
    pv = pvals()
    lines = ["=== SRW3 Phase 1G — Part 6: CROSS-LAYER BYTE CONSISTENCY ===",
             "layers: Python <-> K-abstract (llvm, real krypto shim)",
             ""]
    nok = 0
    total = 0
    for k in pv:
        p, khex = pv[k], kv.get(k, "<MISSING>")
        ok = p == khex
        nok += ok
        total += 1
        lines.append(f"[{k}] python={p}")
        lines.append(f"[{k}] k      ={khex}")
        lines.append(f"[{k}] {'MATCH' if ok else '*** MISMATCH ***'}")
        lines.append("")
    lines.append(f"=== CROSS-LAYER BYTES: {nok}/{total} MATCH "
                 f"(Python <-> K-abstract) ===")
    out = "\n".join(lines) + "\n"
    open(OUT, "w").write(out)
    print(out)
    return 0 if nok == total else 1


if __name__ == "__main__":
    raise SystemExit(main())
