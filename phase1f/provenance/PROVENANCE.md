# SRW3 Phase 1F — Provenance

## Starting state (verified)
- Source: fresh fetch of github.com/Dannyednut/SRW3 (this session; the local
  sandbox had been reset and carried no Phase 1E state — recorded honestly)
- Branch derived: phase1f @ Phase 1E closure commit 8b26cb749... (the fetched
  origin/phase1e HEAD); scientific anchor 0d826c0f152fdea40683be9a6706c65e478f6ea3
  verified on the fetched branch before derivation; no history rewrite
- Toolchain: rebuilt this session from the pinned recipe
  (scripts/reinstall_toolchain_1b.sh + the 1B/1D clang-15 chain patches):
  K v7.1.337 | z3 4.13.3-1 | clang/LLVM-15 15.0.6-4+b1 (bookworm pool) |
  flex/libfl2 2.6.4 | libsecp256k1 0.5.0 (+.0/.1->.2 soname links) |
  KEVM v1.0.921 source | blockchain-k-plugin @ 207ae512 | krypto shim rebuilt
  from k/phase1d/shim (keccak-multiblock fix marker present)

## Baseline regression (before any Phase 1F change)
- L7 suite 10/10; mutations 21/21; comparisons 33/33 zero deviations;
  dishonest producer L7-STATE (part9 PASS); Phase 1E python 24/24 + 12/12;
  K composition suite pos=valid;neg1=neg2=neg3=invalid-state-composition
  (fresh LLVM re-kompile) — transcript:
  phase1f/transcripts/part0_baseline_k_composition.txt

## Key Phase 1F artifacts (sha256)
- phase1f/semantics/MODEL.md:            (see MANIFEST)
- phase1f/semantics/srw3exec.k:          (see MANIFEST)
- phase1f/semantics/srw3exec-demo.k:     (see MANIFEST)
- phase1f/proofs/*.k + not_mechanized/*: (see MANIFEST)
- phase1f/python/*.py:                   (see MANIFEST)
- k/kevm/srw3-exec-evm.k:                (see MANIFEST)
- k/kevm/srw3-exec-evm-demos.k:          (see MANIFEST)
- k/kevm/demos/evm_exec_*.srw3evm:       (see MANIFEST)
- scripts/phase1f/*:                     (see MANIFEST)
- phase1f/transcripts/part0..part7:      (see MANIFEST)

## Reproducibility
1. source tools/env.sh (rebuilt via the pinned recipe; env.sh at
   /home/z/my-project/tools/env.sh)
2. kompile phase1f/semantics/srw3exec.k --backend haskell -o
   phase1f/semantics/exec-hs-out -I phase1e/semantics -I k/phase1d
   -I <plugin-207ae512>/plugin
3. kprove per claim: python3 scripts/split_auth_claims.py
   phase1f/proofs/<f>.k /tmp/x; kprove <claim> -d phase1f/semantics/exec-hs-out
   --spec-module <MOD> -I phase1f/semantics -I phase1e/semantics -I k/phase1d
   -I <plugin>/plugin  (runner: scripts/phase1f/part3_k_proofs.sh)
4. LLVM abstract demo: export NIX_LLVM_KOMPILE_LIBS="-L k/phase1d/shim
   -lkrypto-shim -lsecp256k1 -lgmp"; kompile phase1f/semantics/srw3exec-demo.k
   --backend llvm --hook-namespaces KRYPTO --main-module SRW3EXEC-DEMO -o
   phase1f/semantics/exec-out -I phase1f/semantics -I phase1e/semantics
   -I k/phase1d -I <plugin>/plugin; krun per program (xpos0/xchain/xf8/
   xnegs/xnegs2/xbytes) — runner scripts/phase1f/part4_k_demo.sh
5. KEVM: kompile k/kevm/srw3-exec-evm-demos.k --backend llvm
   --hook-namespaces KRYPTO --main-module SRW3-EXEC-EVM-DEMOS -o
   k/kevm/exec-evm-demos-out -I k/kevm/kproj-e1e/plugin
   -I k/kevm/kproj-e1e/evm-semantics -I phase1f/semantics -I phase1e/semantics
   -I k/phase1d -I <plugin>/plugin; krun demos with -cCHAINID=1 -cMODE=NORMAL
   -cSCHEDULE=CANCUN -cUSEGAS=false (exit 1 = designed carrier terminal) —
   runner scripts/phase1f/part5_kevm.sh
6. Python: python3 phase1f/python/test_exec_verify.py;
   python3 phase1f/python/exec_mutations.py — runner scripts/phase1f/part2_python.sh
7. Cross-layer: python3 scripts/phase1f/part6_crosslayer.py (needs the part4
   xbytes raw + the KEVM commit run output in /tmp)
8. Prior art: python3 scripts/phase1f/part7_prior_art.py
9. Report PDF: python3 scripts/gen_phase1f_pdf.py

## Discipline
- Frozen Phase 1D-R1 / 1E files: untouched (additive modules only; the KEVM
  extension requires + imports, no frozen rule edited)
- New K-feature disclosures: the #next-interception instrumentation with
  [priority] rules; the carrier/run hoisting rules for multi-gate runs;
  the reserved tracer account (4096) with (last-run, last-pc) guards and
  maxUInt-form minimal-width key printing at extraction time
- Evidence tiers: no tier moved upward by a demo pass; the Level-3 result is
  a BINDING proof + an execution-grounded demonstration; general historical
  truth remains REQUIRES CLIENT/PROTOCOL SUPPORT
- The 3 GB sandbox memory constraint is documented (partitioned demo
  programs; none skipped)

## Final commit
- phase1f @ <this closure commit>
- Artifact bundle SRW3-Phase1F-Artifact-Bundle.zip (self-excluding MANIFEST;
  sha256 sidecar; see MANIFEST.txt)
