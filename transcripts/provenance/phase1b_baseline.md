# SRW3 Phase 1B — Part I baseline record (2026-09-29, UTC timestamps inline)

## Phase-1A anchors (frozen; sources: Phase-1A report + bundle)
* Phase-1A recorded commit : 80448f22cd9f24e6598565992db1e447c71cd4db
  (branch `phase1-start`, "Phase-1 starting state: theorem-closure final tree" —
  the commit hash cited by the Phase-1A report §1)
* Phase-1A artifact bundle : download/SRW3-Phase1A-Artifact-Bundle.zip
* bundle sha256            : 1fc51f29858a7f501ec357d0449847b7f21a068709e2a50562ed2775d6b72b4a
* K                        : v7.1.337 (llvm-backend 0.1.140)
* KEVM                     : v1.0.921 (source; $KEVMSRC=/home/z/my-project/tools/evm-semantics-1.0.921)
* blockchain-k-plugin      : 207ae5121e5178a09742ed746f2d15e34b1750cc (K files; C libkrypto not built)
* Z3                       : 4.13.3 (64 bit)
* clang (LLVM backend)     : 15.0.6-4+b1 via LLVM_KOMPILE_CXX
* host                     : Debian 13.4, 2 cores, 4.14 GiB RAM, unprivileged

## Working-tree status at Phase-1B start
* git repo HEAD before sync : 80448f2 (phase1-start), 0 dirty entries
* NOTE: the Phase-1A LLVM work-products (proofs/boundaries sources, llvm/evm-llvm
  transcripts, matrix v4 record) existed only in the working area
  (/home/z/my-project/srw3-kevm) and were NOT part of 80448f2, which records the
  theorem-closure tree Phase 1A started from. They are committed now as
  `phase1a-final` so Phase 1B starts from the complete Phase-1A final tree.

## Phase-1B starting point (branches created in this step)
* phase1a-final : 88e4209  (parent 80448f2; full Phase-1A tree; kompile output
  directories excluded — .gitignore extended with proofs/boundaries/out-*/, proofs/gen/out-*/)
* phase1b-start : 88e4209  (identical tree; clean branch where all Phase-1B work happens)
* status        : 0 dirty entries
* transcript archive: the Phase-1A matrix-v4 record is preserved verbatim as
  transcripts/audit/full_matrix_v4.phase1a.txt; the Part-I re-run below appends
  a clearly-marked Phase-1B re-verification section to full_matrix_v4.txt.

## Part-I re-run of the complete Phase-1A regression matrix
* command: audit_matrix_v4.sh stages setup|py|demos|claims|r2|defect|ghost|
  tier3|kevm|llvm|verdict, executed in order (see full_matrix_v4.txt tail)
* required outcome: all Phase-1A results reproduced unchanged (15/15, 13/13,
  Claims #Top, negative control fails correctly, bridge 9/9, ghost claims,
  KEVM COMMIT/REJECT/REJECT, LLVM equivalence PASS)
