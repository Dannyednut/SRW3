# SRW3 Phase 1D-R1 — Repository Closure Record

Status: **CLOSED** (repository closure and clean handoff; no new scientific variant).
This record was produced by an independent closure audit on 2026-10-03 from a
fresh clone of `https://github.com/Dannyednut/SRW3`, verified by live command
output rather than by reliance on prior reports.

## 1. Repository identity

| Field | Value |
|---|---|
| Repository | `https://github.com/Dannyednut/SRW3` |
| Branch | `phase1d-r1-complete` |
| Final scientific commit (branch tip at closure, also tagged) | `85f4be5ad5fc525540b17b7a27ea27eb34e700a3` |
| Parent commit | `6b2aecca0ac73e217433a9b7744b6d7d6396554a` |
| Tag `phase1d-r1-complete` | tag object `c16bff46b82ea848e549c163465cc11bf737d525`, peeled to `85f4be5ad5fc525540b17b7a27ea27eb34e700a3` |
| Tree object of the tagged commit | `e159e842ab2d288cf22f4d8ce94b441b6700974a` |
| `git archive` SHA-256 of the tagged tree | `f52c7d2e36dfded7eae8066bcad0f50694b980284dc6a7af7c8c7188bf53f23e` (reproduced byte-exactly in the closure session) |
| Closure documentation commit | the first commit on top of `85f4be5` introducing `docs/research/` (documentation only; no scientific file touched) |
| Date of closure audit | 2026-10-03 |
| Working tree at audit | clean; `git status` empty; tree object equals the tagged tree |

Historical progression (conceptual): `phase0d` → `phase1-start @ 80448f2` →
`phase1b @ abdfa62` → `phase1c` → `phase1d-r1-complete @ 85f4be5`. No branch
was rewritten, deleted, squashed, or force-pushed. `phase1-start` and
`kevm-changes @ 69859b1` are preserved inside the git bundles
(`git/srw3-work-r1-final.bundle`, and the historical `git/srw3-work.bundle`,
SHA-256 `92481f29d1fcb0cad0e6d73db9899c0c9eaf9d6f5b06676078b67ee6eb0d7021`);
they are not reachable from current remote branches and are not re-pushed as
new remote branches (that is an owner decision).

### Branch visibility is not provenance

The repository default branch is `phase1b`. This is intentional historical
branch separation and does **not** imply that Phase 1D-R1 is absent:

```text
phase1b...phase1d-r1-complete  =>  behind 0, ahead 21
```

`phase1b` is an ancestor of `phase1d-r1-complete` (0 commits behind); the R1
branch carries the full 21-commit Phase 1C→1D-R1 record on top of it. The
default branch was deliberately **not** changed; that is a repository
maintenance decision left to the owner.

## 2. Scientific closure

All items below were re-verified live in the closure session (fresh clone,
freshly rebuilt pinned toolchain where required), not inferred from reports.

### L7 soundness repair (exact post-state equality)

The verifier establishes `post_map == composed_map` (canonical finite-map
equality), not merely `composed_map ⊆ post_map`:

* Python (`python-gen/lin_verify.py`): the state layer computes
  `post_map = flat(presented)`, `composed_map = flat(apply_effects(pre_state,
  true_effects))` and returns `L7-STATE` when `post_map != composed_map` —
  exact equality; asymmetric membership loops are forbidden by the fix
  discipline documented in the file header.
* K (`k/phase1d/srw3lin-r1.k`, rule `LinCompositionOk`):
  `BytesEq(LinCanonKV(linCtxPostP(CTX)), LinCanonKV(LinApplyEff(linCtxPre(CTX),
  linCtxEffP(CTX))))` — symmetric byte equality of injective canonical
  encodings; extra keys, missing keys and changed values all change the byte
  string and are rejected. The K sources' SHA-256 values recorded in the
  canonical transcript match the committed files exactly
  (`srw3lin-r1.k` = `dc70e69d…f9a5ae`, `srw3lin-r1-demo.k` = `dd5267aa…84a6b`).
* Permanent L7 adversarial suite (`python-gen/test_lin_verify_L7.py`):
  **10/10 PASS live**, including L7-B (the frozen extra-key attack, fully
  re-signed) → `L7-STATE`.

### Mutation resistance

`python-gen/audit_mutations_21.py`: **21/21 rejected live** (0 accepted),
including m20 = the L7 extra-key attack with fully recomputed digests,
evidence, signature and child commitment.

### Authorized dishonest producer

`scripts/final_part9_threat.py`: **rejected live at the state-composition
layer** (`L7-STATE` Python / `invalid-state-composition` K counterpart). The
producer holds a valid key and recomputes every digest and signature
genuinely; all cryptography verifies; the state correspondence is what fails.
This is the exact construction of the recorded transcript, re-executed in the
closure session with an identical verdict (only the transcript's generation
timestamp differs; the tagged transcript bytes were restored after the
re-run to preserve tree identity).

### K correspondence

The canonical audit path
`transcripts/audit/phase1d_r1/part7_k_composition_suite_final.txt` records
the FINAL composition suite with toolchain identity (K v7.1.337, Z3 4.13.3,
clang 15.0.6, KEVM v1.0.921, plugin @ 207ae512) and the four verdicts

```text
pos=valid;neg1=invalid-state-composition;neg2=invalid-state-composition;neg3=invalid-state-composition
```

from two independent runs (live re-kompile and committed definition). The
FINAL report quotes exactly this result. In the closure session the committed
definition `k/phase1d/r1-out` was re-executed live with the rebuilt pinned
toolchain (`krun r1suite.pgm -d r1-out`, exit 0) and reproduced the identical
verdict string. The stale pre-fix failure transcript
(`part7_k_composition_suite.txt`) is preserved unchanged as historical
evidence, as is the pre-fix L7 attack reproduction
(`l7_attack_prefix.txt`).

### Cross-layer byte consistency

`transcripts/audit/phase1d_r1/final_crosslayer_bytes.txt`: **17/17**
byte-equality checks across Python ↔ K (9/9) and K ↔ KEVM (8/8) over the
presented artifacts (canonical serialization, input/effect/state digests,
evidence, signature, child commitment). Scope limitation stated in the
transcript itself: these bind the PRESENTED artifacts; no
historical-execution-authentication claim is made.

### Comparison audit

`python-gen/audit_comparisons.py`: **33/33 live probes, zero deviations**
between implemented and intended relations.

## 3. Provenance closure

Chain verified in the closure session:
final git commit → final source tree → artifact package → MANIFEST hashes →
independent verification.

| Item | Result |
|---|---|
| Preclosure package `SRW3-Phase1D-R1-Artifact-Bundle.zip` | survives unchanged; SHA-256 `b54d896812cd4811bd92af0442a4cc149a04ca6eb98e023616a553e6e205724e` re-verified live against its sidecar and the frozen freeze transcript |
| Tagged tree reproduction | `git archive 85f4be5` → `f52c7d2e…f23e` — byte-exact match with the value recorded at closure time in a separate environment |
| FINAL package | rebuilt in the closure session by the committed packager `scripts/package_artifacts_1d_r1_final.sh` from the tagged tree; see `SRW3-Phase1D-R1-FINAL-Artifact-Bundle.zip.sha256` for the rebuilt container hash |
| MANIFEST | self-excluding (does not checksum itself), 197 entries, round-trip `sha256sum -c` ALL OK from a fresh unzip of the package; no `/home/z` absolute paths |
| Per-entry source correspondence | every tree-sourced package entry byte-matches the tagged tree blob (`git cat-file blob`); only `PROVENANCE.txt` and the three git bundles are packaging additions; zero mismatches |
| Final git bundle | rebuilt in the closure session with refs `main @ 6601242`, `kevm-changes @ 69859b1`, `phase1-start @ 80448f2`, `phase1b @ abdfa62`, `phase1c @ 5a317ca`, `phase1d-r1-complete @ <closure commit>`, tag → `85f4be5`; a superset of the ref inventory recorded at closure time (all recorded refs contained) |

### Explicit discrepancy disclosures (none silently smoothed)

1. **Original FINAL container artifacts are not present in this environment.**
   The FINAL session's `SRW3-Phase1D-R1-FINAL-Artifact-Bundle.zip` and
   `git/srw3-work-r1-final.bundle` bytes were lost with that session's
   workspace (environment reset); they were packaging outputs and were never
   committed to git. Their integrity at closure time is anchored by committed
   evidence: the Part-12 completion check (MANIFEST 295 entries round-trip
   OK, ZIP sidecar verified) and the bundle verification transcript
   (`git_bundle_r1_final_verify.txt`, bundle SHA-256
   `eb191458c2d513732ec11b41e6d06d3dc05e687bca0654bf5d9835d7e090d046`,
   fresh-repo tree reconstruction EXACT MATCH). The closure session therefore
   REBUILT both from the tagged tree with the committed machinery; rebuilt
   container hashes are recorded in their sidecars and differ from the lost
   originals (container-level nondeterminism and, for the bundle, the added
   closure commit). Content-level equivalence is what is checkable and it
   checks out.
2. **Rebuilt MANIFEST has 197 entries; the Part-12 record says 295.**
   Reconciled exactly: the original packaging ran against a staging tree that
   had accumulated 98 files from earlier phases' packaging runs (Phase-0D
   baseline reference implementation, older report PDFs, patches,
   prior-art freeze, historical bundles). 196 fresh copies ∪ 98 lingering =
   294, + `PROVENANCE.txt` = 295. The fresh rebuild contains exactly what the
   committed packager copies from the tagged tree; every one of its entries
   is traceable to the tagged commit or to the packaging machinery. The 98
   historical files are preserved in the frozen pre-closure staging copy and
   in their own phase bundles; none is R1 scientific content.
3. **Packager selectivity.** 63 committed files (compiled K definition output
   directories, abstract demo programs, ghost proof fragments, boundary
   proofs/transcripts, top-level phase transcripts, historical provenance
   notes, `.gitignore`, `kore-exec.tar.gz`) are not represented in the
   package — the same selectivity as the original package (none of the 63 was
   in the original either). The FINAL report's bundle-inventory section is
   fully satisfied.
4. **`PROVENANCE.txt` hardcoded archive-hash line.** The committed packager's
   heredoc carries `e1a8b4d5…` from the b52427a-era bundle verification; for
   the tagged commit `85f4be5` the authoritative `git archive` hash is
   `f52c7d2e…f23e`, verified live twice (source repo and bundle-fresh repo
   pattern). The stale line is historical metadata in a generated file; it is
   disclosed here rather than silently rewritten.

## 4. Scope limitations (unchanged; no category upgrades)

The established result is exactly:

> Within the modeled verifier domain, a validly authorized but dishonest
> producer cannot make an internally inconsistent presented post-state pass
> the verifier's state-composition layer after the L7 repair.

Terminology is locked:

* **presented-effect consistency** — NOT "true execution-effect
  authentication". Historically true execution effects remain an open problem
  (NOT YET MECHANIZED / REQUIRES CLIENT/PROTOCOL SUPPORT).
* **cryptographically bound under stated assumptions** — NOT
  "cryptographically secure".
* The result is a concrete demonstration against the modeled verifier, not a
  general cryptographic theorem.
* Evidence-tier vocabulary (PROVED BY K / DEMONSTRATED BY KEVM / ASSUMED /
  REQUIRES CLIENT/PROTOCOL SUPPORT / NOT YET MECHANIZED) is preserved; no
  result has been moved to a stronger category by this closure.

## 5. Phase 1E boundary

Phase 1E is **closed as of this record** and must not begin from any state
other than the verified R1 branch. See `docs/research/phase1e_handoff.md`
for the exact starting state, the next scientific question (authenticated
state representation and stronger state-commitment binding, e.g.
Merkle/MPT-style commitments where appropriate, connected to the SRW3 lineage
and commitment model), and the standing constraints. No Phase 1E
implementation exists in this repository.
