# SRW3 Phase 1G — Provenance

## Starting state (verified)
- Source: fresh clone of github.com/Dannyednut/SRW3 (this session; the local
  sandbox had been reset and carried no Phase 1E/1F state — recorded honestly)
- Branch derived: phase1g @ the phase1f tip b6c651e07d10a6e909da906b6970043bc5314627
  (the fetched origin/phase1f HEAD; the 1E closure 8b26cb74 and the 1F
  scientific record verified on the fetched history); no history rewrite
- The stale local checkout (phase1b state) preserved as
  /home/z/my-project/srw3-kevm.old-phase1b; the working repo renamed to the
  canonical /home/z/my-project/srw3-kevm so every frozen hardcoded path
  resolves (symbolic links are forbidden by the sandbox — recorded)
- Toolchain: rebuilt this session from the pinned recipe
  (scripts/rebuild_env_1d.sh + scripts/phase1g/setup_env_1g.sh):
  K v7.1.337 | z3 4.13.3-1 | clang/LLVM-15 15.0.6-4+b1 (bookworm pool) |
  flex/libfl2 2.6.4 | libsecp256k1 0.5.0 (+.0/.1->.2 soname links) |
  KEVM v1.0.921 source | blockchain-k-plugin @ 207ae512 | krypto shim rebuilt
  from k/phase1d/shim (keccak-multiblock fix marker present)
- TWO toolchain deviations recorded honestly:
  1. the k.deb download TRUNCATED at 43/181 MB (curl resume re-download;
     dpkg-deb -c verification: 488 archive entries, 432 files extracted)
  2. libclang-common-15-dev was downloaded by rebuild_env_1d.sh but is NOT
     in its extract loop — stddef.h missing for the shim build; extracted
     manually (the 1D recipe note anticipated the dependency)

## Baseline regression (before any Phase 1G change)
- The frozen 1D/1E/1F files are untouched: `git diff` over k/,
  python-gen/, phase1e/, phase1f/ against the phase1f tip is empty (every
  1G extension is additive: srw3authz.k / azCtx / linRecG / the 1G KEVM
  module)
- The 1F/1E Python layers re-verified transitively: the 1G Python suite
  imports and RUNS the frozen chains on every case (25/25 verdict cases
  include the full 1E+1F accept chain; the b02 mutation re-demonstrates the
  1F L14-ANCHOR catch)

## Key Phase 1G artifacts (sha256 in the MANIFEST)
- phase1g/semantics/MODEL.md:            normative model spec (FROZEN)
- phase1g/semantics/srw3authz.k:         the authority semantics (additive)
- phase1g/semantics/srw3authz-demo.k:    the demo suite (8 partitioned programs)
- phase1g/proofs/*.k:                    the mechanized claims + negative controls
- phase1g/python/{authz_model,test_authz_verify,authz_mutations}.py
- k/kevm/srw3-authz-evm.k + srw3-authz-evm-demos.k + demos/evm_authz_*.srw3evm
- scripts/phase1g/*:                     runners + crosslayer + prior art
- phase1g/transcripts/part0..part7:      the evidence transcripts

## Reproducibility
1. source tools/env.sh (rebuilt via the pinned recipe + setup_env_1g.sh)
2. kompile phase1g/semantics/srw3authz.k --backend haskell -o
   phase1g/semantics/authz-hs-out -I phase1f/semantics -I phase1e/semantics
   -I k/phase1d -I <plugin-207ae512>/plugin
3. kprove per claim: python3 scripts/split_auth_claims.py
   phase1g/proofs/<f>.k /tmp/x; kprove <claim> -d phase1g/semantics/authz-hs-out
   --spec-module <MOD> -I phase1g/semantics -I phase1f/semantics
   -I phase1e/semantics -I k/phase1d -I <plugin>/plugin
   (runner: scripts/phase1g/part3_k_proofs.sh)
4. LLVM abstract demo: export NIX_LLVM_KOMPILE_LIBS="-L k/phase1d/shim
   -lkrypto-shim -lsecp256k1 -lgmp"; kompile phase1g/semantics/srw3authz-demo.k
   --backend llvm --hook-namespaces KRYPTO --main-module SRW3AUTHZ-DEMO -o
   phase1g/semantics/authz-out -I phase1g/semantics -I phase1f/semantics
   -I phase1e/semantics -I k/phase1d -I <plugin>/plugin; krun per program
   (xpos0/xchain/xcm1a/xcm1b/xcm2/xcm3/xbal/xbytes) — runner
   scripts/phase1g/part4_k_demo.sh
5. KEVM (Tier G2): kompile k/kevm/srw3-authz-evm-demos.k --backend llvm
   --hook-namespaces KRYPTO --main-module SRW3-AUTHZ-EVM-DEMOS -o
   k/kevm/authz-evm-out -I k/kevm/kproj-e1e/plugin
   -I k/kevm/kproj-e1e/evm-semantics -I phase1g/semantics
   -I phase1f/semantics -I phase1e/semantics -I k/phase1d -I <plugin>/plugin;
   krun demos with -cCHAINID=1 -cMODE=NORMAL -cSCHEDULE=CANCUN
   -cUSEGAS=false (exit 1 = designed carrier terminal) — runner
   scripts/phase1g/part5_kevm.sh. MEMORY NOTE: the KEVM krun needs the
   sandbox exclusively — run AFTER the kprove pass (parallel runs OOM-killed
   at the 3 GB ceiling; recorded).
6. Python: python3 phase1g/python/test_authz_verify.py;
   python3 phase1g/python/authz_mutations.py
7. Cross-layer: python3 scripts/phase1g/part6_crosslayer.py (needs the part4
   xbytes raw output)
8. Prior art: fetch the four sources (see part7 header) then
   python3 scripts/phase1g/part7_prior_art.py
9. Report PDF: python3 scripts/gen_phase1g_pdf.py

## Discipline
- Frozen Phase 1D-R1 / 1E / 1F files: untouched (additive modules only; the
  KEVM extension requires + imports, no frozen rule edited)
- New modeling disclosures: the authority chain verification requires EVERY
  chain step to carry an AUTHORIZED identity (context-derived) — the model
  change that closes the "arbitrary claimed consensus id" hole discovered
  during the design; circularity (authcircle) is checked BEFORE source
  authorization (authsrc) so self-referencing certificates are diagnosed as
  circular even when their source could not be authorized; the KEVM adapter
  binds the certificate's effect digest to the EXECUTION-DERIVED trace,
  making presented == executed a Gate_G consequence at that layer
- The 3 GB sandbox memory constraint is documented (partitioned demo
  programs — the 1F precedent continued; xcm1 split into xcm1a/xcm1b; the
  KEVM/kprove serialization)
- Evidence tiers: no tier moved upward by a demo pass; the authority result
  is INHERITANCE (the gate verifies that a certificate's chain terminates at
  a protocol root and never at itself); the protocol root's own authority is
  the explicit A-G2 assumption replacing A-E3 at the Gate_G level

## Final commit
- phase1g @ <this closure commit>
- Artifact bundle SRW3-Phase1G-Artifact-Bundle.zip (self-excluding MANIFEST;
  round-trip checked) + .sha256 sidecar
- Pushed to origin/phase1g (PAT used for the push only, never stored in any
  file, commit, or log)
