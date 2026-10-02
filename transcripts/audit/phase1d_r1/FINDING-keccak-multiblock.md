# Finding 1D-R1-KECCAK-MULTIBLOCK — shim keccak256 incorrect for inputs >= 136 bytes

Discovered: 2026-10-02, during Phase 1D-R1 Part I byte-level pre-validation
(K<->Python digest comparison for the lin_true_effects record).

## Symptom

The independent Python verifier's keccak256 of the K-side CoreHash preimage
(LinCanonCore output, 237 bytes) diverges from the K side:

    Python keccak256(canon_core) = c763b6d536a6e1a1a2d295275a0899f73077edae5637dcf7b71dbdc497a33254
    K LinCoreHash(...)           = bad218ffeef218f41d115b99ef83d4387814e1ccc7e3ad9e745fffac7e250421

The canon bytes themselves are byte-identical on both sides (probe:
transcripts/audit/phase1d_r1/keccak_multiblock_canon_probe.txt — K
LinCanonCore vs Python canon_core, EQUAL over all 237 bytes; the evidence
signature segment matches byte-for-byte, i.e. RFC6979 ECDSA is consistent).

## Isolation

Literal-input hash probe (srw3lin-hashprobe.k, transcript
keccak_multiblock_hash_probe.txt): the shim keccak256raw matches Python for
inputs of 0, 2, 3, 129, and 132 bytes, and MISMATCHES for a 136-byte input:

    K  keccak256raw(bytes 0x00..0x87, 136 B) = d6d2a509a802642a798434a6251fb2defdbbe00e736ee08a21e5abccf345e97
    PY keccak256     (bytes 0x00..0x87, 136 B) = 7ce759f1ab7f9ce437719970c26b0a66ff11fe3e38e17df89cf5d29c7d7f807e

Boundary: inputs < 136 bytes (the Keccak-f[1600] rate, 1088 bits) are hashed
correctly; inputs >= 136 bytes are hashed incorrectly.

## Root cause (k/phase1c/shim/krypto_shim.cpp, keccak256())

    while (inlen >= KECCAK_RATE) { absorb block; keccakf1600(st); ... }
    memset(block, 0, KECCAK_RATE);        // <-- block aliases st (17 lanes)
    for (i < inlen) block[i] ^= in[i];
    block[inlen] ^= 0x01; block[RATE-1] ^= 0x80;
    keccakf1600(st);

`block` is an alias of the 25-lane state `st`. The memset before the final
block zeroes lanes 0..16 (136 bytes) — destroying the state accumulated from
all absorbed full blocks whenever the input fills at least one full block.
For single-block inputs the memset is a no-op (state already zero), which is
why every previously recorded probe (short vectors) passed.

Mechanical confirmation: scripts/shim_keccak_sim.py transcribes the C
function faithfully in Python and reproduces the K-side CoreHash output
EXACTLY (bad218ff...) while correct keccak gives c763b6d5...

## Impact on the Phase 1D surface

Preimage sizes (prototype model):

    IntentHash  = 4 + 32 + 32 + 32        = 100 B  < 136  -> CORRECT
    stateD/inputD/effectD (canon_kv)      : demo maps < 136 B -> CORRECT;
                                            larger states would diverge
    CoreHash   = 237 B (>= 136)           -> NON-STANDARD DIGEST
    Child      = 306 B (>= 136)           -> NON-STANDARD DIGEST

Consequences:

1. All K-side record CoreHash/Child values are NOT Ethereum keccak256
   digests. The Phase-1C/1D claim "commitments = real Keccak256raw" holds
   only for single-block preimages and MUST be re-classified as an
   overclaim for CoreHash/Child.
2. Within-K consistency (build vs verify) is unaffected — both sides use
   the same deterministic H — so the demo/proof surfaces (tamper matrix,
   chain continuity, replay defense, KEVM composition) remain internally
   valid as MECHANISMS; all frozen verdicts stand.
3. Cross-layer byte equality (R1 Part XIII, Python<->K<->KEVM) FAILS today
   for CoreHash/Child. The R1 close criterion "cross-layer consistent"
   therefore requires the shim fix.
4. The authorized-dishonest-producer analysis is NOT weakened by this
   finding (the digest function is deterministic and collision-resistant
   in practice on both sides); it is an interoperability/faithfulness
   defect, not a soundness hole in the record protocol itself.

## Disposition (R1)

* Part I (this file): pre-fix state frozen; finding recorded; the hash
  probe suite (srw3lin-hashprobe.k, h1..h6) becomes a PERMANENT regression
  probe with post-fix expectation = standard keccak256 on all six vectors.
* Part II: one-line shim fix (zero a local final-block buffer instead of
  the aliased state; never memset the absorbed state), rebuild the 1C shim
  and the 1D LLVM definitions, re-run the live regression surface, and
  re-validate K<->Python byte equality end-to-end.
* The L7 attack reproduction (l7_attack_prefix.txt) is unaffected by this
  finding: the Python verifier uses correct keccak throughout.
