# SRW3 Phase 1E — Provenance

## Starting state (verified)
- Source: fresh clone of github.com/Dannyednut/SRW3 (this session)
- Branch derived: phase1e @ closure commit 668a6519b017de226b25a6b1d6bf8736a731970c
  (phase1d-r1-complete branch tip; tag phase1d-r1-complete -> 85f4be5ad5fc525540b17b7a27ea27eb34e700a3)
- Toolchain: K v7.1.337 | z3 4.13.3-1 | clang/LLVM-15 15.0.6-4+b1 | libsecp256k1 0.5.0
  | KEVM v1.0.921 source | blockchain-k-plugin @ 207ae512 | krypto shim rebuilt
  (keccak-multiblock fix marker present)

## Baseline regression (before any Phase 1E change)
- L7 suite 10/10; mutations 21/21; comparisons 33/33 zero deviations;
  dishonest producer L7-STATE; K composition suite
  pos=valid;neg1=neg2=neg3=invalid-state-composition
- transcript: phase1e/transcripts/../../transcripts/audit/phase1e/part0_baseline_regression.txt

## Key Phase 1E artifacts (sha256)
- phase1e/semantics/MODEL.md: 06044d8005b89f8a6b476e6ae98bad551152fec53bb282f62fbd898dad26e3d6
- phase1e/semantics/srw3auth.k: b4ee19616bdbe456a26bca66e1b51d5b6906c15ee9e8453e5c0c4c6d78584ad4
- phase1e/semantics/srw3auth-demo.k: f298831838379468b38d8f2598368a890059852a12b9a43aaed0992a7ef6eea5
- phase1e/proofs/authenticated_read.k: 397237ded2e117c8ca798f3214f1ef749e0caa2a89040de2f44dfb7f0a468429
- phase1e/proofs/authenticated_update.k: f84cd8f55a5d4fa3b631f4afe3cee46b001574f4ea1ebcbf22dc5ca62b4f9aeb
- phase1e/proofs/root_lineage_binding.k: a6289316cd59988cda1aeaca2b7b3812767a5d00be8b912621ef93a1cc794979
- phase1e/proofs/gate_auth_commit.k: 951cbc433248bc2a194d6764746eb634b360c0eab3482e748f610793c825e821
- phase1e/proofs/negative_controls/auth_negative_controls.k: dec326eb39a75e3ce0ba6d7e6f91d79d1b23287f1c7ea3cc02c70583daf1a4c7
- phase1e/python/auth_model.py: f096169aee5a9e50c4f1802db5aa3d6d314dfd4ccc04f8015a2fd6e04d39e4cf
- phase1e/python/auth_verify.py: 1cb724fec247cb551f773231e5af2cc0dcce99d9fb202b1f1a7a6bd27a1659b6
- phase1e/python/test_auth_verify.py: 4c0c720ea85e436c8df961f989e3a0067e5d3c7ca0a24b0b3d299e86339c5373
- phase1e/python/auth_mutations.py: be8962490c950aa7bc1043a87de4065d192ee37f3fa49a35826e0a7ffd2e969b
- k/kevm/srw3-auth-evm.k: 4ed8813b171ff702d4830fe28e476d1e74421273c5652bacb35aaeb1284b70a2
- k/kevm/demos/evm_auth_commit.srw3evm: 296497e09dcb8803442bcb957f2b2a0c9a99a39c92713e85d6db278b34957a8f
- k/kevm/demos/evm_auth_stale.srw3evm: e0334e19ba988722634803c692c9746dddb25b36ac9b2f6a2968267fb4fb3f4e
- scripts/phase1e_crosslayer.py: e286b97f33382da27c52061c8f924a1045ee612a5eca1672f7a6de2bd45dde2b
- scripts/split_auth_claims.py: f97ebc9d9152764fbc73d05714cecf1b1fe0c63802b9d945c1419cb24e0d1072
- phase1e/report/SRW3-Phase1E-Authenticated-State-Report.md: 1ee4dfc326cb29d7164aacd6d7a504346d563ebf777456878ffdb11df4ee7606
- phase1e/report/SRW3-Phase1E-Authenticated-State-Report.pdf: 695799dd2edd1f945e1fa874df4dde3587aeb9e65836fa059a423c4c76d15127

## Reproducibility
1. source tools/env.sh (rebuilt via scripts/rebuild_env_1d.sh recipe; env.sh at /home/z/my-project/tools/env.sh)
2. kompile phase1e/semantics/srw3auth.k --backend haskell -o auth-hs-out -I <plugin/plugin> -I k/phase1d
3. kprove per claim: python3 scripts/split_auth_claims.py phase1e/proofs/<f>.k /tmp/x; kprove <claim-file> -d phase1e/semantics/auth-hs-out --spec-module <MOD> -I <semantics> -I <plugin/plugin> -I k/phase1d
4. LLVM demo: export NIX_LLVM_KOMPILE_LIBS="-L k/phase1d/shim -lkrypto-shim -lsecp256k1 -lgmp";
   kompile phase1e/semantics/srw3auth-demo.k --backend llvm --hook-namespaces KRYPTO --main-module SRW3AUTH-DEMO -o auth-out -I <plugin/plugin> -I k/phase1d; krun asuite
5. KEVM: kompile k/kevm/srw3-auth-evm.k --backend llvm --hook-namespaces KRYPTO --main-module SRW3-AUTH-EVM -o auth-evm-llvm-out (kproj-e1e assembled per 1D recipe);
   krun k/kevm/demos/evm_auth_commit.srw3evm -d auth-evm-llvm-out -cCHAINID=1 -cMODE=NORMAL -cSCHEDULE=CANCUN -cUSEGAS=false
6. Python: PYTHONPATH=python-gen:phase1e/python python3 phase1e/python/test_auth_verify.py; python3 phase1e/python/auth_mutations.py
7. Cross-layer: python3 scripts/phase1e_crosslayer.py

## Discipline
- Frozen Phase 1D-R1 files: untouched (git diff vs closure commit empty over k/, python-gen/)
- Finding 1E-LINAPPLY-MULTISLOT: additive fix only (srw3auth.k §0), disclosed in the report
- Evidence tiers: no tier moved upward by a demo pass; boundaries stated in MODEL.md §9-10 and the report
