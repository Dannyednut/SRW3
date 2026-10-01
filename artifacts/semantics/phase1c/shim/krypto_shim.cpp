// =============================================================================
// krypto_shim.cpp — SRW3 Phase 1C minimal libkrypto provider
//
// Provides the hook_KRYPTO_* symbols that the pinned blockchain-k-plugin
// (207ae5121e5178a09742ed746f2d15e34b1750cc) declares in plugin/krypto.md,
// without building the full cryptopp/libff/blst/c-kzg stack (Phase-0 §O).
//
// REAL implementations (validated by k/phase1c/krypto-probe.k against external
// test vectors):
//   * KRYPTO.keccak256 / keccak256raw — Keccak-f[1600], 1088-bit rate,
//     original Keccak padding (0x01), i.e. Ethereum's keccak256. Implemented
//     locally; no external dependencies.
//   * KRYPTO.ecdsaRecover / ecdsaSign / ecdsaPubKey — code path identical to
//     the plugin's plugin-c/crypto.cpp, against the pinned libsecp256k1 0.5.0.
//     This is the Part X "libsecp256k1 path".
//
// ABORT stubs (hooks the SRW3 semantics never exercises; documented in the
// Phase-1C report): sha256/raw, sha512*, sha3*, ripemd160*, blake2*, ed25519,
// bn128*, bls12*, verifyKZGProof, p256verify. Calling one aborts loudly
// instead of silently returning wrong data.
//
// ABI note: all hooks are extern "C" (unmangled) exactly as in crypto.cpp, so
// the K LLVM backend's generated calls resolve against this archive.
// =============================================================================

#include <cstdint>
#include <cstdio>
#include <cstdlib>
#include <cstring>

#include <gmp.h>
#include <secp256k1_recovery.h>

#include "plugin_util.h"

extern "C" {

// -----------------------------------------------------------------------------
// Keccak-f[1600] — Ethereum keccak256 (padding byte 0x01, rate 136 bytes)
// -----------------------------------------------------------------------------

namespace {

const int KECCAK_RATE = 136;  // bytes; 1088-bit rate for 256-bit digest

inline uint64_t rotl64(uint64_t x, int n) {
  // n == 0 is common (lane 0 has rho offset 0); x >> 64 would be UB
  return n == 0 ? x : ((x << n) | (x >> (64 - n)));
}

// Keccak round constants
const uint64_t RC[24] = {
    0x0000000000000001ULL, 0x0000000000008082ULL, 0x800000000000808aULL,
    0x8000000080008000ULL, 0x000000000000808bULL, 0x0000000080000001ULL,
    0x8000000080008081ULL, 0x8000000000008009ULL, 0x000000000000008aULL,
    0x0000000000000088ULL, 0x0000000080008009ULL, 0x000000008000000aULL,
    0x000000008000808bULL, 0x800000000000008bULL, 0x8000000000008089ULL,
    0x8000000000008003ULL, 0x8000000000008002ULL, 0x8000000000000080ULL,
    0x000000000000800aULL, 0x800000008000000aULL, 0x8000000080008081ULL,
    0x8000000000008080ULL, 0x0000000080000001ULL, 0x8000000080008008ULL};

// rho rotation offsets, flattened as RHO[x + 5*y]; columns of the
// canonical r[x][y] table (x=0 column: r[0][0..4] = 0,36,3,41,18 ...)
const int RHO[25] = {0,  1, 62, 28, 27, 36, 44, 6,  55, 20, 3,  10, 43,
                     25, 39, 41, 45, 15, 21, 8,  18, 2,  61, 56, 14};

inline int lane_index(int x, int y) { return x + 5 * y; }

void keccakf1600(uint64_t st[25]) {
  for (int round = 0; round < 24; ++round) {
    // theta
    uint64_t bc[5];
    for (int i = 0; i < 5; ++i) {
      bc[i] = st[lane_index(i, 0)] ^ st[lane_index(i, 1)] ^
              st[lane_index(i, 2)] ^ st[lane_index(i, 3)] ^
              st[lane_index(i, 4)];
    }
    for (int i = 0; i < 5; ++i) {
      uint64_t t = bc[(i + 4) % 5] ^ rotl64(bc[(i + 1) % 5], 1);
      for (int j = 0; j < 5; ++j) {
        st[lane_index(i, j)] ^= t;
      }
    }
    // rho + pi
    uint64_t tmp[25];
    for (int x = 0; x < 5; ++x) {
      for (int y = 0; y < 5; ++y) {
        int nx = y;
        int ny = (2 * x + 3 * y) % 5;
        tmp[lane_index(nx, ny)] =
            rotl64(st[lane_index(x, y)], RHO[lane_index(x, y)]);
      }
    }
    // chi
    for (int j = 0; j < 5; ++j) {
      for (int i = 0; i < 5; ++i) {
        st[lane_index(i, j)] = tmp[lane_index(i, j)] ^
                               ((~tmp[lane_index((i + 1) % 5, j)]) &
                                tmp[lane_index((i + 2) % 5, j)]);
      }
    }
    // iota
    st[0] ^= RC[round];
  }
}

// little-endian byte absorption into the 25-lane state
void keccak256(const unsigned char *in, size_t inlen, unsigned char out[32]) {
  uint64_t st[25] = {0};
  unsigned char *block = (unsigned char *)st;  // lanes are LE on x86-64

  while (inlen >= KECCAK_RATE) {
    for (size_t i = 0; i < KECCAK_RATE; ++i) {
      block[i] ^= in[i];
    }
    keccakf1600(st);
    in += KECCAK_RATE;
    inlen -= KECCAK_RATE;
  }

  // final block + padding (original Keccak: 0x01 ... 0x80)
  memset(block, 0, KECCAK_RATE);
  for (size_t i = 0; i < inlen; ++i) {
    block[i] ^= in[i];
  }
  block[inlen] ^= 0x01;
  block[KECCAK_RATE - 1] ^= 0x80;
  keccakf1600(st);

  memcpy(out, st, 32);  // first 32 bytes of the squeezed state
}

}  // namespace

// -----------------------------------------------------------------------------
// Hook implementations
// -----------------------------------------------------------------------------

struct string *hook_KRYPTO_keccak256raw(struct string *str) {
  unsigned char digest[32];
  keccak256((const unsigned char *)str->data, len(str), digest);
  return raw(digest, sizeof(digest));
}

struct string *hook_KRYPTO_keccak256(struct string *str) {
  unsigned char digest[32];
  keccak256((const unsigned char *)str->data, len(str), digest);
  return hexEncode(digest, sizeof(digest));
}

// matches evm and bitcoin's value of V, which is in the range 27-28
struct string *hook_KRYPTO_ecdsaRecover(struct string *str, mpz_t v,
                                        struct string *r, struct string *s) {
  if (len(str) != 32 || len(r) != 32 || len(s) != 32) {
    return allocString(0);
  }
  unsigned char sigArr[64];
  memcpy(sigArr, r->data, 32);
  memcpy(sigArr + 32, s->data, 32);
  secp256k1_context *ctx = secp256k1_context_create(SECP256K1_CONTEXT_VERIFY |
                                                    SECP256K1_CONTEXT_SIGN);
  if (!mpz_fits_ulong_p(v)) {
    return allocString(0);
  }
  unsigned long v_long = mpz_get_ui(v);
  if (v_long < 27 || v_long > 28) {
    return allocString(0);
  }
  secp256k1_ecdsa_recoverable_signature sig;
  if (!secp256k1_ecdsa_recoverable_signature_parse_compact(ctx, &sig, sigArr,
                                                           v_long - 27)) {
    return allocString(0);
  }
  secp256k1_pubkey key;
  if (!secp256k1_ecdsa_recover(ctx, &key, &sig, (unsigned char *)str->data)) {
    return allocString(0);
  }
  unsigned char serialized[65];
  size_t outlen = sizeof(serialized);
  secp256k1_ec_pubkey_serialize(ctx, serialized, &outlen, &key,
                                SECP256K1_EC_UNCOMPRESSED);
  struct string *result = allocString(64);
  memcpy(result->data, serialized + 1, 64);
  return result;
}

struct string *hook_KRYPTO_ecdsaSign(struct string *mhash,
                                     struct string *prikey) {
  if (len(prikey) != 32 || len(mhash) != 32) {
    return hexEncode(nullptr, 0);
  }
  secp256k1_context *ctx = secp256k1_context_create(SECP256K1_CONTEXT_SIGN);
  secp256k1_ecdsa_recoverable_signature sig;
  if (!secp256k1_ecdsa_sign_recoverable(ctx, &sig, (unsigned char *)mhash->data,
                                        (unsigned char *)prikey->data, NULL,
                                        NULL)) {
    return hexEncode(nullptr, 0);
  }
  unsigned char result[65];
  int recid;
  if (!secp256k1_ecdsa_recoverable_signature_serialize_compact(ctx, result,
                                                               &recid, &sig)) {
    return hexEncode(nullptr, 0);
  }
  result[64] = recid;
  return hexEncode(result, 65);
}

struct string *hook_KRYPTO_ecdsaPubKey(struct string *prikey) {
  if (len(prikey) != 32) {
    return hexEncode(nullptr, 0);
  }
  secp256k1_context *ctx = secp256k1_context_create(SECP256K1_CONTEXT_SIGN);
  secp256k1_pubkey pubkey;
  if (!secp256k1_ec_pubkey_create(ctx, &pubkey,
                                  (unsigned char *)prikey->data)) {
    return hexEncode(nullptr, 0);
  }
  unsigned char keystring[65];
  size_t outputlen = 65;
  secp256k1_ec_pubkey_serialize(ctx, keystring, &outputlen, &pubkey,
                                SECP256K1_EC_UNCOMPRESSED);
  return hexEncode(keystring + 1, outputlen - 1);
}

// -----------------------------------------------------------------------------
// Abort stubs — hooks declared by krypto.md but NOT exercised by SRW3
// (see the Phase-1C report §stub-policy). A call aborts loudly.
// -----------------------------------------------------------------------------

[[noreturn]] static void unimplemented(const char *name) {
  fprintf(stderr,
          "SRW3 krypto shim: hook %s is deliberately NOT implemented "
          "(not exercised by SRW3; see Phase-1C report stub policy)\n",
          name);
  abort();
}

struct string *hook_KRYPTO_sha512raw(struct string *) { unimplemented("KRYPTO.sha512raw"); }
struct string *hook_KRYPTO_sha512(struct string *) { unimplemented("KRYPTO.sha512"); }
struct string *hook_KRYPTO_sha512_256raw(struct string *) { unimplemented("KRYPTO.sha512_256raw"); }
struct string *hook_KRYPTO_sha512_256(struct string *) { unimplemented("KRYPTO.sha512_256"); }
struct string *hook_KRYPTO_sha3raw(struct string *) { unimplemented("KRYPTO.sha3raw"); }
struct string *hook_KRYPTO_sha3(struct string *) { unimplemented("KRYPTO.sha3"); }
struct string *hook_KRYPTO_sha256raw(struct string *) { unimplemented("KRYPTO.sha256raw"); }
struct string *hook_KRYPTO_sha256(struct string *) { unimplemented("KRYPTO.sha256"); }
struct string *hook_KRYPTO_ripemd160raw(struct string *) { unimplemented("KRYPTO.ripemd160raw"); }
struct string *hook_KRYPTO_ripemd160(struct string *) { unimplemented("KRYPTO.ripemd160"); }
struct string *hook_KRYPTO_blake2compress(struct string *) { unimplemented("KRYPTO.blake2compress"); }
struct string *hook_KRYPTO_blake2b256raw(struct string *) { unimplemented("KRYPTO.blake2b256raw"); }
struct string *hook_KRYPTO_blake2b256(struct string *) { unimplemented("KRYPTO.blake2b256"); }
bool hook_KRYPTO_ed25519verify(struct string *, struct string *, struct string *) { unimplemented("KRYPTO.ed25519verify"); }
bool hook_KRYPTO_bn128valid(void *) { unimplemented("KRYPTO.bn128valid"); }
bool hook_KRYPTO_bn128g2valid(void *) { unimplemented("KRYPTO.bn128g2valid"); }
void *hook_KRYPTO_bn128add(void *, void *) { unimplemented("KRYPTO.bn128add"); }
void *hook_KRYPTO_bn128mul(void *, mpz_t) { unimplemented("KRYPTO.bn128mul"); }
bool hook_KRYPTO_bn128ate(void *, void *) { unimplemented("KRYPTO.bn128ate"); }
bool hook_KRYPTO_bls12G1OnCurve(void *) { unimplemented("KRYPTO.bls12G1OnCurve"); }
bool hook_KRYPTO_bls12G2OnCurve(void *) { unimplemented("KRYPTO.bls12G2OnCurve"); }
void *hook_KRYPTO_bls12G1Add(void *, void *) { unimplemented("KRYPTO.bls12G1Add"); }
void *hook_KRYPTO_bls12G2Add(void *, void *) { unimplemented("KRYPTO.bls12G2Add"); }
void *hook_KRYPTO_bls12G1Mul(void *, mpz_t) { unimplemented("KRYPTO.bls12G1Mul"); }
void *hook_KRYPTO_bls12G2Mul(void *, mpz_t) { unimplemented("KRYPTO.bls12G2Mul"); }
bool hook_KRYPTO_bls12G1InSubgroup(void *) { unimplemented("KRYPTO.bls12G1InSubgroup"); }
bool hook_KRYPTO_bls12G2InSubgroup(void *) { unimplemented("KRYPTO.bls12G2InSubgroup"); }
bool hook_KRYPTO_bls12PairingCheck(void *, void *) { unimplemented("KRYPTO.bls12PairingCheck"); }
void *hook_KRYPTO_bls12MapFpToG1(void *) { unimplemented("KRYPTO.bls12MapFpToG1"); }
void *hook_KRYPTO_bls12MapFp2ToG2(void *) { unimplemented("KRYPTO.bls12MapFp2ToG2"); }
void *hook_KRYPTO_bls12G1Msm(void *, void *) { unimplemented("KRYPTO.bls12G1Msm"); }
void *hook_KRYPTO_bls12G2Msm(void *, void *) { unimplemented("KRYPTO.bls12G2Msm"); }
bool hook_KRYPTO_verifyKZGProof(void *, void *, void *, void *) { unimplemented("KRYPTO.verifyKZGProof"); }
bool hook_KRYPTO_p256verify(void *, void *, void *, void *) { unimplemented("KRYPTO.p256verify"); }

}  // extern "C"
