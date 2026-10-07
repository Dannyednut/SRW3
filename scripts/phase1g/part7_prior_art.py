#!/usr/bin/env python3
"""SRW3 Phase 1G — targeted current-prior-art review (Part 7).

Sources fetched live this session (raw.githubusercontent.com, unmodified):
  prior-art/eip-8025.md  Optional Execution Proofs        (Draft, Core)
  prior-art/eip-7928.md  Block-Level Access Lists         (Last Call, Core)
  prior-art/eip-8159.md  eth/71 - Block Access List Exchange (Last Call, Networking)
  prior-art/engine-api.md  Engine API (paris: engine_newPayloadV1)

The review determines EXACTLY what authority, provenance, effect
completeness, and commitment mediation each system already provides — and
what remains SRW3's delta. It upgrades no evidence tier.
"""
import os
import re
import hashlib
import datetime

HERE = os.path.dirname(os.path.abspath(__file__))
PA = "/home/z/my-project/srw3-kevm/phase1g/transcripts/prior-art"
OUT = "/home/z/my-project/srw3-kevm/phase1g/transcripts/part7_prior_art.txt"

FILES = ["eip-8025.md", "eip-7928.md", "eip-8159.md", "engine-api.md"]


def sha(p):
    return hashlib.sha256(open(p, "rb").read()).hexdigest()


def status_of(path, eip):
    t = open(path).read()
    m = re.search(r"^status:\s*(\S+)", t, re.M)
    c = re.search(r"^category:\s*(\S+)", t, re.M)
    return f"{m.group(1) if m else '?'}/{c.group(1) if c else '?'}"


def main():
    lines = []
    log = lines.append
    log("=== SRW3 Phase 1G — Part 7: TARGETED CURRENT-PRIOR-ART REVIEW ===")
    log(f"=== generated: {datetime.datetime.utcnow().isoformat()}Z ===")
    log("")
    log("## Sources (fetched live; sha256 verified below)")
    for f in FILES:
        p = os.path.join(PA, f)
        st = status_of(p, f) if f.startswith("eip") else "live main branch"
        log(f"  {f}: {os.path.getsize(p)} bytes  sha256={sha(p)[:16]}...  [{st}]")
    log("")
    log("## 1. EIP-8025 Optional Execution Proofs (Draft, Core)")
    log("   Provides: an opt-in consensus-layer path for STATELESS payload")
    log("   verification. Public input binds the proof to a specific")
    log("   NewPayloadRequest, chain ID, input schema, and validation result.")
    log("   CRITICAL QUOTE (spec, Proof-verifying mode): verified proofs are")
    log("   'a supplementary validity signal, not a replacement for")
    log("   re-execution'; proof-verifying nodes STILL RE-EXECUTE payloads.")
    log("   => 8025 does NOT make proof-checked authority load-bearing; no")
    log("   security-policy binding, no lineage, no obligation gate, no")
    log("   effect-trace binding. SRW3 delta (1G §6/§16): the ADDITIONAL")
    log("   public inputs (policyV, appSetD, graphD, lineageHead), the")
    log("   rel/level/chain authority structure, and the non-circularity")
    log("   theorem. SRW3 Mode B's proof math remains REQUIRES EXTERNAL")
    log("   PROOF SYSTEM (8025 is the natural host for it).")
    log("")
    log("## 2. EIP-7928 Block-Level Access Lists (Last Call, Core)")
    log("   Provides: ENFORCED per-block lists of accounts/storage locations")
    log("   accessed, with post-execution values; storage_changes carry")
    log("   [block_access_index -> new_value] (tx-level write attribution);")
    log("   storage_reads carry READ-ONLY KEYS ONLY (no observed values).")
    log("   => Structurally confirms the 1G BAL findings (mechanized: bal1-4):")
    log("      (a) BAL = footprint + post-values; (b) read OBSERVATIONS are")
    log("      absent -> the oracle-staleness class (1F neg8 / 1G bal3) is")
    log("      INVISIBLE to a BAL; (c) intra-transaction same-slot write")
    log("      order is absent (one entry per (slot, tx)) -> the F4 class is")
    log("      invisible; (d) BAL cannot detect what the ordered digest-bound")
    log("      trace detects, so access list != complete security effect")
    log("      trace. BAL CAN serve as an independent footprint CROSS-CHECK")
    log("      against the digest-bound trace (1G bal2: omission detected).")
    log("")
    log("## 3. EIP-8159 eth/71 BAL Exchange (Last Call, Networking)")
    log("   Provides: peer-to-peer exchange of BALs for sync workflows.")
    log("   => Networking only: no authority model, no commitment mediation,")
    log("   no obligation surface. Irrelevant to the authority boundary.")
    log("")
    log("## 4. Engine API (execution-apis, engine_newPayloadV1+)")
    log("   Provides: the CONSENSUS/EXECUTION boundary. The consensus client")
    log("   drives payload validation/execution; responses carry {status,")
    log("   latestValidHash}. The root becomes AUTHORITATIVE through the")
    log("   consensus process (fork-choice/finalization on top of the EL's")
    log("   VALID response), not inside the EL alone.")
    log("   => This is exactly the 1G modeled edge: the level-0 consensus")
    log("   root authorizes the payload; the level-1 client derives the")
    log("   state/effects. The smallest SRW3 insertion point that does NOT")
    log("   violate the separation: a post-execution hook exposing (payload,")
    log("   parentRoot, executionResult, childRoot, executionEvidence) to a")
    log("   commitment-gate observer. Anything stronger (making the gate's")
    log("   REJECT consensus-visible) is REQUIRES CLIENT/PROTOCOL SUPPORT")
    log("   (the Tier G3 boundary; NOT attempted here).")
    log("")
    log("## 5. Statelessness / witness formats / zkEVM (carried from 1F,")
    log("   unchanged by this session's fetches)")
    log("   Verkle/state witnesses authenticate state PIECES (location +")
    log("   value + proof) — no ordered effect stream, no execution identity,")
    log("   no read-observation binding, no lineage. zkEVM provers prove")
    log("   GENERIC execution validity — the frozen standing distinction")
    log("   (generic execution validity != SRW3 security validity) applies")
    log("   verbatim; complementary as a future Mode-B proof source.")
    log("")
    log("## 6. Net assessment for the Phase 1G research question")
    log("   - No surveyed system models AUTHORITY as distinct from")
    log("     authenticity with a non-circularity obligation; 8025/7928/8159")
    log("     provide evidence TRANSPORT and supplementary signals only.")
    log("   - The Engine API boundary is the real-deployment form of the")
    log("     1G assumption A-G2 (consensus as the authorization root): the")
    log("     model PROVES the adapter semantics; the deployment gap is")
    log("     REQUIRES CLIENT/PROTOCOL SUPPORT, recorded, not hidden.")
    log("   - 7928 BALs are a usable footprint CROSS-CHECK (SRW3's BalFoot-")
    log("     printOk) but structurally cannot replace the ordered digest-")
    log("     bound effect trace (mechanized in bal1-4 + CM-G9).")
    log("   - 8025's public-input set lacks any security-policy/lineage")
    log("     binding: SRW3's proofPub (MODEL.md §6) is the delta, and the")
    log("     proof system itself remains abstract (A-G6).")
    log("")
    log("PART7_PRIOR_ART_DONE")
    open(OUT, "w").write("\n".join(lines) + "\n")
    print(f"wrote {OUT}")


if __name__ == "__main__":
    main()
