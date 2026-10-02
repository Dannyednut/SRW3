requires "srw3lin-symb.k"

module SRW3LIN-SYMB-STEP
  imports SRW3LIN-SYMB

  claim // LIN-CHAIN-STEP: one position-bound accept preserves chain validity.
    LinChainValid(L:Map, N:Int, H:Bytes)
      andBool linVersionOf(R:LinRec) ==Int 1
      andBool linTidOf(R:LinRec) ==Int N:Int
      andBool BytesEq(linParentOf(R:LinRec), H:Bytes)
    => LinChainValid(L:Map[linTidOf(R:LinRec) <- R:LinRec], N:Int +Int 1, linChildOf(R:LinRec))
    [label(LIN-CHAIN-STEP)]
endmodule
