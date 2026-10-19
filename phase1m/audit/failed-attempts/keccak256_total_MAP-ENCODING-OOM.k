// =============================================================================
// SRW3 PHASE 1M — FAILED ATTEMPT OF RECORD (RECONSTRUCTED): the Map-keyed
//                    total Keccak-256 evaluator.  NEVER vector-validated;
//                    the Haskell-backend krun of the full hash OOM-killed
//                    (exit 137) on the 4 GB host.  Superseded by the
//                    packed-Int encoding (phase1m/semantics/keccak256_total.k).
//                    See README.md in this directory.  NOT deliverable.
// =============================================================================

module KECCAK256-TOTAL
  imports INT-SYNTAX
  imports INT-COMMON
  imports BOOL
  imports BYTES
  imports MAP

  syntax Int ::= "KKeccakMask" [function, total]
  rule KKeccakMask => 18446744073709551615

  syntax Int ::= KRotT ( Int , Int ) [function, total]
  rule KRotT(X:Int, 0) => X
  rule KRotT(X:Int, N:Int)
    => ( ( X <<Int N ) |Int ( X >>Int ( 64 -Int N ) ) ) &Int KKeccakMask
    requires N >Int 0 andBool N <Int 64

  syntax Int ::= KLane ( Map , Int ) [function, total]
  rule KLane(.Map, _:Int) => 0
  rule KLane( I:Int |-> V:Int REST:Map, I2:Int ) => V
    requires I ==Int I2
  rule KLane( I:Int |-> _:Int REST:Map, I2:Int ) => KLane(REST, I2)
    requires I =/=Int I2

  syntax Int ::= KRho ( Int ) [function, total]
  rule KRho(0) => 0
  rule KRho(1) => 1
  rule KRho(2) => 62
  rule KRho(3) => 28
  rule KRho(4) => 27
  rule KRho(5) => 36
  rule KRho(6) => 44
  rule KRho(7) => 6
  rule KRho(8) => 55
  rule KRho(9) => 20
  rule KRho(10) => 3
  rule KRho(11) => 10
  rule KRho(12) => 43
  rule KRho(13) => 25
  rule KRho(14) => 39
  rule KRho(15) => 41
  rule KRho(16) => 45
  rule KRho(17) => 15
  rule KRho(18) => 21
  rule KRho(19) => 8
  rule KRho(20) => 18
  rule KRho(21) => 2
  rule KRho(22) => 61
  rule KRho(23) => 56
  rule KRho(24) => 14

  syntax Int ::= KRC ( Int ) [function, total]
  rule KRC(0) => 1
  rule KRC(1) => 32898
  rule KRC(2) => 9223372036854808714
  rule KRC(3) => 9223372039002292224
  rule KRC(4) => 32907
  rule KRC(5) => 2147483649
  rule KRC(6) => 9223372039002292353
  rule KRC(7) => 9223372036854808585
  rule KRC(8) => 138
  rule KRC(9) => 136
  rule KRC(10) => 2147516425
  rule KRC(11) => 2147483658
  rule KRC(12) => 2147516555
  rule KRC(13) => 9223372036854775947
  rule KRC(14) => 9223372036854808713
  rule KRC(15) => 9223372036854808579
  rule KRC(16) => 9223372036854808578
  rule KRC(17) => 9223372036854775936
  rule KRC(18) => 32778
  rule KRC(19) => 9223372039002259466
  rule KRC(20) => 9223372039002292353
  rule KRC(21) => 9223372036854808704
  rule KRC(22) => 2147483649
  rule KRC(23) => 9223372039002292232

  syntax Int ::= KCX ( Map , Int ) [function, total]
  rule KCX(S:Map, X:Int)
    => KLane(S, X) ^Int KLane(S, X +Int 5) ^Int KLane(S, X +Int 10)
       ^Int KLane(S, X +Int 15) ^Int KLane(S, X +Int 20)

  syntax Int ::= KDX ( Map , Int ) [function, total]
  rule KDX(S:Map, X:Int)
    => KCX(S, ( X +Int 4 ) modInt 5)
       ^Int KRotT( KCX(S, ( X +Int 1 ) modInt 5), 1 )

  syntax Map ::= KTheta ( Map ) [function, total]
  rule KTheta(S:Map) => KThetaX(S, 0)

  syntax Map ::= KThetaX ( Map , Int ) [function, total]
  rule KThetaX(S:Map, 5) => S
  rule KThetaX(S:Map, X:Int) => KThetaX( KThetaCol(S, X, 0), X +Int 1 )
    requires X >=Int 0 andBool X <Int 5

  syntax Map ::= KThetaCol ( Map , Int , Int ) [function, total]
  rule KThetaCol(S:Map, _:Int, 5) => S
  rule KThetaCol(S:Map, X:Int, Y:Int)
    => KThetaCol( S[ X +Int 5 *Int Y <- KLane(S, X +Int 5 *Int Y) ^Int KDX(S, X) ]
                , X, Y +Int 1 )
    requires Y >=Int 0 andBool Y <Int 5

  syntax Map ::= KRhoPi ( Map ) [function, total]
  rule KRhoPi(S:Map)
    => ( 0 |-> KRotT( KLane(S, 0), KRho(0) ) )
       ( 10 |-> KRotT( KLane(S, 1), KRho(1) ) )
       ( 20 |-> KRotT( KLane(S, 2), KRho(2) ) )
       ( 5 |-> KRotT( KLane(S, 3), KRho(3) ) )
       ( 15 |-> KRotT( KLane(S, 4), KRho(4) ) )
       ( 16 |-> KRotT( KLane(S, 5), KRho(5) ) )
       ( 1 |-> KRotT( KLane(S, 6), KRho(6) ) )
       ( 11 |-> KRotT( KLane(S, 7), KRho(7) ) )
       ( 21 |-> KRotT( KLane(S, 8), KRho(8) ) )
       ( 6 |-> KRotT( KLane(S, 9), KRho(9) ) )
       ( 7 |-> KRotT( KLane(S, 10), KRho(10) ) )
       ( 17 |-> KRotT( KLane(S, 11), KRho(11) ) )
       ( 2 |-> KRotT( KLane(S, 12), KRho(12) ) )
       ( 12 |-> KRotT( KLane(S, 13), KRho(13) ) )
       ( 22 |-> KRotT( KLane(S, 14), KRho(14) ) )
       ( 23 |-> KRotT( KLane(S, 15), KRho(15) ) )
       ( 8 |-> KRotT( KLane(S, 16), KRho(16) ) )
       ( 18 |-> KRotT( KLane(S, 17), KRho(17) ) )
       ( 3 |-> KRotT( KLane(S, 18), KRho(18) ) )
       ( 13 |-> KRotT( KLane(S, 19), KRho(19) ) )
       ( 14 |-> KRotT( KLane(S, 20), KRho(20) ) )
       ( 24 |-> KRotT( KLane(S, 21), KRho(21) ) )
       ( 9 |-> KRotT( KLane(S, 22), KRho(22) ) )
       ( 19 |-> KRotT( KLane(S, 23), KRho(23) ) )
       ( 4 |-> KRotT( KLane(S, 24), KRho(24) ) )

  syntax Int ::= KNot64 ( Int ) [function, total]
  rule KNot64(X:Int) => X ^Int KKeccakMask

  syntax Map ::= KChi ( Map ) [function, total]
  rule KChi(B:Map) => KChiMerge(B, KChiCol0(B, .Map, 0), 1)

  syntax Map ::= KChiMerge ( Map , Map , Int ) [function, total]
  rule KChiMerge(_:Map, ACC:Map, 5) => ACC
  rule KChiMerge(B:Map, ACC:Map, X:Int)
    => KChiMerge( B, KChiMergeCols(B, ACC, X, 0), X +Int 1 )
    requires X >Int 0 andBool X <Int 5

  syntax Map ::= KChiMergeCols ( Map , Map , Int , Int ) [function, total]
  rule KChiMergeCols(B:Map, ACC:Map, 0, Y:Int) => KChiCol0(B, ACC, Y)
  rule KChiMergeCols(B:Map, ACC:Map, 1, Y:Int) => KChiCol1(B, ACC, Y)
  rule KChiMergeCols(B:Map, ACC:Map, 2, Y:Int) => KChiCol2(B, ACC, Y)
  rule KChiMergeCols(B:Map, ACC:Map, 3, Y:Int) => KChiCol3(B, ACC, Y)
  rule KChiMergeCols(B:Map, ACC:Map, 4, Y:Int) => KChiCol4(B, ACC, Y)
  syntax Map ::= KChiCol0 ( Map , Map , Int ) [function, total]
  rule KChiCol0(B:Map, ACC:Map, 5) => ACC
  rule KChiCol0(B:Map, ACC:Map, Y:Int)
    => KChiCol0( B
                 , ACC[ 0 +Int 5 *Int Y
                        <- KLane(B, 0 +Int 5 *Int Y)
                           ^Int ( KNot64( KLane(B, 1 +Int 5 *Int Y) )
                                  &Int KLane(B, 2 +Int 5 *Int Y) ) ]
                 , Y +Int 1 )
    requires Y >=Int 0 andBool Y <Int 5

  syntax Map ::= KChiCol1 ( Map , Map , Int ) [function, total]
  rule KChiCol1(B:Map, ACC:Map, 5) => ACC
  rule KChiCol1(B:Map, ACC:Map, Y:Int)
    => KChiCol1( B
                 , ACC[ 1 +Int 5 *Int Y
                        <- KLane(B, 1 +Int 5 *Int Y)
                           ^Int ( KNot64( KLane(B, 2 +Int 5 *Int Y) )
                                  &Int KLane(B, 3 +Int 5 *Int Y) ) ]
                 , Y +Int 1 )
    requires Y >=Int 0 andBool Y <Int 5

  syntax Map ::= KChiCol2 ( Map , Map , Int ) [function, total]
  rule KChiCol2(B:Map, ACC:Map, 5) => ACC
  rule KChiCol2(B:Map, ACC:Map, Y:Int)
    => KChiCol2( B
                 , ACC[ 2 +Int 5 *Int Y
                        <- KLane(B, 2 +Int 5 *Int Y)
                           ^Int ( KNot64( KLane(B, 3 +Int 5 *Int Y) )
                                  &Int KLane(B, 4 +Int 5 *Int Y) ) ]
                 , Y +Int 1 )
    requires Y >=Int 0 andBool Y <Int 5

  syntax Map ::= KChiCol3 ( Map , Map , Int ) [function, total]
  rule KChiCol3(B:Map, ACC:Map, 5) => ACC
  rule KChiCol3(B:Map, ACC:Map, Y:Int)
    => KChiCol3( B
                 , ACC[ 3 +Int 5 *Int Y
                        <- KLane(B, 3 +Int 5 *Int Y)
                           ^Int ( KNot64( KLane(B, 4 +Int 5 *Int Y) )
                                  &Int KLane(B, 0 +Int 5 *Int Y) ) ]
                 , Y +Int 1 )
    requires Y >=Int 0 andBool Y <Int 5

  syntax Map ::= KChiCol4 ( Map , Map , Int ) [function, total]
  rule KChiCol4(B:Map, ACC:Map, 5) => ACC
  rule KChiCol4(B:Map, ACC:Map, Y:Int)
    => KChiCol4( B
                 , ACC[ 4 +Int 5 *Int Y
                        <- KLane(B, 4 +Int 5 *Int Y)
                           ^Int ( KNot64( KLane(B, 0 +Int 5 *Int Y) )
                                  &Int KLane(B, 1 +Int 5 *Int Y) ) ]
                 , Y +Int 1 )
    requires Y >=Int 0 andBool Y <Int 5

  syntax Map ::= KRound ( Map , Int ) [function, total]
  rule KRound(S:Map, R:Int) => KIota( KChi( KRhoPi( KTheta(S) ) ), R )

  syntax Map ::= KIota ( Map , Int ) [function, total]
  rule KIota(S:Map, R:Int) => S[ 0 <- KLane(S, 0) ^Int KRC(R) ]

  syntax Map ::= KeccakF ( Map , Int ) [function, total]
  rule KeccakF(S:Map, 24) => S
  rule KeccakF(S:Map, R:Int) => KeccakF( KRound(S, R), R +Int 1 )
    requires R >=Int 0 andBool R <Int 24

  syntax Bytes ::= KPad ( Bytes ) [function, total]
  rule KPad(M:Bytes) => KPadFrom(M, lengthBytes(M) modInt 136)

  syntax Bytes ::= KPadFrom ( Bytes , Int ) [function, total]
  rule KPadFrom(M:Bytes, 0) => M +Bytes KPadFullBlock()
  rule KPadFrom(M:Bytes, 135) => M +Bytes Int2Bytes(1, 129, BE)  // 0x81
  rule KPadFrom(M:Bytes, Q:Int)
    => M +Bytes Int2Bytes(1, 1, BE) +Bytes KZeros(Q -Int 2)
       +Bytes Int2Bytes(1, 128, BE)
    requires Q >Int 0 andBool Q <Int 135

  syntax Bytes ::= KPadFullBlock() [function, total]
  rule KPadFullBlock() => Int2Bytes(1, 1, BE) +Bytes KZeros(134)
                         +Bytes Int2Bytes(1, 128, BE)

  syntax Bytes ::= KZeros ( Int ) [function, total]
  rule KZeros(0) => .Bytes
  rule KZeros(N:Int) => Int2Bytes(1, 0, BE) +Bytes KZeros(N -Int 1)
    requires N >Int 0

  syntax Map ::= KInitState ( Int ) [function, total]
  rule KInitState(25) => .Map
  rule KInitState(I:Int) => ( I |-> 0 ) KInitState( I +Int 1 )
    requires I >=Int 0 andBool I <Int 25

  syntax Int ::= KLoadLane ( Bytes , Int ) [function, total]
  rule KLoadLane(B:Bytes, I:Int)
    => Bytes2Int( substrBytes(B, I *Int 8, I *Int 8 +Int 8), LE, Unsigned )

  syntax Map ::= KXorBlock ( Map , Bytes , Int ) [function, total]
  rule KXorBlock(S:Map, _:Bytes, 17) => S
  rule KXorBlock(S:Map, B:Bytes, I:Int)
    => KXorBlock( S[ I <- KLane(S, I) ^Int KLoadLane(B, I) ], B, I +Int 1 )
    requires I >=Int 0 andBool I <Int 17

  syntax Map ::= KAbsorbAll ( Map , Bytes ) [function, total]
  rule KAbsorbAll(S:Map, B:Bytes) => S
    requires lengthBytes(B) ==Int 0
  rule KAbsorbAll(S:Map, B:Bytes)
    => KAbsorbAll( KeccakF( KXorBlock(S, B, 0), 0 )
                 , substrBytes(B, 136, lengthBytes(B) -Int 136) )
    requires lengthBytes(B) >=Int 136

  syntax Bytes ::= KSqueeze ( Map ) [function, total]
  rule KSqueeze(S:Map)
    => Int2Bytes(8, KLane(S, 0), LE) +Bytes Int2Bytes(8, KLane(S, 1), LE)
       +Bytes Int2Bytes(8, KLane(S, 2), LE) +Bytes Int2Bytes(8, KLane(S, 3), LE)

  syntax Bytes ::= Keccak256T ( Bytes ) [function, total]
  rule Keccak256T(M:Bytes) => KSqueeze( KAbsorbAll( KInitState(0), KPad(M) ) )

endmodule
