# SRW3 Phase 1I-R3 — Configuration-Root-Binding Audit
(Phase 1I-R3: full configuration-root binding — `phase1i-r3/`)

**Scope.** This audit accompanies the isolated R3 machine
(`phase1i-r3/semantics/srw3proto-r3.k`), its proof ladder
(`phase1i-r3/proofs/r3_proofs.k` + `r3_fixtures.k`), the Python mirror
(`phase1i-r3/python/`), the golden vectors (`phase1i-r3/vectors/`), and the
transcripts.  It is an audit/repair record, not a claim that any external
system was changed.  The R3 work is ADDITIVE: the frozen trees
(`phase1g`, `phase1h`, `phase1h-r1-fix`, `phase1i`, `phase1i-r1`,
`phase1i-r2`) are byte-identical to the base commit — see §G.

**Defect under repair (finding R3-F1).**  In the frozen R2 machine, the
configuration-root preimage `ProtoCfgCanonR2` (tag 0x9C) commits to fields
1–8 only, while fields 9–13 (schedule, spec version, authority proof type,
authority guest digest, authority proof-config digest) influence gate
authority through `GateAuthorityMatchesCfgR2` and the machine-built `azCtx`.
The R2 K definition documents them as "pin-internal".  A LOCAL R2 machine
pins all 13 fields, so R2's local receipt-provenance result stands; the gap
is CROSS-MACHINE ROOT IDENTITY: configurations differing only in fields
9–13 share the same R2 root preimage while deriving different gate
authority/decisions (the "R2 alias").

## A. Command-surface and rule-set enumeration (structural claims)

The R3 definition declares exactly one configuration
(`<srw3protoR3>`: `<k> <r3lineage> <r3next> <r3head> <r3linhead> <r3anchor>
<r3valid>`) and a command language `PProgR3I` over `PCmdR3I` with EXACTLY
three constructors:

```text
pInitR3(ProtoCfgR3)
pGateEvalR3(ProtoBlockR3, ExecCtx, LinRecG, AuthzCert, Bytes, Bytes)
pAcceptR3(ProtoBlockR3, Bytes, Bytes, Int)
```

No command has: a verdict/decision argument (any sort), a receipt argument,
a configuration-replacement argument, a root argument, or an anchor
argument.  `SRW3PROTO-R3` imports ONLY `SRW3AUTHZ` (the frozen Phase 1G
gate); `SRW3PROTO`, `SRW3PROTO-R1`, and `SRW3PROTO-R2` are NOT imported, so
the legacy commands (`pInit`/`pAccept` of 1I, `pInitR1`/`pGateEval`/
`pAcceptR1` of R1, `pInitR2`/`pGateEvalR2`/`pAcceptR2` of R2) are not in
the reachable syntax, and the legacy transition rules are absent from the
rule set.  The R3 rule set is finite and enumerated:

| # | Rule | Effect |
|---|------|--------|
| 1 | `pConsR3` / `runNilR3` | program sequencing |
| 2 | `pInitR3` (positive) | pins cfg ONCE — **only if** `ProtoRootR3(C) == <r3anchor>`; anchors `<r3head> := ProtoRootR3(C)`, `<r3linhead> := R3LinRoot` |
| 3 | `pInitR3` [owise] | refuses (re-init or root mismatch); state unchanged |
| 4 | `pGateEvalR3` (pool present) | the ONLY receipt producer; mints the computed verdict + computed root + anchor; no chain movement |
| 5 | `pGateEvalR3` (pool absent) | same, creating the pool |
| 6 | `pAcceptR3` (accept) | the ONLY chain-extending rule; full commitment guard incl. anchor/root re-checks; consumes the receipt exactly once |
| 7 | `pAcceptR3` [owise] | fail-closed reject; every cell unchanged |

Parse-level demonstrations: `transcripts/demos/T10-llvm-injection-ill-formed.txt`
(the R1 injection shape with a verdict string), `T11a..T11f-llvm-legacy-*-ill-formed.txt`
(each legacy command name), all backend-independent kparse rejections.

**R3-ANCHOR-IMMUTABLE (structural).**  Every `<r3anchor>` occurrence in the
definition is read-only; the mechanical scan is
`transcripts/legacy/anchor-immutability-scan.txt` (no `=>` inside the anchor
cell anywhere; the pin at key −1 is written only by rule 2).  Per-rule frame
conjuncts are additionally mechanized inside R3-INIT-PINS-AUTHORIZED,
R3-MINT-SHAPE-*, R3-VALID-ACCEPT, and R3-CONFIG-FRAME-ACCEPT (each leaves
`<r3anchor> A:Bytes` unchanged).  A blanket kprove form ("any command fires
with everything symbolic") is NOT provable — the prover cannot decide the
requires of unfireable command instances (the stuck-term boundary); the
per-rule evidence is the mechanizable content.

## B. Receipt-producer exhaustiveness

`gateReceiptR3` is constructed in exactly two rules (4 and 5), both
guarded by the mint discipline.  No command carries a receipt-shaped
argument; no rule writes a receipt field directly; the accept rule only
CONSUMES (removes) a receipt that the mint discipline produced and that
matches the candidate/results/heads/slot/config/anchor/verdict-derived
decision.  This is the R2 discipline carried forward verbatim; together
with the mint-shape claims (R3-MINT-SHAPE-EXISTING-POOL / -EMPTY-POOL —
both PROVED) it closes R3-GATE-RESULT-DERIVED and R3-GATE-INPUT-BINDING at
the transition level.

## C. Frozen-formula correspondence

R3 reproduces the frozen 1I formulas with IDENTICAL tags and composition
(the one-`<k>`-cell rule prevents importing them — the same documented
indirection the R2 audit section C describes).  The correspondence is
carried by: (a) the PROVED claims `R3-CORRESPONDENCE-POLICY-COMMITMENT`
(frozen `PolicyCommitmentI`, `phase1i/semantics/srw3proto.k` lines 113–118,
tags 0x9D/0xA5), `R3-CORRESPONDENCE-CTX-DIGEST` (frozen `CtxDigestI`, lines
129–134, tag 0xA6), `R3-CORRESPONDENCE-BLOCK-COMMIT` (frozen
`BlockCommitI`, lines 213–223, tag 0x9E), each transcribed byte-for-byte
into the claim text; (b) `R3-CORRESPONDENCE-ROOT-R3` (the new R3 root
composition, PROVED); (c) the byte-level K↔Python cross-checks (§E); and
(d) the Python mirror re-deriving identical preimages
(`phase1i-r3/python/r3_model.py`).

**The one formula R3 replaces is the configuration-root preimage.**  The
frozen 0x9C shape is NOT reused (R3-DOMAIN-SEPARATION, PROVED; the legacy
shape survives only as the clearly labeled witness oracle
`LegacyR2ProjectionR3W` in `proofs/r3_fixtures.k`, used by the alias
regression claims and by nothing else).  Per handoff §2, the frozen
`PolicyCommitment`/`CtxDigest` semantics are UNCHANGED, so they keep the
frozen names/tags; no renamed formula was needed.

## D. The two distinct questions (handoff §4) and their dispositions

**A. Complete commitment — CLOSED (relative to the anchor; collision
resistance assumed).**  The R3 preimage covers all 13 fields with an
explicit versioned domain separator and LP32 length-delimiting:

```text
ProtoCfgCanonR3(C) = "SRW3/ProtoCfg/R3"||0x00 || U32BE(1)
  || LP32(chainId) || U32BE(policyV) || LP32(policyD) || LP32(appSetD)
  || LP32(graphD) || LP32(clientCfgD) || LP32(execClientD) || LP32(fork)
  || LP32(schedule) || U32BE(specV) || U32BE(authPT)
  || LP32(authGuestD) || LP32(authCfgD)
ProtoRootR3(C) = Keccak256(ProtoCfgCanonR3(C))
```

Mechanized: the 349-byte golden-preimage equality `R3-CANON-FIELD-ORDER`
(PROVED on the Haskell backend — a pure-Bytes computation, no hash hook);
per-field preimage inequalities for fields 1–8 (R3-BINDS-FIELDS-1-8) and
for each authority field 9–13 (R3-ROOT-BINDS-AUTHORITY-FIELDS-F09..F13) —
all PROVED concretely over the all-literal fixture; the length-ambiguity
pair (R3-CANON-LENGTH-DELIMITED) and the alias witness
(R3-R2-ALIAS-WITNESS: the legacy projection is UNCHANGED by a schedule
mutation while the R3 preimage CHANGES) — PROVED.  The ROOT-level
distinction is additionally demonstrated with real Keccak-256 on the LLVM
backend (T0/T5 transcripts; `cfgr3root` vs `cfgr3rootS` for the
schedule-mutated config) and in the Python vectors file.  The general
statement "differing preimages ⇒ differing roots" is conditional on Keccak
collision resistance and is NOT claimed as an injectivity theorem.

**B. Authority of the root — PARTIALLY CLOSED BY AN EXPLICIT ASSUMPTION
(disclosed, per handoff §4/§9).**  A locally computed root is not
automatically an authenticated protocol root; R3 therefore exposes the
protocol's trusted configuration-root anchor as a DEDICATED IMMUTABLE CELL
`<r3anchor>` filled by the explicit authenticated external input
`$SRW3R3ANCHOR` (the model of the trusted genesis/config-root channel:
fixed protocol genesis or an authenticated governance root).  The anchor is
reachable by NO command and written by NO rule (§A).  Initialization checks
`ProtoRootR3(C) == <r3anchor>` (R3-INIT-PINS-AUTHORIZED PROVED; the
mismatch case R3-INIT-ROOT-MISMATCH-REJECTS PROVED — state unchanged);
acceptance re-checks the receipt's anchor and computed root against the
live machine (R3-REJECT-ANCHOR-MISMATCH PROVED — decidable on the Haskell
backend because the anchor cell is concrete machine state; the root
conjunct is hash-class on hs and demonstrated concretely on LLVM/Python).

**Where the anchor comes from.**  OUTSIDE the modeled command stream.  R3
does not model governance, root updates, or anchor rotation (handoff §5:
no upgrade transition in scope; none implemented).  Accordingly the
disposition reads exactly:

> **complete configuration commitment closed; protocol-root authority
> remains an explicit assumption.**

This is NOT "end-to-end security closed".

## E. Cross-layer artifacts

- **K (LLVM + krypto shim) ↔ Python ↔ vectors file.**  The K-side
  certificate (`transcripts/crosslayer/r3_byte_certificate_k_raw.txt`,
  produced by `T0-llvm-cross-layer-certificate.txt` with the shim) and the
  Python recomputation agree byte-for-byte on: the complete 13-field
  canonical preimage (`cfgr3canon`, 282 bytes for the demo config), the
  root (`cfgr3root = 207799d4…`), the schedule-mutated root
  (`cfgr3rootS`), the frozen policy commitment / context digest / block
  commitment / SRW3 root, both certificate identities (`certid0` anchors
  to the frozen 1G transcript value `89ffea58…`), the record F-child, and
  the computed verdicts (`valid-g` twice).  The Python suite
  (`run_r3_attacks.py`, KX group) asserts each pair; 181/181 PASS.
- **Golden vector.**  `vectors/config-root-r3.json` carries the 349-byte
  canonical preimage of the handoff/pack sample configuration (K and
  Python reproduce it byte-for-byte; `R3-CANON-FIELD-ORDER` PROVED on the
  Haskell backend), plus per-field mutation vectors, the length-ambiguity
  pair, the R2-alias witness, domain-separation prefixes, and the invalid
  input table.
- **Hash discipline.**  All digests are Ethereum Keccak-256 (original
  padding) via the frozen `LinH` hook (hs: symbolic; LLVM: the Phase-1C
  krypto shim, multiblock fix marker-checked) and `lin_verify.H` in Python.
  `hashlib.sha3_256` is never used; the suite additionally asserts that
  SHA3-256 and Keccak-256 disagree on the same preimage
  (ROOTBIND-keccak-not-sha3) to document why the substitution is forbidden.

## F. Proof-count reconciliation (the unambiguous R3 score convention)

R2's published `score.txt` (`3 0`) disagreed with the report's 37/3
summary because the file held the LAST chunk's count rather than the
inventory total.  R3 defines the convention explicitly (handoff §8):

- `score.txt` = `"<N_proved> <N_failed>"` counted 1:1 over the claim
  inventory of `run_r3_proofs.sh` (each label = exactly one kprove
  invocation = one retained log);
- `claims-status.csv` = the machine-readable per-claim table (backend,
  invoked, raw result, log);
- `claim-classification.csv` = the audit-facing scientific label per claim
  (PROVED / NOT MECHANIZED / STRUCTURAL), never conflated with the raw
  kprove result;
- expected-fail claims (R3-PIPELINE-HONEST, R3-PIPELINE-FORGED, R3-ALL)
  are RETAINED failures with their error classes and concrete substitutes
  — not silent skips.

Final inventory: **50 kprove claims → 47 PROVED / 3 NOT MECHANIZED
(retained)**, plus 1 STRUCTURAL claim (R3-ANCHOR-IMMUTABLE, audit-verified,
not a kprove claim).  The three NOT-MECHANIZED labels inherit the KNOWN
blocker classes recorded since frozen PI7-ALL / R1-ALL / R2-ALL:

| Label | kprove outcome | Class | Concrete substitutes |
|---|---|---|---|
| R3-PIPELINE-HONEST | FAILED(ErrorBottomTotalFunction) | hs stuck-term boundary over the computed verdict / unevaluated Keccak256raw in the destination map | T1-llvm-honest-two-block-pipeline.txt (REAL keccak), Python 181/181, and the PROVED R3-VALID-ACCEPT |
| R3-PIPELINE-FORGED | FAILED(ErrorBottomTotalFunction) | same class as R2-PIPELINE-FORGED | T5/T6/T7-llvm-* rejects; Python INJ/VERDICT/CROSSROOT groups |
| R3-ALL | FAILED(stuck-configuration) | the kore circularity/implication blocker (same as PI7-ALL/R1-ALL/R2-ALL) | the per-claim ladder + producer-exhaustiveness + command-surface audits |

**A new R3-specific hs boundary (disclosed, demonstrated in
T12-hs-init-root-check-boundary.txt).**  Because the R3 init performs a
REAL-KECCAK root equality (`ProtoRootR3(C) == <r3anchor>`), the honest R3
pipeline cannot be EXECUTED concretely on the Haskell backend at all (the
machine stalls at the init equality; krun exits 124 with unevaluated
`Keccak256raw` terms).  R2 had no such boundary at init precisely because
its root omitted fields 9–13 and its init performed no root check — the
defect R3 closes.  The concrete pipeline evidence is the LLVM shim run
(T1, two blocks, real keccak) and the Python suite; the mechanized
Haskell content carries the equality as a hypothesis (standard practice
for hash-class conjuncts, documented since Phase 1C-1).

## G. Frozen-tree byte stability

`git status` over the R3 branch is clean for every TRACKED file outside
`phase1i-r3/` (the full verification command and output are in
`provenance/PROVENANCE.md`).  Two working-tree files that the regression
re-runs regenerate in place
(`phase1h-r1-fix/transcripts/repair/*.json`) and the `kore-exec.tar.gz`
bug-report artifact were RESTORED from the base commit byte-exact before
committing (the same disclosed behavior as the R2 session); the R3-run
copies of the regression outputs live under `phase1i-r3/transcripts/
regression/`.  Notably, `k/phase1d/shim/libkrypto-shim.a` rebuilt this
session is byte-identical to the committed artifact (deterministic
toolchain) — it required no restore.

## H. Assumption and boundary register (complete)

1. `Keccak256raw` collision resistance (ASSUMED; standard for the project
   since 1C) — the general root-distinction statement is conditional on it.
2. The authorized root anchor `$SRW3R3ANCHOR` is an authenticated external
   input (ASSUMED — protocol-root authority/governance is out of scope;
   §D-B).
3. The frozen gate `VerifyLineageG` is sound (mechanized in frozen Phase
   1G; consumed as frozen).
4. The caller-presented evidence objects are a faithful execution record
   ONLY through the frozen gate's own replay/binding layers (unchanged
   trust boundary from R1/R2).
5. Haskell-backend hash hooks are uninterpreted (finding 1C-1) — hash-
   class equalities are hypotheses on hs and concrete on LLVM/Python
   (§F, including the NEW init-check boundary).
6. The Python mirror is EXECUTABLE EVIDENCE, not a formal proof.
7. Level-III protocol model only — NO consensus-integration claim of any
   kind is made or implied.
8. K `Int2Bytes` partiality on out-of-range integers: a garbage
   configuration has no canonical preimage and cannot pass the init
   equality (fail-closed); integer validation is enforced in Python
   before encoding (typed encoder, ValueError/TypeError).
