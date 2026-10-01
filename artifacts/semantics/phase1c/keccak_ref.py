#!/usr/bin/env python3
# Pure-Python Keccak-256 reference (original Keccak padding 0x01) — used to
# debug/validate the C shim implementation. Verified against the canonical
# vectors keccak256("")=c5d246...470, keccak256("abc")=4e0365...c45.
MASK = (1 << 64) - 1

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

# r[x][y] flattened as RHO[x + 5*y]
RHO = [0, 1, 62, 28, 27,
       36, 44, 6, 55, 20,
       3, 10, 43, 25, 39,
       41, 45, 15, 21, 8,
       18, 2, 61, 56, 14]


def rol(x, n):
    n %= 64
    if n == 0:
        return x & MASK
    return ((x << n) | (x >> (64 - n))) & MASK


def keccak_f(st):
    for rnd in range(24):
        # theta
        C = [st[x + 5 * 0] ^ st[x + 5 * 1] ^ st[x + 5 * 2] ^ st[x + 5 * 3]
             ^ st[x + 5 * 4] for x in range(5)]
        D = [C[(x - 1) % 5] ^ rol(C[(x + 1) % 5], 1) for x in range(5)]
        for x in range(5):
            for y in range(5):
                st[x + 5 * y] ^= D[x]
        # rho + pi
        B = [0] * 25
        for x in range(5):
            for y in range(5):
                B[y + 5 * ((2 * x + 3 * y) % 5)] = rol(st[x + 5 * y], RHO[x + 5 * y])
        # chi
        for x in range(5):
            for y in range(5):
                st[x + 5 * y] = B[x + 5 * y] ^ (
                    (~B[(x + 1) % 5 + 5 * y]) & B[(x + 2) % 5 + 5 * y]) & MASK
        # iota
        st[0] ^= RC[rnd]
    return st


def keccak256(data: bytes) -> bytes:
    RATE = 136
    st = [0] * 25
    # absorb
    off = 0
    while len(data) - off >= RATE:
        blk = data[off:off + RATE]
        for i in range(RATE // 8):
            st[i] ^= int.from_bytes(blk[i * 8:(i + 1) * 8], 'little')
        keccak_f(st)
        off += RATE
    # pad: append 0x01, zeros, last byte |= 0x80
    tail = bytearray(data[off:])
    tail.append(0x01)
    while len(tail) < RATE:
        tail.append(0x00)
    tail[RATE - 1] |= 0x80
    for i in range(RATE // 8):
        st[i] ^= int.from_bytes(tail[i * 8:(i + 1) * 8], 'little')
    keccak_f(st)
    # squeeze 32 bytes
    out = b''
    for i in range(4):
        out += st[i].to_bytes(8, 'little')
    return out


if __name__ == '__main__':
    import sys
    a = keccak256(b'').hex()
    b = keccak256(b'abc').hex()
    print('empty:', a, a == 'c5d2460186f7233c927e7db2dcc703c0e500b653ca82273b7bfad8045d85a470')
    print('abc  :', b, b == '4e03657aea45a94fc7d47ba826c8d667c0d1e6e33a64a036ec44f58fa12d6c45')
