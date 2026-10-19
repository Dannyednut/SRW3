#!/usr/bin/env python3
# SRW3 Phase 1M — reference Keccak-256 (original padding 0x01..0x80) for
# vector validation of the pure-K evaluator. Independent implementation.
# (Regenerated after sandbox reset #7; validated against the canonical
# empty/abc vectors and cross-checked against pycryptodome.)
import sys

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
M64 = (1 << 64) - 1

# standard rho offsets table (x rows, y cols)
OFFSETS = [
    [0, 36, 3, 41, 18],
    [1, 44, 10, 45, 2],
    [62, 6, 43, 15, 61],
    [28, 55, 25, 21, 56],
    [27, 20, 39, 8, 14],
]


def rot(v, n):
    return ((v << n) | (v >> (64 - n))) & M64 if n else v


def keccak_f(state):
    # state: list of 25 lanes, lane index = x + 5*y
    for rnd in range(24):
        # theta
        C = [state[x] ^ state[x + 5] ^ state[x + 10] ^ state[x + 15] ^ state[x + 20]
             for x in range(5)]
        D = [C[(x + 4) % 5] ^ rot(C[(x + 1) % 5], 1) for x in range(5)]
        for x in range(5):
            for y in range(5):
                state[x + 5 * y] ^= D[x]
        # rho + pi: A(x,y) -> B(y, (2x+3y)%5)
        B = [0] * 25
        for x in range(5):
            for y in range(5):
                B[y + 5 * ((2 * x + 3 * y) % 5)] = rot(state[x + 5 * y], OFFSETS[x][y])
        # chi
        for x in range(5):
            for y in range(5):
                state[x + 5 * y] = B[x + 5 * y] ^ ((~B[(x + 1) % 5 + 5 * y]) & B[(x + 2) % 5 + 5 * y])
        # iota
        state[0] ^= RC[rnd]
    return state


def keccak256(msg: bytes) -> bytes:
    rate = 136
    q = len(msg) % rate
    if q == 0:
        pad = msg + b"\x01" + b"\x00" * (rate - 2) + b"\x80"
    elif q == rate - 1:
        pad = msg + b"\x81"
    else:
        pad = msg + b"\x01" + b"\x00" * (rate - q - 2) + b"\x80"
    state = [0] * 25
    for off in range(0, len(pad), rate):
        blk = pad[off:off + rate]
        for i in range(17):
            state[i] ^= int.from_bytes(blk[8 * i:8 * i + 8], "little")
        keccak_f(state)
    out = b"".join(int(state[i]).to_bytes(8, "little") for i in range(4))
    return out[:32]


if __name__ == "__main__":
    tests = [
        (b"", "c5d2460186f7233c927e7db2dcc703c0e500b653ca82273b7bfad8045d85a470"),
        (b"abc", "4e03657aea45a94fc7d47ba826c8d667c0d1e6e33a64a036ec44f58fa12d6c45"),
    ]
    ok = True
    for msg, want in tests:
        got = keccak256(msg).hex()
        status = "OK" if got == want else "MISMATCH"
        if got != want:
            ok = False
        print(f"{status}: keccak256({msg!r}) = {got}")
    extra = [b"\x00" * 135, b"\x00" * 136, b"\x00" * 137,
             bytes(range(64)), b"The quick brown fox jumps over the lazy dog" * 5]
    for m in extra:
        print(f"ref: keccak256(len={len(m)}) = {keccak256(m).hex()}")
    sys.exit(0 if ok else 1)
