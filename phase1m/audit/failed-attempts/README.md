# Phase 1M Workstream B — failed attempt of record (the Map-encoding evaluator)

**Attempt:** the FIRST total Keccak-256 evaluator (`keccak256_total.k`,
module KECCAK256-TOTAL) keyed its state as a K **Map** (laneIndex -> 64-bit
lane), with per-stage Map-update recursions (KThetaCol/KChiCol sequential
map updates, a 25-entry KRhoPi map literal, KLane linear scans).

**Disposition:** FUNCTIONALLY plausible but never vector-validated; it
OOM-killed the Haskell-backend `krun` of the full hash on the 4 GB host
(exit 137 = SIGKILL; the retained witness log `krun-OOM-MapEncoding-kek0.log`
was lost with sandbox reset #7 — the crash is recorded verbatim in the
session log: `[Error] krun: Backend crashed during rewriting with exit code 137`
over /tmp/kfull-hs/haskellDefinition.bin, module KFULL, program kekT).

**Replacement:** the PACKED-INT encoding (state = one 1600-bit Int; every
stage a fully-literal-indexed pure-Int reduction; the current
`phase1m/semantics/keccak256_total.k`).  Three latent defects of the Map
attempt were exposed and fixed during the vector validation of the packed
version (they were inherited from this attempt): the padding zero count
(KZeros(Q -Int 2) instead of KZeros(134 -Int Q)), the XOR convention
(`^Int` is exponentiation in K — bitwise XOR is `xorInt`), and the absorb
remainder slice (`lengthBytes(B) -Int 136` silently dropped every second
block; plus `substrBytes` RAISES on start > end).

**File:** `keccak256_total_MAP-ENCODING-OOM.k` — RECONSTRUCTED from the
session record after sandbox reset #7 (the original was uncommitted and
lost with the reset); it is retained as the failed attempt of record and is
NOT part of the deliverable semantics.
