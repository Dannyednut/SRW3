// =============================================================================
// SRW3 Phase 1D-R1 — literal hashing probe: hash FIXED byte strings of several
// lengths through the KRYPTO shim, to isolate any length-dependent divergence
// between the shim keccak256raw and the Python reference.
// =============================================================================

requires "srw3lin.k"

module SRW3LIN-HASHPROBE
  imports SRW3LIN

  configuration <srw3linhashprobe>
                  <k> $PGM </k>
                  <h1> .Bytes </h1>
                  <h2> .Bytes </h2>
                  <h3> .Bytes </h3>
                  <h4> .Bytes </h4>
                  <h5> .Bytes </h5>
                  <h6> .Bytes </h6>
                </srw3linhashprobe>

  syntax HashPgm ::= "dumpHashes" | "dumpHash136"

  rule <k> dumpHashes => .K ... </k>
       <h1> _:Bytes => LinH(.Bytes) </h1>
       <h2> _:Bytes => LinH(LinHex("616263")) </h2>
       <h3> _:Bytes => LinH(LinHex("002F")) </h3>
       <h4> _:Bytes => LinH(LinHex("0102030405060708090a0b0c0d0e0f101112131415161718191a1b1c1d1e1f202122232425262728292a2b2c2d2e2f303132333435363738393a3b3c3d3e3f404142434445464748494a4b4c4d4e4f505152535455565758595a5b5c5d5e5f606162636465666768696a6b6c6d6e6f707172737475767778797a7b7c7d7e7f8081")) </h4>
       <h5> _:Bytes => LinH(LinHex("0102030405060708090a0b0c0d0e0f101112131415161718191a1b1c1d1e1f202122232425262728292a2b2c2d2e2f303132333435363738393a3b3c3d3e3f404142434445464748494a4b4c4d4e4f505152535455565758595a5b5c5d5e5f606162636465666768696a6b6c6d6e6f707172737475767778797a7b7c7d7e7f8081828384858687")) </h5>

  rule <k> dumpHash136 => .K ... </k>
       <h6> _:Bytes => LinH(LinHex("000102030405060708090a0b0c0d0e0f101112131415161718191a1b1c1d1e1f202122232425262728292a2b2c2d2e2f303132333435363738393a3b3c3d3e3f404142434445464748494a4b4c4d4e4f505152535455565758595a5b5c5d5e5f606162636465666768696a6b6c6d6e6f707172737475767778797a7b7c7d7e7f8081828384858687")) </h6>

endmodule

