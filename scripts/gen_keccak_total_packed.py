#!/usr/bin/env python3
"""
SRW3 Phase 1M — Workstream B, Route 1: generate the packed-Int total
Keccak-256 evaluator (pure K, no hooks, no Maps).

The state is a single 1600-bit Int (lane i = x + 5*y at bits 64i..64i+63,
little-endian lane order).  Every stage is a generated, fully-literal-indexed
pure-Int reduction — no map updates, no linear scans (the Map-based first
attempt OOM-killed the Haskell backend krun at 4 GB; see the phase1m
failed-attempts record).

FIXES OF RECORD (all found by the vector validation):
  1. PADDING: interior pad emits KZeros(134 -Int Q), NOT KZeros(Q -Int 2) —
     the padded block must total 136 bytes (the first build's rule was
     inherited from the unvalidated Map attempt and produced 6-byte streams).
  2. XOR CONVENTION: in K, `^Int` is EXPONENTIATION (INT.pow); bitwise XOR is
     `xorInt` (INT.xor).  Every XOR-intent site uses xorInt (the first build
     used ^Int and the LLVM interpreter died computing x**(2**64-1) inside
     KNot64T — SIGFPE).
  3. ABSORB RECURSION: the remainder slice is substrBytes(B, 136,
     lengthBytes(B)) — NOT lengthBytes(B) -Int 136 (which made the remainder
     EMPTY and silently dropped every second block); and the == 136 base rule
     exists because the LLVM Bytes hook substrBytes RAISES on start > end
     (substrBytes(B, 136, 0) is an error, not the empty stream).

Emits: phase1m/semantics/keccak256_total.k  (module KECCAK256-TOTAL)
"""
from pathlib import Path

OUT = Path("/home/z/my-project/srw3-1m/phase1m/semantics/keccak256_total.k")

# rho offsets: OFFS[x][y] (standard table)
OFFS = [
    [0, 36, 3, 41, 18],
    [1, 44, 10, 45, 2],
    [62, 6, 43, 15, 61],
    [28, 55, 25, 21, 56],
    [27, 20, 39, 8, 14],
]
RC = [
    0x0000000000000001, 0x0000000000008082, 0x800000000000808A,
    0x8000000080008000, 0x000000000000808B, 0x0000000080000001,
    0x8000000080008081, 0x8000000000008009, 0x000000000000008A,
    0x0000000000000088, 0x0000000080008009, 0x000000008000000A,
    0x000000008000808B, 0x800000000000008B, 0x8000000000008089,
    0x8000000000008003, 0x8000000000008002, 0x8000000000000080,
    0x000000000000800A, 0x800000008000000A, 0x8000000080008081,
    0x8000000000008080, 0x0000000080000001, 0x8000000080008008,
]

L = lambda i: f"KLaneT(S, {i})"
LB = lambda i: f"KLaneT(B, {i})"


def lane_coords(i):
    return (i % 5, i // 5)


# ---------- Theta ----------
def gen_theta():
    c = [f"{L(0)} xorInt {L(5)} xorInt {L(10)} xorInt {L(15)} xorInt {L(20)}"]
    for x in range(1, 5):
        lanes = " xorInt ".join(L(x + 5 * y) for y in range(5))
        c.append(lanes)
    # D[x] = C[(x+4)%5] ^ Rot(C[(x+1)%5], 1)
    d = []
    for x in range(5):
        d.append(f"KC{ (x + 4) % 5 }(S) xorInt KRotT( KC{ (x + 1) % 5 }(S), 1 )")
    body = "S"
    for i in range(24, -1, -1):
        x, _ = lane_coords(i)
        body = f"KSetLaneT( {body}, {i}, {L(i)} xorInt KD{x}(S) )"
    return c, d, body


# ---------- Rho + Pi (target j <- Rot(lane src, off)) ----------
def gen_rhopi():
    pairs = []
    for i in range(25):
        x, y = lane_coords(i)
        j = y + 5 * ((2 * x + 3 * y) % 5)
        pairs.append((j, i, OFFS[x][y]))
    pairs.sort()  # by target index, ascending — deterministic emission
    terms = []
    for j, src, off in pairs:
        terms.append(f"( KRotT( {L(src)}, {off} ) <<Int {64 * j} )")
    return " |Int\n       ".join(terms)


# ---------- Chi ----------
def gen_chi():
    body = "B"
    for i in range(24, -1, -1):
        x, y = lane_coords(i)
        a1 = (x + 1) % 5 + 5 * y
        a2 = (x + 2) % 5 + 5 * y
        expr = f"{LB(i)} xorInt ( KNot64T( {LB(a1)} ) &Int {LB(a2)} )"
        body = f"KSetLaneT( {body}, {i}, {expr} )"
    return body


# ---------- Iota ----------
def gen_iota():
    return "KSetLaneT( S, 0, KLaneT(S, 0) xorInt KRC(R) )"


# ---------- absorb one 136-byte block into lanes 0..16 ----------
def gen_absorb():
    # PURE SetLane chain: each write targets a DISTINCT literal lane and each
    # value reads KLaneT(S, i) from the ORIGINAL state — no recursion, no
    # double absorption.
    body = "S"
    for i in range(17):
        v = (f"KLaneT(S, {i}) xorInt "
             f"Bytes2Int( substrBytes(B, {8 * i}, {8 * i + 8}), LE, Unsigned )")
        body = f"KSetLaneT( {body}, {i}, {v} )"
    return body


def main():
    c_lines, d_lines, theta_body = gen_theta()
    rhopi = gen_rhopi()
    chi_body = gen_chi()
    absorb = gen_absorb()

    rc_rules = "\n".join(f"  rule KRC({i}) => {v}" for i, v in enumerate(RC))

    kc_rules = "\n\n".join(
        f"  syntax Int ::= KC{x} ( Int ) [function, total]\n"
        f"  rule KC{x}(S:Int)\n    => {c_lines[x]}"
        for x in range(5)
    )
    kd_rules = "\n\n".join(
        f"  syntax Int ::= KD{x} ( Int ) [function, total]\n"
        f"  rule KD{x}(S:Int)\n    => {d_lines[x]}"
        for x in range(5)
    )

    header = f"""\
// =============================================================================
// SRW3 PHASE 1M — THE TOTAL DETERMINISTIC KECCAK-256 EVALUATOR (pure K,
//                    PACKED-INT STATE; generated by
//                    scripts/gen_keccak_total_packed.py — do not hand-edit)
//                    (phase1m/semantics/keccak256_total.k)
//
// THE HASH-DEFINEDNESS BLOCKER (phase1l/audit/induction-diagnosis.md B1),
// REMOVED BY CONSTRUCTION: the KRYPTO Keccak256raw HOOK is partial on the
// Haskell backend (no evaluator over symbolic/hash-containing arguments), so
// every proof path that MATERIALIZES a hash application over such arguments
// dies with an undischargeable #Ceil(Keccak256raw(...)).  THIS module defines
// Keccak256T: a REAL, DETERMINISTIC, TOTAL Keccak-256 evaluator written in
// plain K rules (NO hooks) — Keccak-f[1600], 24 rounds, rate 136 bytes,
// ORIGINAL Keccak padding (0x01 ... 0x80 — the Ethereum KRYPTO.keccak256raw
// convention), little-endian lane load/store.
//
// ENCODING: the state is ONE 1600-bit Int (lane i = x + 5*y at bits
// 64i .. 64i+63); every stage is a fully-literal-indexed pure-Int reduction.
// This replaces the FIRST attempt (a Map-keyed state; preserved with its
// disposition at phase1m/audit/failed-attempts/ — the Haskell-backend krun
// of the full hash was killed, exit 137, on the 4 GB host: the map-update
// churn of the round stages exhausted memory).  The packed encoding has NO
// map updates and NO linear scans; the algorithm is IDENTICAL (same tables,
// same padding, same lane order) and is pinned to the Keccak-256 test
// vectors and cross-checked BYTE-FOR-BYTE against the backend hook
// Keccak256raw (real Keccak, LLVM krypto shim) — see the M2 validation
// transcripts.
//
//   * TOTAL by the [function,total] annotation AND by construction: the
//     padding rules partition lengthBytes(M) modInt 136 exactly (0 / 135 /
//     interior); the absorb rules partition the padded stream by
//     lengthBytes == 0 / == 136 / > 136 (the padded stream is always a
//     positive multiple of 136); every stage is a literal-indexed pure-Int
//     reduction.  #Ceil(Keccak256T(x)) therefore discharges for EVERY
//     argument — literal, symbolic, or nested-hash.
//   * DETERMINISTIC and EXACT: pinned to the Keccak-256 test vectors (the
//     empty string c5d24601...a470, "abc" 4e03657a...6c45, the 135/136/137
//     boundary vectors, and a two-block 215-byte vector) — M2 transcripts,
//     executed on BOTH backends.
//   * NO hash EQUALITY, collision resistance, preimage resistance, or
//     injectivity is assumed or derived anywhere: the evaluator COMPUTES;
//     hash equalities remain claim hypotheses where they are hypotheses,
//     and the M2 negative controls enforce that totality grants no
//     equality power (the weakened controls must keep failing).
//   * PROOF FACING: the M2 machine's hash leaf LinH is redirected to
//     Keccak256T by a priority rule (the machine-side redirect); the frozen
//     machine's executable tier keeps the real hook.  On concrete inputs
//     the two agree byte-for-byte (the pinned vectors); on symbolic inputs
//     Keccak256T stays a defined opaque term (no Ceil) where Keccak256raw
//     was UNDEFINED (the blocker).
// =============================================================================
"""

    core = f"""
module KECCAK256-TOTAL
  imports INT-SYNTAX
  imports INT-COMMON
  imports BOOL
  imports BYTES

  // ---------------------------------------------------------------------
  // 64-bit mask / rotation / lane access on the packed state
  // ---------------------------------------------------------------------
  syntax Int ::= "KMask64" [function, total]
  rule KMask64 => 18446744073709551615

  syntax Int ::= KRotT ( Int , Int ) [function, total]
  rule KRotT(V:Int, 0) => V
  rule KRotT(V:Int, N:Int)
    => ( ( V <<Int N ) |Int ( V >>Int ( 64 -Int N ) ) ) &Int KMask64
    requires N >Int 0 andBool N <Int 64

  // lane i lives at bits 64i .. 64i+63 of the packed state
  syntax Int ::= KLaneT ( Int , Int ) [function, total]
  rule KLaneT(S:Int, I:Int) => ( S >>Int ( 64 *Int I ) ) &Int KMask64

  syntax Int ::= KSetLaneT ( Int , Int , Int ) [function, total]
  rule KSetLaneT(S:Int, I:Int, V:Int)
    => ( S &Int ~Int ( KMask64 <<Int ( 64 *Int I ) ) )
       |Int ( ( V &Int KMask64 ) <<Int ( 64 *Int I ) )

  syntax Int ::= KNot64T ( Int ) [function, total]
  rule KNot64T(X:Int) => X xorInt KMask64

  // ---------------------------------------------------------------------
  // Round constants (Keccak-f[1600], 24 rounds)
  // ---------------------------------------------------------------------
  syntax Int ::= KRC ( Int ) [function, total]
{rc_rules}

  // ---------------------------------------------------------------------
  // Theta — column parities C[x], diffusion D[x], applied to all 25 lanes
  // ---------------------------------------------------------------------
{kc_rules}

{kd_rules}

  syntax Int ::= KThetaT ( Int ) [function, total]
  rule KThetaT(S:Int)
    => {theta_body}

  // ---------------------------------------------------------------------
  // Rho + Pi — fully unrolled (literal target shifts; the pi table is a
  // bijection so the 25 shifted lanes OR together without overlap)
  // ---------------------------------------------------------------------
  syntax Int ::= KRhoPiT ( Int ) [function, total]
  rule KRhoPiT(S:Int)
    => {rhopi}

  // ---------------------------------------------------------------------
  // Chi — A'[x,y] = B[x,y] ^ ( ~B[x+1,y] & B[x+2,y] ), fully unrolled
  // ---------------------------------------------------------------------
  syntax Int ::= KChiT ( Int ) [function, total]
  rule KChiT(B:Int)
    => {chi_body}

  // ---------------------------------------------------------------------
  // Iota + the round function + the 24-round permutation
  // ---------------------------------------------------------------------
  syntax Int ::= KIotaT ( Int , Int ) [function, total]
  rule KIotaT(S:Int, R:Int)
    => {gen_iota()}

  syntax Int ::= KRoundT ( Int , Int ) [function, total]
  rule KRoundT(S:Int, R:Int) => KIotaT( KChiT( KRhoPiT( KThetaT(S) ) ), R )

  syntax Int ::= KeccakFT ( Int , Int ) [function, total]
  rule KeccakFT(S:Int, 24) => S
  rule KeccakFT(S:Int, R:Int) => KeccakFT( KRoundT(S, R), R +Int 1 )
    requires R >=Int 0 andBool R <Int 24

  // ---------------------------------------------------------------------
  // Padding (ORIGINAL Keccak: 0x01 ... 0x80; the KRYPTO.keccak256raw
  // convention).  The three rules partition lengthBytes(M) modInt 136
  // exactly: 0 (full pad block), 135 (single 0x81 byte), 1..134 interior.
  // FIX OF RECORD: the interior rule pads with KZeros(134 -Int Q) — the
  // padded block totals 136 bytes.
  // ---------------------------------------------------------------------
  syntax Bytes ::= KPad ( Bytes ) [function, total]
  rule KPad(M:Bytes) => KPadFrom(M, lengthBytes(M) modInt 136)

  syntax Bytes ::= KPadFrom ( Bytes , Int ) [function, total]
  rule KPadFrom(M:Bytes, 0) => M +Bytes KPadFullBlock()
  rule KPadFrom(M:Bytes, 135) => M +Bytes Int2Bytes(1, 129, BE)  // 0x81
  rule KPadFrom(M:Bytes, Q:Int)
    => M +Bytes Int2Bytes(1, 1, BE) +Bytes KZeros(134 -Int Q)
       +Bytes Int2Bytes(1, 128, BE)
    requires Q >Int 0 andBool Q <Int 135

  syntax Bytes ::= KPadFullBlock() [function, total]
  rule KPadFullBlock() => Int2Bytes(1, 1, BE) +Bytes KZeros(134)
                         +Bytes Int2Bytes(1, 128, BE)

  syntax Bytes ::= KZeros ( Int ) [function, total]
  rule KZeros(0) => .Bytes
  rule KZeros(N:Int) => Int2Bytes(1, 0, BE) +Bytes KZeros(N -Int 1)
    requires N >Int 0

  // ---------------------------------------------------------------------
  // Absorption: one 136-byte block XORed into the rate lanes 0..16 as a
  // PURE SetLane chain (each write targets a distinct literal lane, each
  // value reads the ORIGINAL state — no recursion, no double absorption).
  // The block reader's substrBytes bounds are literal and guarded by
  // lengthBytes(B) ==Int 136.
  // ---------------------------------------------------------------------
  syntax Int ::= KAbsorbBlockT ( Int , Bytes ) [function, total]
  rule KAbsorbBlockT(S:Int, B:Bytes)
    => {absorb}
    requires lengthBytes(B) ==Int 136

  syntax Int ::= KLoadT ( Bytes , Int ) [function, total]
  rule KLoadT(B:Bytes, I:Int)
    => Bytes2Int( substrBytes(B, I *Int 8, I *Int 8 +Int 8), LE, Unsigned )

  // FIX OF RECORD: the remainder slice is substrBytes(B, 136,
  // lengthBytes(B)) (the -Int 136 form made the remainder EMPTY and
  // silently dropped every second block), and the == 136 base rule exists
  // because the LLVM Bytes hook substrBytes RAISES on start > end
  // (substrBytes(B, 136, 0) is an error, not the empty stream).
  syntax Int ::= KAbsorbAllT ( Int , Bytes ) [function, total]
  rule KAbsorbAllT(S:Int, B:Bytes) => S
    requires lengthBytes(B) ==Int 0
  rule KAbsorbAllT(S:Int, B:Bytes)
    => KeccakFT( KAbsorbBlockT(S, B), 0 )
    requires lengthBytes(B) ==Int 136
  rule KAbsorbAllT(S:Int, B:Bytes)
    => KAbsorbAllT( KeccakFT( KAbsorbBlockT(S, substrBytes(B, 0, 136)), 0 )
                  , substrBytes(B, 136, lengthBytes(B)) )
    requires lengthBytes(B) >Int 136

  // ---------------------------------------------------------------------
  // Squeeze: the 32-byte digest = lanes 0..3, little-endian
  // ---------------------------------------------------------------------
  syntax Bytes ::= KSqueezeT ( Int ) [function, total]
  rule KSqueezeT(S:Int)
    => Int2Bytes(8, KLaneT(S, 0), LE) +Bytes Int2Bytes(8, KLaneT(S, 1), LE)
       +Bytes Int2Bytes(8, KLaneT(S, 2), LE) +Bytes Int2Bytes(8, KLaneT(S, 3), LE)

  // ---------------------------------------------------------------------
  // THE TOTAL HASH — the leaf the M2 machine's builders call
  // ---------------------------------------------------------------------
  syntax Bytes ::= Keccak256T ( Bytes ) [function, total]
  rule Keccak256T(M:Bytes) => KSqueezeT( KAbsorbAllT( 0, KPad(M) ) )

endmodule
"""

    OUT.write_text(header + core)
    print(f"wrote {OUT} ({len(header + core)} bytes)")


if __name__ == "__main__":
    main()
