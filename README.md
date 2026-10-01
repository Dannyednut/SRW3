# SRW3 — Commitment-Gated Security Calculus: Mechanized Verification (K / KEVM)

Off-site backup of the SRW3 mechanization project. Every working session ends with a
push here, so that sandbox resets cannot lose work.

**SRW3** is a security calculus in which an application may transition only when every
obligation implied by its prospective write set is discharged through a single
commitment gate. The project mechanizes the calculus and its safety theorems with the
K Framework (v7.1.337, Haskell + LLVM backends), binds the abstract layer to a real EVM
semantics (KEVM v1.0.921), and cross-validates every result against a Python mirror
oracle. All toolchain versions are pinned; every artifact carries a SHA-256 chain
(`artifacts/MANIFEST.txt`).

## Phase status

| Phase | Scope | Status |
|---|---|---|
| 0-D | Pinned toolchain, abstract SRW3 K model, one-gate architecture, Claims 1–4 | CLOSED |
| 1A | LLVM retarget + proof-boundary experiment, baseline frozen (`88e4209`) | CLOSED |
| 1B | Generalized semantics `srw3gen.k`: CM2 aliasing + CM3 aggregate authority absorbed; ∀n ghost theorems mechanized (35 claims: 32 PROVED + 3 designed-FAIL); KEVM generalized binding; matrix v5 zero regression | CLOSED |
| 1C | Cryptographic grounding — keccak256 commitment lineage executable in the gate (tamper rejected, restore verified); libsecp256k1 ECDSA path vector-validated; krypto probe 8/8; A6 → DEMONSTRATED (execution layer) | CLOSED |

## Repository layout

| Path | Contents |
|---|---|
| `reports/` | Phase reports (Markdown source of truth + rendered PDF): 0-D KEVM, 1A LLVM, 1B Gen |
| `bundles/` | Per-phase cumulative artifact bundles (`.zip` + `.sha256` sidecars) |
| `artifacts/` | Browsable cumulative tree (0-D + 1A + 1B): semantics, proofs, scripts, transcripts, python-gen, patches, `MANIFEST.txt` sha256 chain, `git/` bundles |
| `artifacts/git/srw3-work.bundle` | Historical git bundle (pre-1B lineage) |
| `artifacts/git/srw3b-work.bundle` | Phase-1B git bundle |
| `artifacts/git/srw3c-work.bundle` | Phase-1C git bundle |
| `worklog.md` | Full multi-session work log (all task IDs, decisions, defect records) |

Branches:

| Branch | Contents |
|---|---|
| `main` | This archive (browsable artifacts + bundles + reports) |
| `phase1b` | Git history of the Phase-1B working repo (tag `phase1b-complete` = `e132157`) |
| `phase1c` | Phase-1C working history: crypto probe + krypto shim + `srw3ck.k` integration (HEAD `9dc90f0`) |

## Session-to-session recovery procedure

A fresh sandbox can reconstruct the complete working state:

```bash
git clone https://github.com/Dannyednut/SRW3.git
cd SRW3

# 1) Working repo with full Phase-1B history (sources only):
git clone --branch phase1c --single-branch . ../srw3b-work
#    (phase1b = Phase-1B snapshot; from the bundle: git clone artifacts/git/srw3c-work.bundle ../srw3b-work)
#    (or from the bundle: git clone artifacts/git/srw3b-work.bundle ../srw3b-work)

# 2) Toolchain re-install (pinned recipe, ~no root needed):
bash ../srw3b-work/scripts/reinstall_toolchain_1b.sh   # K v7.1.337, z3 4.13.3, KEVM 1.0.921, libsecp256k1, LLVM-15

# 3) Verify artifact integrity against the sha256 chain:
cd artifacts && sha256sum -c MANIFEST.txt --quiet && echo OK

# 4) Reports + evidence: reports/ (PDF+MD), artifacts/transcripts/ (all audit runs)
```

The GitHub personal access token must be re-supplied by the user each session (it is
deliberately NOT stored in this repository). Push convention at session end:

```bash
cd srw3b-work && git push <token-remote> phase1b          # working repo history
# + refresh artifacts/, bundles/, worklog.md on main and push
```

## Headline results (Phase 1B)

- **CM2 (resource aliasing) and CM3 (aggregate/delegated authority) absorbed with zero
  ad hoc cases** — both counterexamples formalized, executable, permanent regressions.
- **Three new ∀n safety theorems PROVED BY K** (circularity, `#Top`): alias-aware,
  aggregate-authority, and the full generalized multi-write + alias + authority theorem.
- **Python mirror oracle** reproduces the K decision table 14/14.
- **KEVM generalized binding** evaluates the same obligations over REAL EVM storage;
  carriers identical across haskell and llvm backends.
- **Matrix v5**: zero regression on the Phase-1A surface.
