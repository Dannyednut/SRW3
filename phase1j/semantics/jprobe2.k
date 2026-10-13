requires "../proofs/j_fixtures.k"

module JPROBE2
  imports SRW3CLOSURE-J-FIXTURES

  syntax PCmdJI ::= "xprobe2"
  rule <k> xprobe2
        => "canonlen=" +String Int2String(lengthBytes(JCatalogCanonJ(XCatJ)))
           +String ",prefeq=" +String Bool2StringX(BytesEq(substrBytes(JCatalogCanonJ(XCatJ), 0, 22), JCatDomainSep +Bytes I2B4(JCatEncodingVersion)))
           +String ",tag156=" +String Bool2StringX(BytesEq(substrBytes(JCatalogCanonJ(XCatJ), 0, 1), Int2Bytes(1, 156, BE)))
           +String ",appsneq=" +String Bool2StringX(BytesEq(JCanonApps(jcAppsOf(XCatJ)), JCanonApps(jcAppsOf(XCatJNameB))))
           +String ",key64=" +String Bool2StringX(BytesEq(Int2Bytes(8, A2Key(4097, 0), BE), LinHex("0000010010000000")))
           +String ",keyk=" +String Bytes2StringX(Int2Bytes(8, A2Key(4097, 0), BE))
           +String ",keyh=" +String Bytes2StringX(LinHex("0000010010000000"))
           +String ",prefeq21=" +String Bool2StringX(BytesEq(substrBytes(JCatalogCanonJ(XCatJ), 0, 21), JCatDomainSep +Bytes I2B4(JCatEncodingVersion)))
           +String ",fpproj=" +String Bool2StringX(JFootprintKeysOf(jExecOkTraceOf(ExecFragmentJ(.Map, ListItem(jWrite(4098, 0, 100)) ListItem(jWrite(4097, 0, 5)) ListItem(jWrite(4098, 0, 7)) .List))) ==K ListItem(A2Key(4098, 0)) ListItem(A2Key(4097, 0)) .List)
           +String ",clok=" +String Bool2StringX(isJClosureOk(AffectedClosureJ(ListItem(A2Key(4097, 0)) .List, jcHypersOf(XCatJ), JClosureFuelJ)))
           +String ",clsz=" +String Int2String(size(jClosureOkAffectedOf(AffectedClosureJ(ListItem(A2Key(4097, 0)) .List, jcHypersOf(XCatJ), JClosureFuelJ))))
           +String ",clh=" +String Bool2StringX(JKeyInList(A2Key(4098, 1), jClosureOkAffectedOf(AffectedClosureJ(ListItem(A2Key(4097, 0)) .List, jcHypersOf(XCatJ), JClosureFuelJ))))
           +String ",ord1=" +String Bool2StringX(jClosureOkAffectedOf(AffectedClosureJ(ListItem(A2Key(4097, 0)) .List, jcHypersOf(XCatJ), JClosureFuelJ)) ==K ListItem(A2Key(4098, 1)) ListItem(A2Key(4098, 0)) ListItem(A2Key(4099, 0)) ListItem(A2Key(4097, 0)) .List)
           +String ",ord2=" +String Bool2StringX(jClosureOkAffectedOf(AffectedClosureJ(ListItem(A2Key(4097, 0)) .List, jcHypersOf(XCatJ), JClosureFuelJ)) ==K ListItem(A2Key(4098, 0)) ListItem(A2Key(4099, 0)) ListItem(A2Key(4097, 0)) ListItem(A2Key(4098, 1)) .List)
           +String ",ord3=" +String Bool2StringX(jClosureOkAffectedOf(AffectedClosureJ(ListItem(A2Key(4097, 0)) .List, jcHypersOf(XCatJ), JClosureFuelJ)) ==K ListItem(A2Key(4098, 0)) ListItem(A2Key(4098, 1)) ListItem(A2Key(4099, 0)) ListItem(A2Key(4097, 0)) .List)
           +String ",ord4=" +String Bool2StringX(jClosureOkAffectedOf(AffectedClosureJ(ListItem(A2Key(4097, 0)) .List, jcHypersOf(XCatJ), JClosureFuelJ)) ==K ListItem(A2Key(4098, 1)) ListItem(A2Key(4099, 0)) ListItem(A2Key(4097, 0)) ListItem(A2Key(4098, 0)) .List)
           ... </k>
endmodule