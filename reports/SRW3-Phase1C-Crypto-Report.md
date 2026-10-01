# SRW3 Phase 1C — Cryptographic Grounding Report

**Status: COMPLETE · Evidence classes upgraded for the commitment-lineage layer · All artifacts sha256-chained**

---

## 1. Starting state and mandate

Phase 1B closed with the generalized commitment-gate semantics mechanized end to end: CM2 (resource aliasing) and CM3 (aggregate authority) absorbed as evaluated obligations inside the unchanged one-gate architecture, three new forall-n safety theorems proved by K, a Python mirror oracle at 14/14, an additive KEVM binding with identical carriers across the Haskell and LLVM backends, and matrix v5 showing zero regression on the Phase-1A surface. The recorded open items were exactly three: the tier-3 universal property, **cryptographic lineage**, and the **derivation of the alias table (`resmap`) and capacity (`cap`) from on-chain facts** — the latter two carried the explicit assumption classification A5/A6 as ASSUMED.

The Phase-1C mandate is the cryptographic layer of that closure, and it decomposes into the two named test points of the working plan:

- **Part IV** — establish that the pinned blockchain-k-plugin's cryptographic definitions (keccak256 commitment hashing) are actually usable in our toolchain, lifting the Phase-0 §O limitation ("C library libkrypto NOT built — no keccak-dependent opcodes exercised").
- **Part X** — establish the libsecp256k1 signature-verification path (ECDSA sign/recover/pubkey) as an executable capability behind the gate.

This report documents both parts, the two toolchain findings that explain why the capability never existed before, the minimal honest shim that provides it, the defect log from bring-up, and the integration of a real-hash commitment lineage into the gate as a working, tamper-evident semantics.

## 2. Environment recovery (third recorded reset)

The session began with the workspace reset again: `tools/` was gone, and the Phase-1C bundle from the previous (context-exhausted) session had been lost with it. Recovery followed the Phase-1B recipe and the new off-site backup. The pinned toolchain was reinstalled from `scripts/reinstall_toolchain_1b.sh`: K v7.1.337 (jammy deb, extracted without root), z3 4.13.3, flex/libfl2, libsecp256k1 0.5.0 with the `.0`/`.1`→`.2` soname compat shims, the LLVM-15 runtime, and the KEVM v1.0.921 source. The Phase-1A clang chain (llvm-15/clang-15/lld-15/libclang-cpp15 at 15.0.6-4+b1) was re-extracted and the hardcoded paths in `llvm-kompile`/`llvm-kompile-clang` re-patched, including the `LLVM_KOMPILE_CXX` override introduced in Phase 1A.

One reproducibility fix was folded into the record: the reinstall script's bookworm-pool grep for `libllvm15` no longer matches because the pool now publishes binary-suffixed filenames (`15.0.6-4+b1`), and `+` is outside the script's character class; the five debs were fetched directly and the pattern fix noted for the next reset. The surviving compiled definitions from `srw3-kevm/` were reused after verification: abstract demos green, generalized demos 10/10 PASS on the Haskell backend, and the full KEVM binding executing real EVM semantics (COMMIT/REJECT+RESTORE carriers).

The blockchain-k-plugin was re-fetched at the same pinned SHA as every prior phase, `207ae5121e5178a09742ed746f2d15e34b1750cc`, K sources only, into `kproj/plugin/`.

## 3. Finding 1C-1a: kompile silently strips unregistered hook namespaces

The first substantive result of the phase explains all previous §O behavior. Compiling the probe definition (below) produced a definition in which `Keccak256` was a **plain symbol with no hook attribute** — the backend therefore generated no call to any crypto hook, and `krun` left the term stuck. The hook attributes were being removed at the kompile stage, silently, with no warning of any kind.

The mechanism: kompile retains `hook(...)` attributes only for **registered hook namespaces**; `KRYPTO` is not in the default registration. The remedy is the kompile flag `--hook-namespaces KRYPTO`, which is exactly what the KEVM build passes through its pyk driver (`HOOK_NAMESPACES = ('JSON', 'KRYPTO')` in `kevm-pyk/src/kevm_pyk/kompile.py`). With the flag, all 36 KRYPTO hook attributes survive into `definition.kore` as `hooked-symbol` declarations.

This finding retroactively documents the Phase-0 decision: libkrypto was not merely "not built"; **no K definition compiled in any prior phase could have reached a crypto hook at all**, regardless of the C library. The §O limitation is now attributable to a one-flag omission plus a missing library, both cured in this phase.

## 4. Finding 1C-1b: the Haskell backend has no KRYPTO evaluators at all

With hooks preserved, the probe was run on the Haskell backend. `kore-exec` warns — per symbol — `No evaluators for function symbol: LblKeccak256...`, `LblECDSASign...`, `LblECDSARecover...`, `LblECDSAPubKey...`, `LblKeccak256raw...`, and the terms remain stuck. The Haskell backend implements no KRYPTO hooks natively in this toolchain, despite `kore-exec` linking `libsecp256k1.so.0`.

Consequence for the evidence architecture: **cryptographic commitments are an LLVM-backend capability** (the backend that links C code at definition build time). The Haskell backend continues to carry the abstract-layer proofs — the ∀n theorems of Phases 0-D/1B are unaffected — while executable cryptographic grounding lives on the LLVM side. This division of labor is recorded as the standing evidence model: abstract properties are proved symbolically on hs; cryptographic executability is demonstrated concretely on llvm with real hash/ECC libraries.

## 5. The krypto shim: minimal, honest, stub-policy'd

Rather than building the full libkrypto stack (cryptopp + libff + blst + c-kzg; the libff build historically OOMs in this 2-core/4.1 GiB container), Phase 1C builds a **minimal shim** (`k/phase1c/shim/krypto_shim.cpp`, archived as `libkrypto-shim.a`) that provides exactly the hook symbols the SRW3 semantics can reach, in three classes:

1. **Real, locally implemented:** `KRYPTO.keccak256` / `keccak256raw` — a self-contained Keccak-f[1600] with the 1088-bit rate and original Keccak padding (0x01), i.e. Ethereum's keccak256, validated against the canonical external vectors (§7).
2. **Real, plugin-faithful:** `KRYPTO.ecdsaRecover` / `ecdsaSign` / `ecdsaPubKey` — the plugin's own `crypto.cpp` code path (same input checks, same secp256k1 context usage, same return shapes) linked against the pinned libsecp256k1 0.5.0. This is the Part X "libsecp256k1 path" in the most literal sense.
3. **Documented abort stubs:** every other hook declared by `krypto.md` (sha256/sha512/sha3/ripemd families, blake2, ed25519, bn128, bls12, KZG, p256verify) aborts loudly on call — `SRW3 krypto shim: hook X is deliberately NOT implemented` — rather than returning wrong data. SRW3 never exercises these; the stub policy converts silent wrongness into a loud crash, which is the honest trade.

The shim compiles with the pinned clang-15 against the K LLVM runtime headers (`kllvm/runtime/{header,alloc}.h`), gmp, mpfr and secp256k1 dev headers extracted alongside the runtime libs. Linking is via the standard two-step: `kompile --backend llvm --hook-namespaces KRYPTO` (whose internal link fails by design without the library) followed by `llvm-kompile definition.kore dt main -o interpreter -L<shim> -lkrypto-shim -lsecp256k1 -lgmp`. The `NIX_LLVM_KOMPILE_LIBS` environment variable provides the same flags through the kompile-driven path.

## 6. Bring-up defect log (recorded as report material)

Five defects were found and fixed while bringing the probe up; each is a durable K-toolchain fact worth keeping in the project record:

- **`==K` is not term syntax in this K version.** The matching-equality operator `:=K` compiles to pattern matching and is illegal with function calls on its left; plain `==K` (seen in older K) does not parse in rule bodies here. Equality of two *computed* values goes through a self-matching helper (`BytesEq(B,B) => true` / owise-false). Note the frozen Phase-1B surface uses `==K` freely — it is available when a module `imports DOMAINS` (the `K-EQUAL` slice), which the probe did not.
- **`DOMAINS` does not include `BYTES`.** A module importing `DOMAINS` still needs `imports BYTES` for `Int2Bytes`, `+Bytes`, and Bytes literals; otherwise the parser rejects them as unknown tokens.
- **`substrString(S, start, end)` is start/end**, not start/length — a silent off-by-semantics that surfaced as an "index 128 > end 2" abort.
- **`rotl64(x, 0)` is UB in C** (`x >> 64`); the Keccak lane with rho offset 0 hits this immediately and corrupted the permutation. Fixed with an explicit zero-width guard.
- **The rho offset table is orientation-sensitive.** The canonical `r[x][y]` table must be flattened as `RHO[x + 5*y]`; the transposed layout produces a permutation that is wrong but self-consistent — raw and hex outputs still agree (probe P8), so only external vectors expose it. This is precisely why P1/P2 exist.
- (Process finding, not a defect: K Bytes literals are `b"..."`; `0x`-hex is not syntax, so demo programs take hex through a `CkHex` parser function.)

The reference implementation `scripts/keccak_ref.py` (pure-Python keccak-256) was written as an independent oracle during debugging and is retained as a cross-check artifact.

## 7. Part IV + Part X probe: 8/8 green on the LLVM backend

`k/phase1c/krypto-probe.k` (module `PHASE1C-PROBE`) evaluates eight named probes; the transcript is `transcripts/audit/phase1c_krypto_probe.txt`. Results on LLVM + shim:

| # | Probe | Checks | Result |
|---|---|---|---|
| P1 | `IV-keccak256-empty` | keccak256("") = `c5d24601…a470` (canonical vector) | ok |
| P2 | `IV-keccak256-abc` | keccak256("abc") = `4e03657a…6c45` (canonical vector) | ok |
| P3 | `IX-pubkey-of-one` | ECDSAPubKey(priv=1) = 1·G (external secp256k1 vector) | ok |
| P4 | `IX-recover-roundtrip` | recover(hash, 27+recid, r, s) = pubkey(priv) | ok |
| P5 | `IX-wrong-v-neg` | flipped recovery id ≠ signer key | ok |
| P6 | `IX-bad-sig-empty` | malformed (r,s) → empty Bytes | ok |
| P7 | `IVX-address-derivation` | addr = last 20 bytes of keccak256(pubkey); priv=1 → `7e5f4552…9395bdf` (canonical Ethereum tooling value) | ok |
| P8 | `IV-keccak256-raw-hex` | raw and hex APIs agree on the same digest | ok |

P5 deserves a note: the first version hardcoded v=28 as "wrong", which fails whenever the signature's actual recovery id is 1 (28 is then the *correct* v). The control was corrected to flip the recovery id (`v' = 27 + (1 − recid)`), which is wrong by construction. The Haskell-backend control in the same transcript records the absence of evaluators (Finding 1C-1b) for provenance.

**Part IV verdict:** the pinned plugin's keccak256 definitions are usable in this toolchain, on the LLVM backend, through the shim — the §O limitation is lifted for every hook SRW3 uses. **Part X verdict:** the libsecp256k1 path is live end to end — sign, recover, and pubkey derivation all agree with external vectors, and the negative controls reject as designed.

## 8. Integration: cryptographic commitment lineage in the gate (`srw3ck.k`)

`k/phase1c/srw3ck.k` (module `SRW3CK`) is a minimal faithful instance of the Phase-1B gate architecture in which lineage commitments are **real hashes** and the gate **verifies by recomputation**. The shape mirrors `srw3gen.k` — one-gate discipline, evaluated obligations, a single accept rule — reduced to the one-app, one-declared-write instance that isolates the cryptographic mechanism:

- A transition (`ckBegin; ckW(slot,v); ckGate(H)`) **presents** the new head commitment `H:Bytes`.
- The gate's obligations are: **ICK-PRESENT** — `H == CkHash(head, slot, v)` where `CkHash(p, s, v) = Keccak256raw(p ‖ slot₄ᴮᴱ ‖ v₄ᴮᴱ)`; and **ICK-CHAIN** — the entire existing lineage re-derives record-by-record from the root (32 zero bytes): each record's parent equals the expected running hash and its child equals the recomputed hash of its own fields.
- The accept rule is the only rule that updates `<committed>`, `<head>` and `<lineage>` (append `cklin(parent=head, tid, slot, v, child=H)`); the reject rule restores — prospective discarded, pend cleared — the commitment boundary exactly as in the abstract layer.

The demo commitments were computed **offline** with `scripts/keccak_ref.py` — the model never generates its own test data: `H1 = d9e1dd8a…33f5` (root‖0‖7), `H2 = f9c13403…616b` (H1‖0‖9), and a tampered `H1' = …33f4` (final bit flipped).

Transcript `transcripts/audit/phase1c_ck_demos.txt`; all three demos on LLVM + shim:

| Demo | Program shape | Outcome |
|---|---|---|
| `ck_chain_positive` | two transitions presenting H1 then H2 | **commit**; final head = H2 (raw bytes in transcript), lineageNext = 2 — a two-record real-keccak chain |
| `ck_tamper_reject` | presents H1' then the (now stale) H2 | **reject**; the chain does not advance, and the second gate also rejects because the stale H2's parent no longer matches the head — restoration semantics deny any progress on a tampered step |
| `ck_recover` | presents H1' (rejected), then re-presents the correct H1 | **commit** — after a rejected transition the honest commitment is accepted with pend/prospective cleanly restored |

This is the cryptographic-lineage open item retired at the execution layer: the gate now rejects any transition whose presented commitment does not re-derive, and any lineage that does not re-derive from the root, inside the unchanged one-gate architecture.

## 9. Assumption classification after Phase 1C

With the five-level evidence scheme from the Phase-1B report:

- **A5 (resmap derivation)** — upgraded from ASSUMED to **ASSUMED-CRYPTO-READY**: the alias table remains model input at the abstract layer, but the commitment machinery that an on-chain anchoring would verify is now executable and vector-validated (P1–P8, §8 demos). Remaining work is data-plumbing (reading the alias facts from a verified commitment), not cryptography.
- **A6 (cryptographic lineage)** — upgraded from ASSUMED to **DEMONSTRATED (execution layer)**: real keccak256 lineage chains with gate-verified presented commitments and tamper rejection (§8). The ∀n safety statements continue to live at the abstract layer by design (Finding 1C-1b: hs cannot evaluate crypto hooks), so the abstract↔crypto correspondence rests on the architecture identity between `srw3ck.k` and the `srw3gen.k` gate shape, which is by-construction (same rule skeleton, same single-accept discipline).
- **Tier-3 universal** — unchanged, out of Phase-1C scope.

## 10. Limitations

The shim implements only the hooks SRW3 can reach; bn128/bls12/KZG/blake2/sha-family hooks abort by policy and would need the full libkrypto (or per-hook implementations) if future phases touch the corresponding precompiles. The cryptographic demos run on the LLVM backend only — this is a recorded property of the toolchain (Finding 1C-1b), not a defect of the model. The `srw3ck.k` instance is single-app/single-write by design: its purpose is to isolate and demonstrate the cryptographic mechanism inside the gate skeleton, not to replace the generalized abstract layer, which remains the home of the ∀n theorems. The KEVM-storage binding (Phase 1B) and the crypto binding (this phase) are integrated additively and have not yet been composed into a single definition that hashes real EVM storage snapshots; that composition is the natural Phase-2 opening.

## 11. Artifact index

| Artifact | Path |
|---|---|
| Probe definition | `k/phase1c/krypto-probe.k` (+ `probe.pgm`, `dbg.k` bring-up artifact) |
| Gate integration | `k/phase1c/srw3ck.k` (+ `ck_chain_positive.ck`, `ck_tamper_reject.ck`, `ck_recover.ck`) |
| Krypto shim | `k/phase1c/shim/krypto_shim.cpp` (+ `plugin_util.{h,cpp}` from the pinned plugin) |
| Reference oracle | `scripts/keccak_ref.py` |
| Probe transcript | `transcripts/audit/phase1c_krypto_probe.txt` |
| Demo transcript | `transcripts/audit/phase1c_ck_demos.txt` |
| Git lineage | branch `phase1c` (commits `402a3f9`, `25b875b`), tag `phase1b-complete` = `e132157` preserved |
| Backup | github.com/Dannyednut/SRW3 — branches `main` (archive), `phase1b`, `phase1c` |
