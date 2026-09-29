# SRW3 Phase 1A — Canonical Git Provenance (Part I.B repair)

Date of repair: 2026-09-29 (UTC). This record documents the canonical Git
provenance of the Phase-1A starting state, repairing the Phase-0 bundle
deficiency (the theorem-closure final state existed only as an uncommitted
working tree; the shipped git bundle's tip predated it). No historical claim
was rewritten: `main` and `kevm-changes` are untouched; the final state is a
new descendant commit.

## Chain

    final source tree (srw3-kevm/, theorem-closure state)
        -> git commit 80448f2 (branch phase1-start, parent 69859b1)
        -> reproducible git bundle srw3-work.bundle (sha256 92481f29...)
        -> commit hash recorded in SRW3-Phase1A-LLVM-Report.md §1

## Commits

| field         | value |
|---------------|-------|
| final commit  | `80448f22cd9f24e6598565992db1e447c71cd4db` |
| message       | "Phase-1 starting state: theorem-closure final tree (canonical provenance)" |
| branch        | `phase1-start` |
| parent commit | `69859b1723b08fe56bcaa55a707b350bfc9d96e7` (kevm-changes: K v7.1.337 compat fixes) |
| grandparent   | `a857618627763ccc424322d9390436eb42b6c622` (main: baseline-v1.0, byte-identical SRW3_Phase_0D_Implementation_v1.0.zip) |

`git status` at the final commit: **clean**
(see `git_status_phase1-start.txt`).

`git diff` kevm-changes..phase1-start: 60 files, the complete research delta
(see `git_diff_stat_69859b1_phase1-start.txt` and the full patch
`git_diff_69859b1_phase1-start.patch`).

## Git bundle

| field    | value |
|----------|-------|
| artifact | `srw3-work.bundle` |
| sha256   | `92481f29d1fcb0cad0e6d73db9899c0c9eaf9d6f5b06676078b67ee6eb0d7021` |
| refs     | `main` = a857618, `kevm-changes` = 69859b1, `phase1-start` = 80448f2 |
| history  | complete (`git bundle verify` passed) |

Reconstruction of the exact Phase-1A source tree:

    git clone srw3-work.bundle srw3-restored
    cd srw3-restored && git checkout phase1-start
    # srw3-kevm/  ==  the exact tree used for the Phase-1A LLVM experiment

Kompile-output directories are excluded from the tree (reproducible
derivatives; see `srw3-kevm/.gitignore` in the commit).

## Pinned toolchain revisions (unchanged from Phase 0-D unless noted)

| component            | revision |
|----------------------|----------|
| K Framework          | v7.1.337 (K .deb; llvm-backend `0.1.140`; deps/k_release pin = 7.1.337) |
| KEVM                 | v1.0.921 (source tarball; no binary release assets published) |
| blockchain-k-plugin  | `207ae5121e5178a09742ed746f2d15e34b1750cc` (K files only; C libkrypto NOT built — no keccak-dependent opcode exercised; documented limitation §O of the Phase-0 report) |
| Z3                   | 4.13.3 (Debian trixie package, extracted without root) |
| Java                 | OpenJDK 21.0.12 (host) |
| Python               | 3.12.14 (host) |
| clang/lld (NEW 1A)   | 15.0.6-4+b1 Debian pool, extracted to `tools/clangpkg` without root; K's `llvm-kompile-clang` wrapper reads `LLVM_KOMPILE_CXX` (original preserved as `.orig`); dev-symlink shims for host `lib{tinfo,mpfr,jemalloc,unwind}` in `tools/hostlibs` — all documented as Phase-1A toolchain deviations (report §3) |

## Baseline provenance (unchanged)

    SRW3_Phase_0D_Implementation_v1.0.zip
    sha256 2db8669f8aeddc5bceff762bfd4a4901ddc9cb3f3e6387364e0abe2ac8e62955
    (byte-identical copy in git bundle, commit a857618, branch main)

## Artifact archive

The Phase-1A download archive (`SRW3-Phase0D-Artifact-Bundle.zip` successor,
rebuilt at Phase-1A close) embeds this file; its SHA-256 is recorded in
`artifact_zip_sha256.txt` (written at packaging time, outside the committed
tree to avoid self-reference) and in the Phase-1A report §1.
