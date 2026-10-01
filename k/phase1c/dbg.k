requires "krypto.md"

module DBG
  imports KRYPTO
  imports BYTES
  imports STRING
  imports INT
  imports BOOL

  syntax Bytes ::= Hex2Bytes    ( String ) [function, total]
                 | HexBytesAux ( String ) [function, total]
  syntax String ::= HexAlign   ( String ) [function, total]

  rule Hex2Bytes(S)      => HexBytesAux(HexAlign(S))
  rule HexAlign(S)     => S             requires         lengthString(S) modInt 2 ==Int 0
  rule HexAlign(S)     => "0" +String S requires notBool lengthString(S) modInt 2 ==Int 0
  rule HexBytesAux("")  => .Bytes
  rule HexBytesAux(S)   => Int2Bytes(lengthString(S) /Int 2, String2Base(S, 16), BE)
    requires lengthString(S) >=Int 2

  syntax Bytes ::= "PK1" [function]
  rule PK1 => Hex2Bytes("0000000000000000000000000000000000000000000000000000000000000001")

  syntax String ::= "HASH1" [function]
  rule HASH1 => Keccak256(String2Bytes("SRW3 lineage entry"))

  syntax DbgPgm ::= "dbg"
  syntax KItem ::= #dbg ( String ) [klabel(#dbg), symbol]
  configuration <k> $PGM </k>

  rule <k> (_:DbgPgm) => #dbg(
      "hash=" +String HASH1
   +String "\nhashraw-len=" +String Int2String(lengthBytes(Keccak256raw(String2Bytes("SRW3 lineage entry"))))
   +String "\npk-len=" +String Int2String(lengthBytes(PK1))
   +String "\nsig=" +String ECDSASign(Keccak256raw(String2Bytes("SRW3 lineage entry")), PK1)
   +String "\npub=" +String ECDSAPubKey(PK1)
   +String "\nkec-empty=" +String Keccak256(.Bytes)
   +String "\nkec-abc=" +String Keccak256(String2Bytes("abc"))) ... </k>
endmodule
