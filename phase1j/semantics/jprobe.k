requires "srw3closure-j-demo.k"

module JPROBE
  imports SRW3CLOSURE-J-DEMO

  syntax PCmdJI ::= "xprobeJ"
  rule <k> xprobeJ
        => "res0isok=" +String Bool2StringX(isExecOkJ(ExecFragmentJ(XPre0, XProg0)))
           +String ",resuisok=" +String Bool2StringX(isExecOkJ(ExecFragmentJ(XPost1D, XProgUnsafe)))
           +String ",post0len=" +String Int2String(lengthBytes(LinCanonKV(XPost0D)))
           +String ",eff0len="  +String Int2String(lengthBytes(LinCanonKV(XEff0D)))
           +String ",applied0len=" +String Int2String(lengthBytes(LinCanonKV(LinApplyEff(XPre0, XEff0D))))
           +String ",comp0=" +String Bool2StringX(LinCompositionOk(linCtxP(XPre0, XEff0D, XPost0D, XReg, XAuth)))
           +String ",compU=" +String Bool2StringX(LinCompositionOk(linCtxP(XPost1D, XEffUD, XPostUD, XReg, XAuth)))
           +String ",postUlen=" +String Int2String(lengthBytes(LinCanonKV(XPostUD)))
           +String ",k1v=" +String Int2String(JStateGet(XPost0D, JRK1))
           +String ",k2vU=" +String Int2String(JStateGet(XPostUD, JRK2))
           +String ",k3vU=" +String Int2String(JStateGet(XPostUD, JRK3))
           +String ",h1vU=" +String Bool2StringX(InvHoldsJ(jInvSum(11, 1, ListItem(JRK2) ListItem(JRK3), 600), XPostUD))
           ... </k>
endmodule