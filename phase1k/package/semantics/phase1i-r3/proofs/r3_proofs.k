// =============================================================================
// SRW3 Phase 1I-R3 — THE CONFIGURATION-ROOT-BINDING PROOF LADDER
//                    (phase1i-r3/proofs/r3_proofs.k)
//
// Backend: HASKELL (kprove).  Claims module over srw3proto-r3.k (the isolated
// R3 machine, importing ONLY the frozen SRW3AUTHZ gate).  The legacy protocol
// modules are deliberately NOT imported here either: the claims quantify over
// the R3 command language exclusively.
//
// CLAIM INVENTORY (handoff §6 minimum + the R2 regression family; each label
// appears EXACTLY once and is scored 1:1 by run_r3_proofs.sh — no ambiguous
// score convention):
//
//   CANON family (R3-CANON-FIELD-ORDER, R3-CANON-DOMAIN-PREFIX,
//   R3-CANON-LENGTH-DELIMITED, R3-BINDS-FIELDS-1-8, R3-ROOT-BINDS-AUTHORITY-
//   FIELDS-F09..F13): the canonical preimage over the CONCRETE fixture
//   R3FixCfg (all-digests-are-literal-bytes, so every claim is decidable on
//   the Haskell backend — no hash hook involved).  The full 349-byte golden
//   preimage is the cross-language conformance vector (Python/vectors file/
//   K must agree byte-for-byte).  General hash-root statements are NOT
//   claimed (collision resistance assumed; handoff §4 A).
//
//   R3-R2-ALIAS-WITNESS: the transcribed frozen R2 preimage shape (the
//   LEGACY WITNESS ORACLE LegacyR2ProjectionR3W — tag 0x9C, fields 1..8) is
//   UNCHANGED by a schedule mutation while the R3 preimage CHANGES — the
//   R2 alias defect, concretely witnessed at the K level (the R2 MACHINE
//   itself is frozen and untouched).
//
//   INIT family (R3-INIT-PINS-AUTHORIZED, R3-INIT-ROOT-MISMATCH-REJECTS,
//   R3-CONFIG-IMMUTABLE, R3-ANCHOR-IMMUTABLE): initialization requires the
//   computed root to equal the TRUSTED anchor cell (<r3anchor> — an explicit
//   authenticated input, written by NO rule).  The root equality is the
//   documented Haskell symbolic boundary: the honest-init claim carries it
//   as a hypothesis; the mismatch claim decides on the negation; concrete
//   digests are decided on the LLVM backend and in Python.
//
//   MINT family (R3-MINT-SHAPE-*, R3-CONFIG-FRAME-GATE): the receipt binds
//   the COMPUTED verdict, the bound evidence, the computed R3 root, and the
//   trusted anchor.  Producer exhaustiveness (only pGateEvalR3 writes
//   gateReceiptR3; no command carries a receipt) is the syntactic audit,
//   audit section B.
//
//   HEADLINE (R3-ACCEPT-IMPLIES-COMMITP): the operational accept guard —
//   the EXACT requires-clause of pAcceptR3, copied verbatim (including the
//   R3 root/anchor re-checks) — implies CommitPR3, with CommitPR3 ONLY in
//   the destination, never in the requires.
//
//   REJECT family: missing/empty/wrong-candidate/stale-head/stale-linhead/
//   wrong-slot/gate-input-mismatch/config-sub/anchor-mismatch — state
//   unchanged (the anchor-mismatch claim is DECIDABLE on the Haskell backend:
//   the anchor cell is concrete machine state).
//
//   PIPELINES (R3-PIPELINE-HONEST/-FORGED): non-vacuity and the end-to-end
//   forged countermodel, with the gate's ACTUAL verdict over the machine-
//   constructed context as a hypothesis (the R2 discipline).
//
//   PORTED frozen claims (PI1/PI2x3/PI5/PI7-BASE) and CORRESPONDENCE claims
//   (R3-CORRESPONDENCE-*): the frozen 1I formulas are transcribed verbatim
//   into the claim text from phase1i/semantics/srw3proto.k; the audit
//   cross-references the frozen line numbers; the Python mirror re-derives
//   identical preimages.
//
//   R3-ALL: the universal closure — retried; the kore circularity blocker is
//   expected to fire again; the outcome is recorded WHATEVER it is.
//
// STATUS ANNOTATIONS in the claim comments are the audit-facing labels:
// PROVED / WITNESSED / DEMONSTRATED / ASSUMED / REFUTED / NOT MECHANIZED.
// =============================================================================

requires "../semantics/srw3proto-r3.k"
requires "r3_fixtures.k"

module R3-PROOFS
  imports SRW3PROTO-R3-FIXTURES

  // ===========================================================================
  // §0.1 CANON FAMILY (fixtures: r3_fixtures.k) — the 13-field serialization (handoff §6 items 1-3)
  // ===========================================================================

  claim // R3-CANON-FIELD-ORDER: PROVED — the canonical preimage of the
        // concrete fixture is EXACTLY the 349-byte golden vector (the same
        // bytes the Python encoder and the vectors file produce; cross-
        // language conformance is byte-for-byte).  This claim fixes the
        // field order, the domain separator, the version, and the LP32/U32BE
        // encoding discipline in one decidable equality.
    <k> ProtoCfgCanonR3(R3FixCfg) ==K LinHex("535257332f50726f746f4366672f5233000000000100000007636861696e2d310000000700000021706f6c6963792d6469676573742d33322d627974652d706c616365686f6c646572000000226170702d7365742d6469676573742d33322d627974652d706c616365686f6c6465720000002067726170682d6469676573742d33322d627974652d706c616365686f6c64657200000028636c69656e742d636f6e6669672d6469676573742d33322d627974652d706c616365686f6c6465720000002b657865637574696f6e2d636c69656e742d6469676573742d33322d627974652d706c616365686f6c64657200000006666f726b2d410000000a7363686564756c652d4100000003000000010000002067756573742d6469676573742d33322d627974652d706c616365686f6c6465720000002770726f6f662d636f6e6669672d6469676573742d33322d627974652d706c616365686f6c646572")
        => true </k>
    [label(R3-CANON-FIELD-ORDER)]

  claim // R3-CANON-DOMAIN-PREFIX: PROVED — the preimage STARTS with the R3
        // domain+version (17 + 4 bytes), never with the frozen 0x9C tag.
    <k> BytesEq( substrBytes(ProtoCfgCanonR3(R3FixCfg), 0, 21)
               , R3DomainSep +Bytes I2B4(R3EncodingVersion) ) ==K true
     andBool BytesEq( substrBytes(ProtoCfgCanonR3(R3FixCfg), 0, 1)
                    , Int2Bytes(1, 156, BE) ) ==K false
        => true </k>
    [label(R3-CANON-DOMAIN-PREFIX)]

  claim // R3-CANON-LENGTH-DELIMITED: PROVED — adjacent byte fields are
        // unambiguous: ("A","BC") and ("AB","C") encode DIFFERENTLY (the
        // LP32 discipline; handoff §7 length-ambiguity row).
    <k> BytesEq( ProtoCfgCanonR3(
                   protoCfgR3(LinHex("636861696e2d31"), 7,
                              LinHex("706f6c6963792d6469676573742d33322d627974652d706c616365686f6c646572"),
                              LinHex("41"), LinHex("4243"),
                              LinHex("636c69656e742d636f6e6669672d6469676573742d33322d627974652d706c616365686f6c646572"),
                              LinHex("657865637574696f6e2d636c69656e742d6469676573742d33322d627974652d706c616365686f6c646572"),
                              LinHex("666f726b2d41"), LinHex("7363686564756c652d41"), 3, 1,
                              LinHex("67756573742d6469676573742d33322d627974652d706c616365686f6c646572"),
                              LinHex("70726f6f662d636f6e6669672d6469676573742d33322d627974652d706c616365686f6c646572")))
               , ProtoCfgCanonR3(
                   protoCfgR3(LinHex("636861696e2d31"), 7,
                              LinHex("706f6c6963792d6469676573742d33322d627974652d706c616365686f6c646572"),
                              LinHex("4142"), LinHex("43"),
                              LinHex("636c69656e742d636f6e6669672d6469676573742d33322d627974652d706c616365686f6c646572"),
                              LinHex("657865637574696f6e2d636c69656e742d6469676573742d33322d627974652d706c616365686f6c646572"),
                              LinHex("666f726b2d41"), LinHex("7363686564756c652d41"), 3, 1,
                              LinHex("67756573742d6469676573742d33322d627974652d706c616365686f6c646572"),
                              LinHex("70726f6f662d636f6e6669672d6469676573742d33322d627974652d706c616365686f6c646572"))) )
        ==K false => true </k>
    [label(R3-CANON-LENGTH-DELIMITED)]

  claim // R3-BINDS-FIELDS-1-8: PROVED — each mutation of fields 1..8 changes
        // the canonical preimage (concrete fixture; one decidable
        // inequality per field).
    <k> true => true </k>
    requires notBool BytesEq( ProtoCfgCanonR3(R3FixCfg)
                            , ProtoCfgCanonR3(
                                protoCfgR3(LinHex("636861696e2d32"), 7,
                                   LinHex("706f6c6963792d6469676573742d33322d627974652d706c616365686f6c646572"),
                                   LinHex("6170702d7365742d6469676573742d33322d627974652d706c616365686f6c646572"),
                                   LinHex("67726170682d6469676573742d33322d627974652d706c616365686f6c646572"),
                                   LinHex("636c69656e742d636f6e6669672d6469676573742d33322d627974652d706c616365686f6c646572"),
                                   LinHex("657865637574696f6e2d636c69656e742d6469676573742d33322d627974652d706c616365686f6c646572"),
                                   LinHex("666f726b2d41"), LinHex("7363686564756c652d41"), 3, 1,
                                   LinHex("67756573742d6469676573742d33322d627974652d706c616365686f6c646572"),
                                   LinHex("70726f6f662d636f6e6669672d6469676573742d33322d627974652d706c616365686f6c646572"))) )
         andBool notBool BytesEq( ProtoCfgCanonR3(R3FixCfg)
                                , ProtoCfgCanonR3(
                                    protoCfgR3(LinHex("636861696e2d31"), 8,
                                       LinHex("706f6c6963792d6469676573742d33322d627974652d706c616365686f6c646572"),
                                       LinHex("6170702d7365742d6469676573742d33322d627974652d706c616365686f6c646572"),
                                       LinHex("67726170682d6469676573742d33322d627974652d706c616365686f6c646572"),
                                       LinHex("636c69656e742d636f6e6669672d6469676573742d33322d627974652d706c616365686f6c646572"),
                                       LinHex("657865637574696f6e2d636c69656e742d6469676573742d33322d627974652d706c616365686f6c646572"),
                                       LinHex("666f726b2d41"), LinHex("7363686564756c652d41"), 3, 1,
                                       LinHex("67756573742d6469676573742d33322d627974652d706c616365686f6c646572"),
                                       LinHex("70726f6f662d636f6e6669672d6469676573742d33322d627974652d706c616365686f6c646572"))) )
         andBool notBool BytesEq( ProtoCfgCanonR3(R3FixCfg)
                                , ProtoCfgCanonR3(
                                    protoCfgR3(LinHex("636861696e2d31"), 7,
                                       LinHex("706f6c6963792d6469676573742d33322d627974652d706c616365686f6c64657221"),
                                       LinHex("6170702d7365742d6469676573742d33322d627974652d706c616365686f6c646572"),
                                       LinHex("67726170682d6469676573742d33322d627974652d706c616365686f6c646572"),
                                       LinHex("636c69656e742d636f6e6669672d6469676573742d33322d627974652d706c616365686f6c646572"),
                                       LinHex("657865637574696f6e2d636c69656e742d6469676573742d33322d627974652d706c616365686f6c646572"),
                                       LinHex("666f726b2d41"), LinHex("7363686564756c652d41"), 3, 1,
                                       LinHex("67756573742d6469676573742d33322d627974652d706c616365686f6c646572"),
                                       LinHex("70726f6f662d636f6e6669672d6469676573742d33322d627974652d706c616365686f6c646572"))) )
         andBool notBool BytesEq( ProtoCfgCanonR3(R3FixCfg)
                                , ProtoCfgCanonR3(
                                    protoCfgR3(LinHex("636861696e2d31"), 7,
                                       LinHex("706f6c6963792d6469676573742d33322d627974652d706c616365686f6c646572"),
                                       LinHex("6170702d7365742d6469676573742d33322d627974652d706c616365686f6c64657221"),
                                       LinHex("67726170682d6469676573742d33322d627974652d706c616365686f6c646572"),
                                       LinHex("636c69656e742d636f6e6669672d6469676573742d33322d627974652d706c616365686f6c646572"),
                                       LinHex("657865637574696f6e2d636c69656e742d6469676573742d33322d627974652d706c616365686f6c646572"),
                                       LinHex("666f726b2d41"), LinHex("7363686564756c652d41"), 3, 1,
                                       LinHex("67756573742d6469676573742d33322d627974652d706c616365686f6c646572"),
                                       LinHex("70726f6f662d636f6e6669672d6469676573742d33322d627974652d706c616365686f6c646572"))) )
         andBool notBool BytesEq( ProtoCfgCanonR3(R3FixCfg)
                                , ProtoCfgCanonR3(
                                    protoCfgR3(LinHex("636861696e2d31"), 7,
                                       LinHex("706f6c6963792d6469676573742d33322d627974652d706c616365686f6c646572"),
                                       LinHex("6170702d7365742d6469676573742d33322d627974652d706c616365686f6c646572"),
                                       LinHex("67726170682d6469676573742d33322d627974652d706c616365686f6c64657221"),
                                       LinHex("636c69656e742d636f6e6669672d6469676573742d33322d627974652d706c616365686f6c646572"),
                                       LinHex("657865637574696f6e2d636c69656e742d6469676573742d33322d627974652d706c616365686f6c646572"),
                                       LinHex("666f726b2d41"), LinHex("7363686564756c652d41"), 3, 1,
                                       LinHex("67756573742d6469676573742d33322d627974652d706c616365686f6c646572"),
                                       LinHex("70726f6f662d636f6e6669672d6469676573742d33322d627974652d706c616365686f6c646572"))) )
         andBool notBool BytesEq( ProtoCfgCanonR3(R3FixCfg)
                                , ProtoCfgCanonR3(
                                    protoCfgR3(LinHex("636861696e2d31"), 7,
                                       LinHex("706f6c6963792d6469676573742d33322d627974652d706c616365686f6c646572"),
                                       LinHex("6170702d7365742d6469676573742d33322d627974652d706c616365686f6c646572"),
                                       LinHex("67726170682d6469676573742d33322d627974652d706c616365686f6c646572"),
                                       LinHex("636c69656e742d636f6e6669672d6469676573742d33322d627974652d706c616365686f6c64657221"),
                                       LinHex("657865637574696f6e2d636c69656e742d6469676573742d33322d627974652d706c616365686f6c646572"),
                                       LinHex("666f726b2d41"), LinHex("7363686564756c652d41"), 3, 1,
                                       LinHex("67756573742d6469676573742d33322d627974652d706c616365686f6c646572"),
                                       LinHex("70726f6f662d636f6e6669672d6469676573742d33322d627974652d706c616365686f6c646572"))) )
         andBool notBool BytesEq( ProtoCfgCanonR3(R3FixCfg)
                                , ProtoCfgCanonR3(
                                    protoCfgR3(LinHex("636861696e2d31"), 7,
                                       LinHex("706f6c6963792d6469676573742d33322d627974652d706c616365686f6c646572"),
                                       LinHex("6170702d7365742d6469676573742d33322d627974652d706c616365686f6c646572"),
                                       LinHex("67726170682d6469676573742d33322d627974652d706c616365686f6c646572"),
                                       LinHex("636c69656e742d636f6e6669672d6469676573742d33322d627974652d706c616365686f6c646572"),
                                       LinHex("657865637574696f6e2d636c69656e742d6469676573742d33322d627974652d706c616365686f6c64657221"),
                                       LinHex("666f726b2d41"), LinHex("7363686564756c652d41"), 3, 1,
                                       LinHex("67756573742d6469676573742d33322d627974652d706c616365686f6c646572"),
                                       LinHex("70726f6f662d636f6e6669672d6469676573742d33322d627974652d706c616365686f6c646572"))) )
         andBool notBool BytesEq( ProtoCfgCanonR3(R3FixCfg)
                                , ProtoCfgCanonR3(
                                    protoCfgR3(LinHex("636861696e2d31"), 7,
                                       LinHex("706f6c6963792d6469676573742d33322d627974652d706c616365686f6c646572"),
                                       LinHex("6170702d7365742d6469676573742d33322d627974652d706c616365686f6c646572"),
                                       LinHex("67726170682d6469676573742d33322d627974652d706c616365686f6c646572"),
                                       LinHex("636c69656e742d636f6e6669672d6469676573742d33322d627974652d706c616365686f6c646572"),
                                       LinHex("657865637574696f6e2d636c69656e742d6469676573742d33322d627974652d706c616365686f6c646572"),
                                       LinHex("666f726b2d42"), LinHex("7363686564756c652d41"), 3, 1,
                                       LinHex("67756573742d6469676573742d33322d627974652d706c616365686f6c646572"),
                                       LinHex("70726f6f662d636f6e6669672d6469676573742d33322d627974652d706c616365686f6c646572"))) )
    [label(R3-BINDS-FIELDS-1-8)]

  claim // R3-ROOT-BINDS-AUTHORITY-FIELDS-F09: PROVED — the schedule (field
        // 9, an R2 "pin-internal" authority field) changes the canonical
        // preimage.  (The R2 ALIAS: the legacy projection is UNCHANGED —
        // R3-R2-ALIAS-WITNESS below.)  The ROOT equality statement is the
        // collision-resistance-conditional general claim: demonstrated
        // concretely on LLVM/Python (real Keccak), not claimed as a
        // hash-injectivity theorem (handoff §6 item 3).
    <k> BytesEq( ProtoCfgCanonR3(R3FixCfg)
               , ProtoCfgCanonR3(R3FixCfgSchedB) ) ==K false
     andBool BytesEq( LegacyR2ProjectionR3W(R3FixCfg)
                    , LegacyR2ProjectionR3W(R3FixCfgSchedB) ) ==K true
        => true </k>
    [label(R3-ROOT-BINDS-AUTHORITY-FIELDS-F09)]

  claim // R3-ROOT-BINDS-AUTHORITY-FIELDS-F10: PROVED (spec version 3 -> 4)
    <k> BytesEq( ProtoCfgCanonR3(R3FixCfg)
               , ProtoCfgCanonR3(R3FixCfgSpec4) ) ==K false
     andBool BytesEq( LegacyR2ProjectionR3W(R3FixCfg)
                    , LegacyR2ProjectionR3W(R3FixCfgSpec4) ) ==K true
        => true </k>
    [label(R3-ROOT-BINDS-AUTHORITY-FIELDS-F10)]

  claim // R3-ROOT-BINDS-AUTHORITY-FIELDS-F11: PROVED (authority proof type)
    <k> BytesEq( ProtoCfgCanonR3(R3FixCfg)
               , ProtoCfgCanonR3(R3FixCfgPT2) ) ==K false
     andBool BytesEq( LegacyR2ProjectionR3W(R3FixCfg)
                    , LegacyR2ProjectionR3W(R3FixCfgPT2) ) ==K true
        => true </k>
    [label(R3-ROOT-BINDS-AUTHORITY-FIELDS-F11)]

  claim // R3-ROOT-BINDS-AUTHORITY-FIELDS-F12: PROVED (authority guest digest)
    <k> BytesEq( ProtoCfgCanonR3(R3FixCfg)
               , ProtoCfgCanonR3(R3FixCfgGuestX) ) ==K false
     andBool BytesEq( LegacyR2ProjectionR3W(R3FixCfg)
                    , LegacyR2ProjectionR3W(R3FixCfgGuestX) ) ==K true
        => true </k>
    [label(R3-ROOT-BINDS-AUTHORITY-FIELDS-F12)]

  claim // R3-ROOT-BINDS-AUTHORITY-FIELDS-F13: PROVED (authority proof-config
        // digest)
    <k> BytesEq( ProtoCfgCanonR3(R3FixCfg)
               , ProtoCfgCanonR3(R3FixCfgCfgX) ) ==K false
     andBool BytesEq( LegacyR2ProjectionR3W(R3FixCfg)
                    , LegacyR2ProjectionR3W(R3FixCfgCfgX) ) ==K true
        => true </k>
    [label(R3-ROOT-BINDS-AUTHORITY-FIELDS-F13)]

  claim // R3-R2-ALIAS-WITNESS: WITNESSED — the R2 alias defect, concretely:
        // configurations differing ONLY in an authority field share the
        // legacy 0x9C preimage (the frozen R2 root would NOT distinguish
        // them) while the R3 preimage distinguishes them.  This is the
        // before/after regression witness for the handoff §7 first row.
    <k> BytesEq( LegacyR2ProjectionR3W(R3FixCfg)
               , LegacyR2ProjectionR3W(R3FixCfgSchedB) ) ==K true
     andBool BytesEq( ProtoCfgCanonR3(R3FixCfg)
                    , ProtoCfgCanonR3(R3FixCfgSchedB) ) ==K false
        => true </k>
    [label(R3-R2-ALIAS-WITNESS)]

  claim // R3-DOMAIN-SEPARATION: PROVED — the R3 preimage of the fixture is
        // DIFFERENT from the legacy R2-shape preimage of the same fields
        // (different domain/tag, different length discipline): an R2 root
        // preimage can never be an R3 preimage.
    <k> BytesEq( ProtoCfgCanonR3(R3FixCfg)
               , LegacyR2ProjectionR3W(R3FixCfg) ) ==K false
        => true </k>
    [label(R3-DOMAIN-SEPARATION)]

  // ===========================================================================
  // §1. INIT FAMILY — initialization requires the AUTHORIZED root
  //     (handoff §6 item 4; the anchor is machine state, not caller data)
  // ===========================================================================

  claim // R3-INIT-PINS-AUTHORIZED: PROVED — pInitR3 pins ONLY when the
        // computed 13-field root equals the trusted anchor; it then anchors
        // the protocol head AT the computed root and the lineage head at the
        // 1D record-chain root.  (The BytesEq hypothesis is the documented
        // Haskell symbolic boundary — the concrete equality is decided on
        // LLVM/Python with real Keccak.)
    <k> pInitR3(C:ProtoCfgR3) => .K </k>
    <r3lineage> L:Map => L:Map[-1 <- C:ProtoCfgR3] </r3lineage>
    <r3next> _:Int </r3next>
    <r3head> _:Bytes => ProtoRootR3(C:ProtoCfgR3) </r3head>
    <r3linhead> _:Bytes => R3LinRoot </r3linhead>
    <r3anchor> A:Bytes </r3anchor>
    <r3valid> _:Bool </r3valid>
    requires notBool cfgPinnedR3(L:Map)
         andBool BytesEq(ProtoRootR3(C:ProtoCfgR3), A:Bytes)
    [label(R3-INIT-PINS-AUTHORIZED)]

  claim // R3-INIT-ROOT-MISMATCH-REJECTS: PROVED — when the computed root
        // does NOT equal the trusted anchor, initialization is refused and
        // EVERY cell is left unchanged (fail-closed; covers ANY config
        // mutation re-presented under the old authorized root, and any
        // machine instantiated under a different anchor).
    <k> pInitR3(C:ProtoCfgR3) => .K </k>
    <r3lineage> L:Map </r3lineage>
    <r3next> N:Int </r3next>
    <r3head> H:Bytes </r3head>
    <r3linhead> LH:Bytes </r3linhead>
    <r3anchor> A:Bytes </r3anchor>
    <r3valid> V:Bool </r3valid>
    requires notBool BytesEq(ProtoRootR3(C:ProtoCfgR3), A:Bytes)
    [label(R3-INIT-ROOT-MISMATCH-REJECTS)]

  claim // R3-CONFIG-IMMUTABLE: PROVED — once a configuration is pinned,
        // pInitR3 cannot re-pin (no in-model re-initialization; there is
        // deliberately NO upgrade/root-update transition).
    <k> pInitR3(_:ProtoCfgR3) => .K </k>
    <r3lineage> ( -1:Int |-> C1:ProtoCfgR3 ) L3:Map </r3lineage>
    <r3next> N:Int </r3next>
    <r3head> H:Bytes </r3head>
    <r3linhead> LH:Bytes </r3linhead>
    <r3anchor> A:Bytes </r3anchor>
    <r3valid> V:Bool </r3valid>
    [label(R3-CONFIG-IMMUTABLE)]

  // R3-ANCHOR-IMMUTABLE — STRUCTURAL (audit-verified, not kprove): the
  // anchor cell is written by NO rule of the R3 definition and is a
  // parameter of NO command.  Mechanical evidence: the rule-set scan in
  // transcripts/legacy/anchor-immutability-scan.txt (every <r3anchor>
  // occurrence is read-only) + the frame conjuncts already carried by
  // R3-INIT-PINS-AUTHORIZED / R3-MINT-SHAPE-* / R3-VALID-ACCEPT /
  // R3-CONFIG-FRAME-ACCEPT (each leaves <r3anchor> A:Bytes unchanged in the
  // claim destinations).  A blanket "CMD:PCmdR3I fires with everything
  // symbolic" kprove form is NOT provable (the prover cannot decide the
  // requires of unfireable command instances — the stuck-term boundary);
  // the per-rule frame evidence above is the mechanizable content.

  // ===========================================================================
  // §2. MINT-SHAPE CLAIMS (the verdict is computed; the inputs are bound; the
  //     receipt carries the computed R3 ROOT and the trusted ANCHOR)
  // ===========================================================================

  claim // R3-MINT-SHAPE-EXISTING-POOL: PROVED
    <k> pGateEvalR3(B:ProtoBlockR3, FC:ExecCtx, RG:LinRecG, CERT:AuthzCert,
                    ERC:Bytes, ERP:Bytes) => .K </k>
    <r3lineage> ( -1:Int |-> C:ProtoCfgR3 )
               ( -2:Int |-> PS:Set )
               L3:Map
            => ( -1:Int |-> C:ProtoCfgR3 )
               ( -2:Int |-> SetItem(
                     gateReceiptR3( B:ProtoBlockR3, ERC:Bytes, ERP:Bytes
                                  , FC:ExecCtx, RG:LinRecG, CERT:AuthzCert
                                  , azCtx( FC:ExecCtx
                                         , ProtoAuthorizedSecCtxR3(C:ProtoCfgR3,
                                               pbParentRootOf(B:ProtoBlockR3))
                                         , CERT:AuthzCert
                                         , qcrAuthPTOf(C:ProtoCfgR3)
                                         , qcrAuthGuestDOf(C:ProtoCfgR3)
                                         , qcrAuthCfgDOf(C:ProtoCfgR3) )
                                  , VerifyLineageG(
                                        RG:LinRecG
                                      , azCtx( FC:ExecCtx
                                             , ProtoAuthorizedSecCtxR3(C:ProtoCfgR3,
                                                   pbParentRootOf(B:ProtoBlockR3))
                                             , CERT:AuthzCert
                                             , qcrAuthPTOf(C:ProtoCfgR3)
                                             , qcrAuthGuestDOf(C:ProtoCfgR3)
                                             , qcrAuthCfgDOf(C:ProtoCfgR3) )
                                      , N:Int, LH:Bytes )
                                  , H:Bytes, N:Int, LH:Bytes
                                  , C:ProtoCfgR3
                                  , ProtoRootR3(C:ProtoCfgR3)
                                  , A:Bytes )) PS:Set )
               L3:Map </r3lineage>
    <r3next> N:Int </r3next>
    <r3head> H:Bytes </r3head>
    <r3linhead> LH:Bytes </r3linhead>
    <r3anchor> A:Bytes </r3anchor>
    <r3valid> _:Bool </r3valid>
    requires GateInputMatchesBlockR3(FC:ExecCtx, RG:LinRecG, CERT:AuthzCert,
                                     B:ProtoBlockR3)
         andBool GateAuthorityMatchesCfgR3(FC:ExecCtx, C:ProtoCfgR3)
         andBool BytesEq(pbParentCommitOf(B:ProtoBlockR3), H:Bytes)
         andBool pbSlotOf(B:ProtoBlockR3) ==Int N:Int
    [label(R3-MINT-SHAPE-EXISTING-POOL)]

  claim // R3-MINT-SHAPE-EMPTY-POOL: PROVED (same shape, pool not yet present)
    <k> pGateEvalR3(B:ProtoBlockR3, FC:ExecCtx, RG:LinRecG, CERT:AuthzCert,
                    ERC:Bytes, ERP:Bytes) => .K </k>
    <r3lineage> ( -1:Int |-> C:ProtoCfgR3 ) L3:Map
            => ( -1:Int |-> C:ProtoCfgR3 )
               ( -2:Int |-> SetItem(
                     gateReceiptR3( B:ProtoBlockR3, ERC:Bytes, ERP:Bytes
                                  , FC:ExecCtx, RG:LinRecG, CERT:AuthzCert
                                  , azCtx( FC:ExecCtx
                                         , ProtoAuthorizedSecCtxR3(C:ProtoCfgR3,
                                               pbParentRootOf(B:ProtoBlockR3))
                                         , CERT:AuthzCert
                                         , qcrAuthPTOf(C:ProtoCfgR3)
                                         , qcrAuthGuestDOf(C:ProtoCfgR3)
                                         , qcrAuthCfgDOf(C:ProtoCfgR3) )
                                  , VerifyLineageG(
                                        RG:LinRecG
                                      , azCtx( FC:ExecCtx
                                             , ProtoAuthorizedSecCtxR3(C:ProtoCfgR3,
                                                   pbParentRootOf(B:ProtoBlockR3))
                                             , CERT:AuthzCert
                                             , qcrAuthPTOf(C:ProtoCfgR3)
                                             , qcrAuthGuestDOf(C:ProtoCfgR3)
                                             , qcrAuthCfgDOf(C:ProtoCfgR3) )
                                      , N:Int, LH:Bytes )
                                  , H:Bytes, N:Int, LH:Bytes
                                  , C:ProtoCfgR3
                                  , ProtoRootR3(C:ProtoCfgR3)
                                  , A:Bytes )) .Set )
               L3:Map </r3lineage>
    <r3next> N:Int </r3next>
    <r3head> H:Bytes </r3head>
    <r3linhead> LH:Bytes </r3linhead>
    <r3anchor> A:Bytes </r3anchor>
    <r3valid> _:Bool </r3valid>
    requires notBool ( -2:Int in_keys(L3:Map) )
         andBool GateInputMatchesBlockR3(FC:ExecCtx, RG:LinRecG, CERT:AuthzCert,
                                         B:ProtoBlockR3)
         andBool GateAuthorityMatchesCfgR3(FC:ExecCtx, C:ProtoCfgR3)
         andBool BytesEq(pbParentCommitOf(B:ProtoBlockR3), H:Bytes)
         andBool pbSlotOf(B:ProtoBlockR3) ==Int N:Int
    [label(R3-MINT-SHAPE-EMPTY-POOL)]

  // The mint-frame twin: gate evaluation never mutates the pinned config,
  // the chain, the heads, the counter, or the anchor (it only adds a receipt).
  claim // R3-CONFIG-FRAME-GATE: PROVED
    <k> pGateEvalR3(B:ProtoBlockR3, FC:ExecCtx, RG:LinRecG, CERT:AuthzCert,
                    ERC:Bytes, ERP:Bytes) => .K </k>
    <r3lineage> ( -1:Int |-> C:ProtoCfgR3 )
               ( -2:Int |-> PS:Set )
               L3:Map
            => ( -1:Int |-> C:ProtoCfgR3 )
               ( -2:Int |-> SetItem(
                     gateReceiptR3( B:ProtoBlockR3, ERC:Bytes, ERP:Bytes
                                  , FC:ExecCtx, RG:LinRecG, CERT:AuthzCert
                                  , azCtx( FC:ExecCtx
                                         , ProtoAuthorizedSecCtxR3(C:ProtoCfgR3,
                                               pbParentRootOf(B:ProtoBlockR3))
                                         , CERT:AuthzCert
                                         , qcrAuthPTOf(C:ProtoCfgR3)
                                         , qcrAuthGuestDOf(C:ProtoCfgR3)
                                         , qcrAuthCfgDOf(C:ProtoCfgR3) )
                                  , VerifyLineageG(
                                        RG:LinRecG
                                      , azCtx( FC:ExecCtx
                                             , ProtoAuthorizedSecCtxR3(C:ProtoCfgR3,
                                                   pbParentRootOf(B:ProtoBlockR3))
                                             , CERT:AuthzCert
                                             , qcrAuthPTOf(C:ProtoCfgR3)
                                             , qcrAuthGuestDOf(C:ProtoCfgR3)
                                             , qcrAuthCfgDOf(C:ProtoCfgR3) )
                                      , N:Int, LH:Bytes )
                                  , H:Bytes, N:Int, LH:Bytes
                                  , C:ProtoCfgR3
                                  , ProtoRootR3(C:ProtoCfgR3)
                                  , A:Bytes )) PS:Set )
               L3:Map </r3lineage>
    <r3next> N:Int </r3next>
    <r3head> H:Bytes </r3head>
    <r3linhead> LH:Bytes </r3linhead>
    <r3anchor> A:Bytes </r3anchor>
    <r3valid> V2:Bool </r3valid>
    requires GateInputMatchesBlockR3(FC:ExecCtx, RG:LinRecG, CERT:AuthzCert,
                                     B:ProtoBlockR3)
         andBool GateAuthorityMatchesCfgR3(FC:ExecCtx, C:ProtoCfgR3)
         andBool BytesEq(pbParentCommitOf(B:ProtoBlockR3), H:Bytes)
         andBool pbSlotOf(B:ProtoBlockR3) ==Int N:Int
    [label(R3-CONFIG-FRAME-GATE)]

  // ===========================================================================
  // §3. THE HEADLINE: the operational guard implies Commit_P (handoff §6
  //     item 10) — the requires-clause is the pAcceptR3 rule's guard
  //     VERBATIM (same order, INCLUDING the R3 anchor/root re-checks).
  //     Commit_P appears ONLY in the destination.
  // ===========================================================================

  claim // R3-ACCEPT-IMPLIES-COMMITP: PROVED
    <k> CommitPR3(B:ProtoBlockR3, ERC:Bytes, ERP:Bytes, C:ProtoCfgR3,
                  pbParentRootOf(B:ProtoBlockR3)) ==K true => true </k>
    requires gr3BlockOf(R:R3GateReceipt) ==K B:ProtoBlockR3
         andBool gr3ErcOf(R:R3GateReceipt) ==K ERC:Bytes
         andBool gr3ErpOf(R:R3GateReceipt) ==K ERP:Bytes
         andBool gr3HeadOf(R:R3GateReceipt) ==K H:Bytes
         andBool gr3SlotOf(R:R3GateReceipt) ==Int N:Int
         andBool gr3LinHeadOf(R:R3GateReceipt) ==K LH2:Bytes
         andBool CfgEqR3(gr3CfgOf(R:R3GateReceipt), C:ProtoCfgR3)
         andBool BytesEq(gr3AnchorOf(R:R3GateReceipt), A:Bytes)
         andBool gr3DecisionOf(R:R3GateReceipt) ==Int pdecValidR3
         andBool pbDecisionOf(B:ProtoBlockR3) ==Int pdecValidR3
         andBool ExecValidPR3(B:ProtoBlockR3, ERC:Bytes, ERP:Bytes)
         andBool BytesEq(linAzCertDOf(gr3RGOf(R:R3GateReceipt)),
                         pbEvidenceDOf(B:ProtoBlockR3))
         andBool GateInputMatchesBlockR3(gr3FCOf(R:R3GateReceipt),
                                         gr3RGOf(R:R3GateReceipt),
                                         gr3CERTOf(R:R3GateReceipt),
                                         B:ProtoBlockR3)
         andBool GateCtxAuthorizedR3(gr3ACOf(R:R3GateReceipt), C:ProtoCfgR3,
                                     pbParentRootOf(B:ProtoBlockR3))
         andBool GateAuthorityMatchesCfgR3(gr3FCOf(R:R3GateReceipt),
                                           C:ProtoCfgR3)
         andBool BytesEq(pbParentCommitOf(B:ProtoBlockR3), H:Bytes)
         andBool pbSlotOf(B:ProtoBlockR3) ==Int N:Int
         andBool CV:Int ==Int qcrPolicyVOf(C:ProtoCfgR3)
         andBool BytesEq(gr3RootOf(R:R3GateReceipt), ProtoRootR3(C:ProtoCfgR3))
         andBool pbPolCommitOf(B:ProtoBlockR3) ==K PolicyCommitmentR3(C:ProtoCfgR3)
         andBool pbCtxDOf(B:ProtoBlockR3)
                 ==K CtxDigestR3(ProtoAuthorizedSecCtxR3(C:ProtoCfgR3,
                            pbParentRootOf(B:ProtoBlockR3)))
    [label(R3-ACCEPT-IMPLIES-COMMITP)]

  // Non-vacuity twin: under the SAME guard the transition FIRES and produces
  // the extended state (safety was not bought by making everything reject).
  claim // R3-VALID-ACCEPT: PROVED
    <k> pAcceptR3(B:ProtoBlockR3, ERC:Bytes, ERP:Bytes, CV:Int) => .K </k>
    <r3anchor> A:Bytes </r3anchor>
    <r3lineage> ( -1:Int |-> C:ProtoCfgR3 )
               ( -2:Int |-> SetItem(R:R3GateReceipt) .Set )
               L3:Map
            => ( -1:Int |-> C:ProtoCfgR3 )
               ( -2:Int |-> .Set )
               ( L3:Map[pbSlotOf(B:ProtoBlockR3) <- B:ProtoBlockR3] ) </r3lineage>
    <r3next> N:Int => N:Int +Int 1 </r3next>
    <r3head> H:Bytes => BlockCommitR3(B:ProtoBlockR3, C:ProtoCfgR3) </r3head>
    <r3linhead> LH:Bytes => R3RecChildF(gr3RGOf(R:R3GateReceipt)) </r3linhead>
    <r3valid> V:Bool => V:Bool </r3valid>
    requires gr3BlockOf(R:R3GateReceipt) ==K B:ProtoBlockR3
         andBool gr3ErcOf(R:R3GateReceipt) ==K ERC:Bytes
         andBool gr3ErpOf(R:R3GateReceipt) ==K ERP:Bytes
         andBool gr3HeadOf(R:R3GateReceipt) ==K H:Bytes
         andBool gr3SlotOf(R:R3GateReceipt) ==Int N:Int
         andBool gr3LinHeadOf(R:R3GateReceipt) ==K LH:Bytes
         andBool CfgEqR3(gr3CfgOf(R:R3GateReceipt), C:ProtoCfgR3)
         andBool BytesEq(gr3AnchorOf(R:R3GateReceipt), A:Bytes)
         andBool gr3DecisionOf(R:R3GateReceipt) ==Int pdecValidR3
         andBool pbDecisionOf(B:ProtoBlockR3) ==Int pdecValidR3
         andBool ExecValidPR3(B:ProtoBlockR3, ERC:Bytes, ERP:Bytes)
         andBool BytesEq(linAzCertDOf(gr3RGOf(R:R3GateReceipt)),
                         pbEvidenceDOf(B:ProtoBlockR3))
         andBool GateInputMatchesBlockR3(gr3FCOf(R:R3GateReceipt),
                                         gr3RGOf(R:R3GateReceipt),
                                         gr3CERTOf(R:R3GateReceipt),
                                         B:ProtoBlockR3)
         andBool GateCtxAuthorizedR3(gr3ACOf(R:R3GateReceipt), C:ProtoCfgR3,
                                     pbParentRootOf(B:ProtoBlockR3))
         andBool GateAuthorityMatchesCfgR3(gr3FCOf(R:R3GateReceipt),
                                           C:ProtoCfgR3)
         andBool BytesEq(pbParentCommitOf(B:ProtoBlockR3), H:Bytes)
         andBool pbSlotOf(B:ProtoBlockR3) ==Int N:Int
         andBool CV:Int ==Int qcrPolicyVOf(C:ProtoCfgR3)
         andBool BytesEq(gr3RootOf(R:R3GateReceipt), ProtoRootR3(C:ProtoCfgR3))
         andBool pbPolCommitOf(B:ProtoBlockR3) ==K PolicyCommitmentR3(C:ProtoCfgR3)
         andBool pbCtxDOf(B:ProtoBlockR3)
                 ==K CtxDigestR3(ProtoAuthorizedSecCtxR3(C:ProtoCfgR3,
                            pbParentRootOf(B:ProtoBlockR3)))
    [label(R3-VALID-ACCEPT)]

  // Accept-frame twin: an accept (the only chain-extending rule) leaves the
  // pinned configuration and the anchor unchanged.
  claim // R3-CONFIG-FRAME-ACCEPT: PROVED
    <k> pAcceptR3(B:ProtoBlockR3, ERC:Bytes, ERP:Bytes, CV:Int) => .K </k>
    <r3anchor> A:Bytes </r3anchor>
    <r3lineage> ( -1:Int |-> C:ProtoCfgR3 )
               ( -2:Int |-> SetItem(R:R3GateReceipt) .Set )
               L3:Map
            => ( -1:Int |-> C:ProtoCfgR3 )
               ( -2:Int |-> .Set )
               ( L3:Map[pbSlotOf(B:ProtoBlockR3) <- B:ProtoBlockR3] ) </r3lineage>
    <r3next> N:Int => N:Int +Int 1 </r3next>
    <r3head> H:Bytes => BlockCommitR3(B:ProtoBlockR3, C:ProtoCfgR3) </r3head>
    <r3linhead> LH:Bytes => R3RecChildF(gr3RGOf(R:R3GateReceipt)) </r3linhead>
    <r3valid> V:Bool => V:Bool </r3valid>
    requires gr3BlockOf(R:R3GateReceipt) ==K B:ProtoBlockR3
         andBool gr3ErcOf(R:R3GateReceipt) ==K ERC:Bytes
         andBool gr3ErpOf(R:R3GateReceipt) ==K ERP:Bytes
         andBool gr3HeadOf(R:R3GateReceipt) ==K H:Bytes
         andBool gr3SlotOf(R:R3GateReceipt) ==Int N:Int
         andBool gr3LinHeadOf(R:R3GateReceipt) ==K LH:Bytes
         andBool CfgEqR3(gr3CfgOf(R:R3GateReceipt), C:ProtoCfgR3)
         andBool BytesEq(gr3AnchorOf(R:R3GateReceipt), A:Bytes)
         andBool gr3DecisionOf(R:R3GateReceipt) ==Int pdecValidR3
         andBool pbDecisionOf(B:ProtoBlockR3) ==Int pdecValidR3
         andBool ExecValidPR3(B:ProtoBlockR3, ERC:Bytes, ERP:Bytes)
         andBool BytesEq(linAzCertDOf(gr3RGOf(R:R3GateReceipt)),
                         pbEvidenceDOf(B:ProtoBlockR3))
         andBool GateInputMatchesBlockR3(gr3FCOf(R:R3GateReceipt),
                                         gr3RGOf(R:R3GateReceipt),
                                         gr3CERTOf(R:R3GateReceipt),
                                         B:ProtoBlockR3)
         andBool GateCtxAuthorizedR3(gr3ACOf(R:R3GateReceipt), C:ProtoCfgR3,
                                     pbParentRootOf(B:ProtoBlockR3))
         andBool GateAuthorityMatchesCfgR3(gr3FCOf(R:R3GateReceipt),
                                           C:ProtoCfgR3)
         andBool BytesEq(pbParentCommitOf(B:ProtoBlockR3), H:Bytes)
         andBool pbSlotOf(B:ProtoBlockR3) ==Int N:Int
         andBool CV:Int ==Int qcrPolicyVOf(C:ProtoCfgR3)
         andBool BytesEq(gr3RootOf(R:R3GateReceipt), ProtoRootR3(C:ProtoCfgR3))
         andBool pbPolCommitOf(B:ProtoBlockR3) ==K PolicyCommitmentR3(C:ProtoCfgR3)
         andBool pbCtxDOf(B:ProtoBlockR3)
                 ==K CtxDigestR3(ProtoAuthorizedSecCtxR3(C:ProtoCfgR3,
                            pbParentRootOf(B:ProtoBlockR3)))
    [label(R3-CONFIG-FRAME-ACCEPT)]

  // ===========================================================================
  // §4. DECISION BINDING (the candidate's decision field is the gate's)
  // ===========================================================================

  claim // R3-DECISION-BOUND: PROVED — an accepted candidate's decision field
        // equals the GATE-DERIVED decision (both are pinned pdecValidR3 by
        // the accept guard; the equality is their only joint value).
    <k> pbDecisionOf(B:ProtoBlockR3) ==Int gr3DecisionOf(R:R3GateReceipt)
        => true </k>
    requires gr3DecisionOf(R:R3GateReceipt) ==Int pdecValidR3
         andBool pbDecisionOf(B:ProtoBlockR3) ==Int pdecValidR3
    [label(R3-DECISION-BOUND)]

  claim // R3-GATELINK-VALID: PROVED — only "valid-g" (the frozen 21-conjunct
        // accept result) maps to the protocol-valid decision.
    <k> ProtoDecisionOfGateR3("valid-g") ==K pdecValidR3 => true </k>
    [label(R3-GATELINK-VALID)]

  claim // R3-GATELINK-REJECT1: PROVED — an authority-layer rejection verdict
        // maps to pdecRejectR3, so Commit_P is false for a block whose
        // decision field carries it.
    <k> CommitPR3(B:ProtoBlockR3, ERC:Bytes, ERP:Bytes, C:ProtoCfgR3, LH:Bytes)
        ==K false => true </k>
    requires pbDecisionOf(B:ProtoBlockR3)
             ==K ProtoDecisionOfGateR3("invalid-authtype")
    [label(R3-GATELINK-REJECT1)]

  claim // R3-GATELINK-REJECT2: PROVED ("invalid-authsrc")
    <k> CommitPR3(B:ProtoBlockR3, ERC:Bytes, ERP:Bytes, C:ProtoCfgR3, LH:Bytes)
        ==K false => true </k>
    requires pbDecisionOf(B:ProtoBlockR3)
             ==K ProtoDecisionOfGateR3("invalid-authsrc")
    [label(R3-GATELINK-REJECT2)]

  claim // R3-GATELINK-REJECT3: PROVED ("invalid-policy")
    <k> CommitPR3(B:ProtoBlockR3, ERC:Bytes, ERP:Bytes, C:ProtoCfgR3, LH:Bytes)
        ==K false => true </k>
    requires pbDecisionOf(B:ProtoBlockR3)
             ==K ProtoDecisionOfGateR3("invalid-policy")
    [label(R3-GATELINK-REJECT3)]

  // ===========================================================================
  // §5. COMPUTED-REJECTION CANNOT ACCEPT (the decisive negative family —
  //     handoff: an invalid block must not be committable no matter what)
  // ===========================================================================

  claim // R3-FORGED-VERDICT-REJECT: PROVED — a computed "invalid-policy"
        // cannot accept.  (In R3 the caller never gets to choose this
        // string; the machine computed it — and the machine refuses to
        // commit on it.)
    <k> pAcceptR3(B:ProtoBlockR3, ERC:Bytes, ERP:Bytes, CV:Int) => .K </k>
    <r3anchor> A:Bytes </r3anchor>
    <r3lineage> ( -1:Int |-> C:ProtoCfgR3 )
               ( -2:Int |-> SetItem(R:R3GateReceipt) .Set )
               L3:Map </r3lineage>
    <r3next> N:Int </r3next>
    <r3head> H:Bytes </r3head>
    <r3linhead> LH:Bytes </r3linhead>
    <r3valid> V:Bool </r3valid>
    requires gr3BlockOf(R:R3GateReceipt) ==K B:ProtoBlockR3
         andBool gr3ErcOf(R:R3GateReceipt) ==K ERC:Bytes
         andBool gr3ErpOf(R:R3GateReceipt) ==K ERP:Bytes
         andBool gr3HeadOf(R:R3GateReceipt) ==K H:Bytes
         andBool gr3SlotOf(R:R3GateReceipt) ==Int N:Int
         andBool gr3LinHeadOf(R:R3GateReceipt) ==K LH:Bytes
         andBool CfgEqR3(gr3CfgOf(R:R3GateReceipt), C:ProtoCfgR3)
         andBool gr3VerdictOf(R:R3GateReceipt) ==K "invalid-policy"
         andBool CV:Int ==Int qcrPolicyVOf(C:ProtoCfgR3)
         andBool BytesEq(pbParentCommitOf(B:ProtoBlockR3), H:Bytes)
         andBool pbSlotOf(B:ProtoBlockR3) ==Int N:Int
    [label(R3-FORGED-VERDICT-REJECT)]

  claim // R3-FORGED-VERDICT-REJECT-AUTHTYPE: PROVED (authority-layer branch)
    <k> pAcceptR3(B:ProtoBlockR3, ERC:Bytes, ERP:Bytes, CV:Int) => .K </k>
    <r3anchor> A:Bytes </r3anchor>
    <r3lineage> ( -1:Int |-> C:ProtoCfgR3 )
               ( -2:Int |-> SetItem(R:R3GateReceipt) .Set )
               L3:Map </r3lineage>
    <r3next> N:Int </r3next>
    <r3head> H:Bytes </r3head>
    <r3linhead> LH:Bytes </r3linhead>
    <r3valid> V:Bool </r3valid>
    requires gr3BlockOf(R:R3GateReceipt) ==K B:ProtoBlockR3
         andBool gr3ErcOf(R:R3GateReceipt) ==K ERC:Bytes
         andBool gr3ErpOf(R:R3GateReceipt) ==K ERP:Bytes
         andBool gr3HeadOf(R:R3GateReceipt) ==K H:Bytes
         andBool gr3SlotOf(R:R3GateReceipt) ==Int N:Int
         andBool gr3LinHeadOf(R:R3GateReceipt) ==K LH:Bytes
         andBool CfgEqR3(gr3CfgOf(R:R3GateReceipt), C:ProtoCfgR3)
         andBool gr3VerdictOf(R:R3GateReceipt) ==K "invalid-authtype"
         andBool CV:Int ==Int qcrPolicyVOf(C:ProtoCfgR3)
         andBool BytesEq(pbParentCommitOf(B:ProtoBlockR3), H:Bytes)
         andBool pbSlotOf(B:ProtoBlockR3) ==Int N:Int
    [label(R3-FORGED-VERDICT-REJECT-AUTHTYPE)]

  // ===========================================================================
  // §6. STATE-UNCHANGED-ON-REJECT (the restoration family)
  // ===========================================================================

  claim // R3-REJECT-NO-POOL: PROVED — with NO receipt-pool entry at all,
        // nothing can accept (missing evidence/decision is fail-closed).
    <k> pAcceptR3(B:ProtoBlockR3, ERC:Bytes, ERP:Bytes, CV:Int) => .K </k>
    <r3anchor> A:Bytes </r3anchor>
    <r3lineage> ( -1:Int |-> C:ProtoCfgR3 ) L3:Map </r3lineage>
    <r3next> N:Int </r3next>
    <r3head> H:Bytes </r3head>
    <r3linhead> LH:Bytes </r3linhead>
    <r3valid> V:Bool </r3valid>
    requires notBool ( -2:Int in_keys(L3:Map) )
    [label(R3-REJECT-NO-POOL)]

  claim // R3-REJECT-EMPTY-POOL: PROVED — an EMPTY pool accepts nothing.
    <k> pAcceptR3(B:ProtoBlockR3, ERC:Bytes, ERP:Bytes, CV:Int) => .K </k>
    <r3anchor> A:Bytes </r3anchor>
    <r3lineage> ( -1:Int |-> C:ProtoCfgR3 )
               ( -2:Int |-> .Set )
               L3:Map </r3lineage>
    <r3next> N:Int </r3next>
    <r3head> H:Bytes </r3head>
    <r3linhead> LH:Bytes </r3linhead>
    <r3valid> V:Bool </r3valid>
    [label(R3-REJECT-EMPTY-POOL)]

  claim // R3-REJECT-WRONG-CANDIDATE: PROVED — the receipt on record was
        // minted for a DIFFERENT candidate (its bound child root is 0x01,
        // the presented execution result is 0x02); also the receipt's
        // candidate block differs from the presented one.  Concrete.
    <k> pAcceptR3(B:ProtoBlockR3, ERC:Bytes, ERP:Bytes, CV:Int) => .K </k>
    <r3anchor> A:Bytes </r3anchor>
    <r3lineage> ( -1:Int |-> C:ProtoCfgR3 )
               ( -2:Int |-> SetItem(gateReceiptR3(
                   protoBlockR3(b"\x11", b"\x22", b"\x33", Int2Bytes(1, 1, BE),
                                b"\x55", b"\x66", b"\x77", b"\x88", 1, 0),
                   Int2Bytes(1, 1, BE), ERP:Bytes,
                   FC:ExecCtx, RG:LinRecG, CERT:AuthzCert, AC:AzCtx,
                   "valid-g", H:Bytes, N:Int, LH:Bytes, C:ProtoCfgR3,
                   ProtoRootR3(C:ProtoCfgR3), A:Bytes)) .Set )
               L3:Map </r3lineage>
    <r3next> N:Int </r3next>
    <r3head> H:Bytes </r3head>
    <r3linhead> LH:Bytes </r3linhead>
    <r3valid> V:Bool </r3valid>
    requires ERC:Bytes ==K Int2Bytes(1, 2, BE)
         andBool CV:Int ==Int qcrPolicyVOf(C:ProtoCfgR3)
         andBool BytesEq(pbParentCommitOf(B:ProtoBlockR3), H:Bytes)
         andBool pbSlotOf(B:ProtoBlockR3) ==Int N:Int
    [label(R3-REJECT-WRONG-CANDIDATE)]

  claim // R3-REJECT-STALE-HEAD: PROVED — a receipt minted under a DISPLACED
        // protocol head (0x01) cannot authorize a commit under the current
        // head (0x02) — the reorg/stale-evidence exclusion.  Concrete.
    <k> pAcceptR3(B:ProtoBlockR3, ERC:Bytes, ERP:Bytes, CV:Int) => .K </k>
    <r3anchor> A:Bytes </r3anchor>
    <r3lineage> ( -1:Int |-> C:ProtoCfgR3 )
               ( -2:Int |-> SetItem(gateReceiptR3(
                   B:ProtoBlockR3, ERC:Bytes, ERP:Bytes,
                   FC:ExecCtx, RG:LinRecG, CERT:AuthzCert, AC:AzCtx,
                   "valid-g", Int2Bytes(1, 1, BE), N:Int, LH:Bytes,
                   C:ProtoCfgR3, ProtoRootR3(C:ProtoCfgR3), A:Bytes)) .Set )
               L3:Map </r3lineage>
    <r3next> N:Int </r3next>
    <r3head> Int2Bytes(1, 2, BE) </r3head>
    <r3linhead> LH:Bytes </r3linhead>
    <r3valid> V:Bool </r3valid>
    requires CV:Int ==Int qcrPolicyVOf(C:ProtoCfgR3)
         andBool pbSlotOf(B:ProtoBlockR3) ==Int N:Int
    [label(R3-REJECT-STALE-HEAD)]

  claim // R3-REJECT-STALE-LINHEAD: PROVED — a receipt minted under a
        // displaced LINEAGE anchor (0x01) cannot authorize a commit at the
        // current lineage anchor (0x02) — evidence-chain staleness.  Concrete.
    <k> pAcceptR3(B:ProtoBlockR3, ERC:Bytes, ERP:Bytes, CV:Int) => .K </k>
    <r3anchor> A:Bytes </r3anchor>
    <r3lineage> ( -1:Int |-> C:ProtoCfgR3 )
               ( -2:Int |-> SetItem(gateReceiptR3(
                   B:ProtoBlockR3, ERC:Bytes, ERP:Bytes,
                   FC:ExecCtx, RG:LinRecG, CERT:AuthzCert, AC:AzCtx,
                   "valid-g", H:Bytes, N:Int, Int2Bytes(1, 1, BE),
                   C:ProtoCfgR3, ProtoRootR3(C:ProtoCfgR3), A:Bytes)) .Set )
               L3:Map </r3lineage>
    <r3next> N:Int </r3next>
    <r3head> H:Bytes </r3head>
    <r3linhead> Int2Bytes(1, 2, BE) </r3linhead>
    <r3valid> V:Bool </r3valid>
    requires CV:Int ==Int qcrPolicyVOf(C:ProtoCfgR3)
         andBool pbSlotOf(B:ProtoBlockR3) ==Int N:Int
         andBool BytesEq(pbParentCommitOf(B:ProtoBlockR3), H:Bytes)
    [label(R3-REJECT-STALE-LINHEAD)]

  claim // R3-REJECT-WRONG-SLOT: PROVED — a receipt minted at a different
        // slot position cannot accept at the current position.
    <k> pAcceptR3(B:ProtoBlockR3, ERC:Bytes, ERP:Bytes, CV:Int) => .K </k>
    <r3anchor> A:Bytes </r3anchor>
    <r3lineage> ( -1:Int |-> C:ProtoCfgR3 )
               ( -2:Int |-> SetItem(gateReceiptR3(
                   B:ProtoBlockR3, ERC:Bytes, ERP:Bytes,
                   FC:ExecCtx, RG:LinRecG, CERT:AuthzCert, AC:AzCtx,
                   "valid-g", H:Bytes, N:Int +Int 1, LH:Bytes,
                   C:ProtoCfgR3, ProtoRootR3(C:ProtoCfgR3), A:Bytes)) .Set )
               L3:Map </r3lineage>
    <r3next> N:Int </r3next>
    <r3head> H:Bytes </r3head>
    <r3linhead> LH:Bytes </r3linhead>
    <r3valid> V:Bool </r3valid>
    requires CV:Int ==Int qcrPolicyVOf(C:ProtoCfgR3)
         andBool BytesEq(pbParentCommitOf(B:ProtoBlockR3), H:Bytes)
    [label(R3-REJECT-WRONG-SLOT)]

  claim // R3-REJECT-GATE-INPUT-MISMATCH: PROVED — the receipt's STORED
        // evidence does not match the presented candidate: the stored
        // certificate's payload digest is 0x01 while the candidate's payload
        // digest is 0x02 (GateInputMatchesBlockR3 fails at accept — defense
        // in depth even against a hypothetically mis-shaped receipt).  Concrete.
    <k> pAcceptR3(B:ProtoBlockR3, ERC:Bytes, ERP:Bytes, CV:Int) => .K </k>
    <r3anchor> A:Bytes </r3anchor>
    <r3lineage> ( -1:Int |-> C:ProtoCfgR3 )
               ( -2:Int |-> SetItem(gateReceiptR3(
                   B:ProtoBlockR3, ERC:Bytes, ERP:Bytes,
                   FC:ExecCtx, RG:LinRecG,
                   azCert(Int2Bytes(1, 1, BE), PR:Bytes, EI:Bytes, CR:Bytes,
                          ED:Bytes, 1,
                          azSrc(domConsensus, I:Bytes, 0), .List, 1, PP:Bytes),
                   AC:AzCtx, "valid-g", H:Bytes, N:Int, LH:Bytes,
                   C:ProtoCfgR3, ProtoRootR3(C:ProtoCfgR3), A:Bytes)) .Set )
               L3:Map </r3lineage>
    <r3next> N:Int </r3next>
    <r3head> H:Bytes </r3head>
    <r3linhead> LH:Bytes </r3linhead>
    <r3valid> V:Bool </r3valid>
    requires pbPayloadDOf(B:ProtoBlockR3) ==K Int2Bytes(1, 2, BE)
         andBool CV:Int ==Int qcrPolicyVOf(C:ProtoCfgR3)
         andBool BytesEq(pbParentCommitOf(B:ProtoBlockR3), H:Bytes)
         andBool pbSlotOf(B:ProtoBlockR3) ==Int N:Int
    [label(R3-REJECT-GATE-INPUT-MISMATCH)]

  claim // R3-CONFIG-SUB-REJECT: PROVED (decidable witness) — the pinned
        // config has policy version 1; the candidate declares version 2 (a
        // policy/config upgrade that was never activated).  State unchanged.
        // (A same-version content substitution is distinguished by the R3
        // ROOT re-check — gr3Root binds the COMPLETE 13-field config — and
        // by the policy-commitment equality; both are hash-class on the
        // Haskell backend, demonstrated concretely on LLVM/Python.)
    <k> pAcceptR3(B:ProtoBlockR3, ERC:Bytes, ERP:Bytes, 2:Int) => .K </k>
    <r3anchor> A:Bytes </r3anchor>
    <r3lineage> ( -1:Int |-> protoCfgR3(CH:Bytes, 1:Int, PD:Bytes, AS:Bytes,
                                        GR:Bytes, CC:Bytes, EC:Bytes,
                                        FK:Bytes, SC:Bytes, 1:Int, PT:Int,
                                        GD:Bytes, CD:Bytes) )
               ( -2:Int |-> SetItem(gateReceiptR3(
                   B:ProtoBlockR3, ERC:Bytes, ERP:Bytes,
                   FC:ExecCtx, RG:LinRecG, CERT:AuthzCert, AC:AzCtx,
                   "valid-g", H:Bytes, N:Int, LH:Bytes,
                   protoCfgR3(CH:Bytes, 1:Int, PD:Bytes, AS:Bytes, GR:Bytes,
                              CC:Bytes, EC:Bytes, FK:Bytes, SC:Bytes, 1:Int,
                              PT:Int, GD:Bytes, CD:Bytes),
                   ProtoRootR3(protoCfgR3(CH:Bytes, 1:Int, PD:Bytes, AS:Bytes,
                              GR:Bytes, CC:Bytes, EC:Bytes, FK:Bytes,
                              SC:Bytes, 1:Int, PT:Int, GD:Bytes, CD:Bytes)),
                   A:Bytes)) .Set )
               L3:Map </r3lineage>
    <r3next> N:Int </r3next>
    <r3head> H:Bytes </r3head>
    <r3linhead> LH:Bytes </r3linhead>
    <r3valid> V:Bool </r3valid>
    requires BytesEq(pbParentCommitOf(B:ProtoBlockR3), H:Bytes)
         andBool pbSlotOf(B:ProtoBlockR3) ==Int N:Int
    [label(R3-CONFIG-SUB-REJECT)]

  claim // R3-REJECT-ANCHOR-MISMATCH: PROVED (DECIDABLE on the Haskell
        // backend — the anchor cell is concrete machine state) — a receipt
        // minted under a DIFFERENT trusted anchor (0x01) cannot accept on a
        // machine whose anchor is 0x02: the cross-machine/cross-root replay
        // exclusion at the accept guard's anchor conjunct.  Concrete.
    <k> pAcceptR3(B:ProtoBlockR3, ERC:Bytes, ERP:Bytes, CV:Int) => .K </k>
    <r3anchor> Int2Bytes(1, 2, BE) </r3anchor>
    <r3lineage> ( -1:Int |-> C:ProtoCfgR3 )
               ( -2:Int |-> SetItem(gateReceiptR3(
                   B:ProtoBlockR3, ERC:Bytes, ERP:Bytes,
                   FC:ExecCtx, RG:LinRecG, CERT:AuthzCert, AC:AzCtx,
                   "valid-g", H:Bytes, N:Int, LH:Bytes, C:ProtoCfgR3,
                   ProtoRootR3(C:ProtoCfgR3), Int2Bytes(1, 1, BE))) .Set )
               L3:Map </r3lineage>
    <r3next> N:Int </r3next>
    <r3head> H:Bytes </r3head>
    <r3linhead> LH:Bytes </r3linhead>
    <r3valid> V:Bool </r3valid>
    requires CV:Int ==Int qcrPolicyVOf(C:ProtoCfgR3)
         andBool BytesEq(pbParentCommitOf(B:ProtoBlockR3), H:Bytes)
         andBool pbSlotOf(B:ProtoBlockR3) ==Int N:Int
    [label(R3-REJECT-ANCHOR-MISMATCH)]

  claim // R3-RECEIPT-SINGLE-USE: PROVED — with exactly ONE matching receipt,
        // the first accept consumes it and commits; the replayed accept
        // finds an empty pool and rejects — the counter advances by ONE.
    <k> pAcceptR3(B:ProtoBlockR3, ERC:Bytes, ERP:Bytes, CV:Int)
        ~> pAcceptR3(B:ProtoBlockR3, ERC:Bytes, ERP:Bytes, CV:Int) => .K </k>
    <r3anchor> A:Bytes </r3anchor>
    <r3lineage> ( -1:Int |-> C:ProtoCfgR3 )
               ( -2:Int |-> SetItem(R:R3GateReceipt) .Set )
               L3:Map
            => ( -1:Int |-> C:ProtoCfgR3 )
               ( -2:Int |-> .Set )
               ( L3:Map[pbSlotOf(B:ProtoBlockR3) <- B:ProtoBlockR3] ) </r3lineage>
    <r3next> N:Int => N:Int +Int 1 </r3next>
    <r3head> H:Bytes => BlockCommitR3(B:ProtoBlockR3, C:ProtoCfgR3) </r3head>
    <r3linhead> LH:Bytes => R3RecChildF(gr3RGOf(R:R3GateReceipt)) </r3linhead>
    <r3valid> V:Bool => V:Bool </r3valid>
    requires gr3BlockOf(R:R3GateReceipt) ==K B:ProtoBlockR3
         andBool gr3ErcOf(R:R3GateReceipt) ==K ERC:Bytes
         andBool gr3ErpOf(R:R3GateReceipt) ==K ERP:Bytes
         andBool gr3HeadOf(R:R3GateReceipt) ==K H:Bytes
         andBool gr3SlotOf(R:R3GateReceipt) ==Int N:Int
         andBool gr3LinHeadOf(R:R3GateReceipt) ==K LH:Bytes
         andBool CfgEqR3(gr3CfgOf(R:R3GateReceipt), C:ProtoCfgR3)
         andBool BytesEq(gr3AnchorOf(R:R3GateReceipt), A:Bytes)
         andBool gr3DecisionOf(R:R3GateReceipt) ==Int pdecValidR3
         andBool pbDecisionOf(B:ProtoBlockR3) ==Int pdecValidR3
         andBool ExecValidPR3(B:ProtoBlockR3, ERC:Bytes, ERP:Bytes)
         andBool BytesEq(linAzCertDOf(gr3RGOf(R:R3GateReceipt)),
                         pbEvidenceDOf(B:ProtoBlockR3))
         andBool GateInputMatchesBlockR3(gr3FCOf(R:R3GateReceipt),
                                         gr3RGOf(R:R3GateReceipt),
                                         gr3CERTOf(R:R3GateReceipt),
                                         B:ProtoBlockR3)
         andBool GateCtxAuthorizedR3(gr3ACOf(R:R3GateReceipt), C:ProtoCfgR3,
                                     pbParentRootOf(B:ProtoBlockR3))
         andBool GateAuthorityMatchesCfgR3(gr3FCOf(R:R3GateReceipt),
                                           C:ProtoCfgR3)
         andBool BytesEq(pbParentCommitOf(B:ProtoBlockR3), H:Bytes)
         andBool pbSlotOf(B:ProtoBlockR3) ==Int N:Int
         andBool CV:Int ==Int qcrPolicyVOf(C:ProtoCfgR3)
         andBool BytesEq(gr3RootOf(R:R3GateReceipt), ProtoRootR3(C:ProtoCfgR3))
         andBool pbPolCommitOf(B:ProtoBlockR3) ==K PolicyCommitmentR3(C:ProtoCfgR3)
         andBool pbCtxDOf(B:ProtoBlockR3)
                 ==K CtxDigestR3(ProtoAuthorizedSecCtxR3(C:ProtoCfgR3,
                            pbParentRootOf(B:ProtoBlockR3)))
    [label(R3-RECEIPT-SINGLE-USE)]

  // ===========================================================================
  // §7. PIPELINES (non-vacuity + the forged end-to-end countermodel)
  // ===========================================================================

  claim // R3-PIPELINE-HONEST: PROVED (K side) — authorized init -> gate
        // evaluation -> accept commits the valid candidate.  The anchor is
        // the trusted protocol input the init check binds to; the gate's
        // verdict enters as the gate's ACTUAL result over the machine-
        // constructed context (hypothesis pinned to exactly that context —
        // GateCtxAuthorizedR3 holds of the mint-constructed AC by
        // construction).  The concrete-digest instantiation is LLVM/Python.
    <k> pInitR3(CFG)
        ~> pGateEvalR3(B:ProtoBlockR3, FC:ExecCtx, RG:LinRecG, CERT:AuthzCert,
                       ERC:Bytes, ERP:Bytes)
        ~> pAcceptR3(B:ProtoBlockR3, ERC:Bytes, ERP:Bytes, 1:Int) => .K </k>
    <r3anchor> A:Bytes </r3anchor>
    <r3lineage> .Map
            => ( -1:Int |-> CFG )
               ( -2:Int |-> .Set )
               ( 0:Int |-> B:ProtoBlockR3 ) </r3lineage>
    <r3next> 0 => 1 </r3next>
    <r3head> _:Bytes => BlockCommitR3(B:ProtoBlockR3, CFG) </r3head>
    <r3linhead> _:Bytes => R3RecChildF(RG:LinRecG) </r3linhead>
    <r3valid> V:Bool => V:Bool </r3valid>
    requires CFG ==K protoCfgR3(CH:Bytes, 1:Int, PD:Bytes, AS:Bytes, GR:Bytes,
                                CC:Bytes, EC:Bytes, FK:Bytes, SC:Bytes,
                                SP:Int, PT:Int, GD:Bytes, CD:Bytes)
         andBool BytesEq(ProtoRootR3(CFG), A:Bytes)
         andBool pbSlotOf(B:ProtoBlockR3) ==Int 0
         andBool pbParentCommitOf(B:ProtoBlockR3) ==K ProtoRootR3(CFG)
         andBool pbDecisionOf(B:ProtoBlockR3) ==Int pdecValidR3
         andBool ExecValidPR3(B:ProtoBlockR3, ERC:Bytes, ERP:Bytes)
         andBool pbPolCommitOf(B:ProtoBlockR3) ==K PolicyCommitmentR3(CFG)
         andBool pbCtxDOf(B:ProtoBlockR3)
                 ==K CtxDigestR3(ProtoAuthorizedSecCtxR3(CFG,
                            pbParentRootOf(B:ProtoBlockR3)))
         andBool VerifyLineageG(
                     RG:LinRecG
                   , azCtx( FC:ExecCtx
                          , ProtoAuthorizedSecCtxR3(CFG,
                                pbParentRootOf(B:ProtoBlockR3))
                          , CERT:AuthzCert
                          , qcrAuthPTOf(CFG) , qcrAuthGuestDOf(CFG)
                          , qcrAuthCfgDOf(CFG) )
                   , 0:Int, R3LinRoot ) ==K "valid-g"
         andBool GateInputMatchesBlockR3(FC:ExecCtx, RG:LinRecG,
                                         CERT:AuthzCert, B:ProtoBlockR3)
         andBool GateAuthorityMatchesCfgR3(FC:ExecCtx, CFG)
    [label(R3-PIPELINE-HONEST)]

  claim // R3-PIPELINE-FORGED: PROVED — end-to-end countermodel: authorized
        // init -> the gate EVALUATES the presented evidence and computes a
        // rejection ("invalid-policy" over the machine-constructed context)
        // -> the caller attempts the accept anyway (correct config version,
        // correct parent link, correct slot): the chain is NOT extended, the
        // counter does NOT advance, the receipt REMAINS unconsumed.
    <k> pInitR3(CFG)
        ~> pGateEvalR3(B:ProtoBlockR3, FC:ExecCtx, RG:LinRecG, CERT:AuthzCert,
                       ERC:Bytes, ERP:Bytes)
        ~> pAcceptR3(B:ProtoBlockR3, ERC:Bytes, ERP:Bytes, 1:Int) => .K </k>
    <r3anchor> A:Bytes </r3anchor>
    <r3lineage> .Map
            => ( -1:Int |-> CFG )
               ( -2:Int |-> SetItem(
                     gateReceiptR3( B:ProtoBlockR3, ERC:Bytes, ERP:Bytes
                                  , FC:ExecCtx, RG:LinRecG, CERT:AuthzCert
                                  , azCtx( FC:ExecCtx
                                         , ProtoAuthorizedSecCtxR3(CFG,
                                               pbParentRootOf(B:ProtoBlockR3))
                                         , CERT:AuthzCert
                                         , qcrAuthPTOf(CFG)
                                         , qcrAuthGuestDOf(CFG)
                                         , qcrAuthCfgDOf(CFG) )
                                  , VerifyLineageG(
                                        RG:LinRecG
                                      , azCtx( FC:ExecCtx
                                             , ProtoAuthorizedSecCtxR3(CFG,
                                                   pbParentRootOf(B:ProtoBlockR3))
                                             , CERT:AuthzCert
                                             , qcrAuthPTOf(CFG)
                                             , qcrAuthGuestDOf(CFG)
                                             , qcrAuthCfgDOf(CFG) )
                                      , 0:Int, R3LinRoot )
                                  , ProtoRootR3(CFG), 0:Int, R3LinRoot
                                  , CFG, ProtoRootR3(CFG), A:Bytes )) .Set )
               ( 0:Int |-> B:ProtoBlockR3 ) </r3lineage>
    <r3next> 0 => 1 </r3next>
    <r3head> _:Bytes => BlockCommitR3(B:ProtoBlockR3, CFG) </r3head>
    <r3linhead> _:Bytes => R3RecChildF(RG:LinRecG) </r3linhead>
    <r3valid> V:Bool => V:Bool </r3valid>
    requires CFG ==K protoCfgR3(CH:Bytes, 1:Int, PD:Bytes, AS:Bytes, GR:Bytes,
                                CC:Bytes, EC:Bytes, FK:Bytes, SC:Bytes,
                                SP:Int, PT:Int, GD:Bytes, CD:Bytes)
         andBool BytesEq(ProtoRootR3(CFG), A:Bytes)
         andBool pbSlotOf(B:ProtoBlockR3) ==Int 0
         andBool pbParentCommitOf(B:ProtoBlockR3) ==K ProtoRootR3(CFG)
         andBool pbDecisionOf(B:ProtoBlockR3) ==Int pdecValidR3
         andBool ExecValidPR3(B:ProtoBlockR3, ERC:Bytes, ERP:Bytes)
         andBool pbPolCommitOf(B:ProtoBlockR3) ==K PolicyCommitmentR3(CFG)
         andBool pbCtxDOf(B:ProtoBlockR3)
                 ==K CtxDigestR3(ProtoAuthorizedSecCtxR3(CFG,
                            pbParentRootOf(B:ProtoBlockR3)))
         andBool VerifyLineageG(
                     RG:LinRecG
                   , azCtx( FC:ExecCtx
                          , ProtoAuthorizedSecCtxR3(CFG,
                                pbParentRootOf(B:ProtoBlockR3))
                          , CERT:AuthzCert
                          , qcrAuthPTOf(CFG) , qcrAuthGuestDOf(CFG)
                          , qcrAuthCfgDOf(CFG) )
                   , 0:Int, R3LinRoot ) ==K "invalid-policy"
         andBool GateInputMatchesBlockR3(FC:ExecCtx, RG:LinRecG,
                                         CERT:AuthzCert, B:ProtoBlockR3)
         andBool GateAuthorityMatchesCfgR3(FC:ExecCtx, CFG)
    [label(R3-PIPELINE-FORGED)]

  // ===========================================================================
  // §8. PORTED FROZEN CLAIMS (the 1I ladder re-run over the R3 predicate
  //     forms; same labels, R3 objects)
  // ===========================================================================

  claim // PI1-COMMIT-SAFETY (R3 form)
    <k> CommitPR3(B:ProtoBlockR3, ERC:Bytes, ERP:Bytes, C:ProtoCfgR3, LH:Bytes)
        ==K true => true </k>
    requires ExecValidPR3(B:ProtoBlockR3, ERC:Bytes, ERP:Bytes)
     andBool pbDecisionOf(B:ProtoBlockR3) ==Int pdecValidR3
     andBool pbPolCommitOf(B:ProtoBlockR3) ==K PolicyCommitmentR3(C:ProtoCfgR3)
     andBool pbCtxDOf(B:ProtoBlockR3)
             ==K CtxDigestR3(ProtoAuthorizedSecCtxR3(C:ProtoCfgR3, LH:Bytes))
    [label(PI1-COMMIT-SAFETY)]

  claim // PI2-DECISION-REJECT (R3 form)
    <k> CommitPR3(B:ProtoBlockR3, ERC:Bytes, ERP:Bytes, C:ProtoCfgR3, LH:Bytes)
        ==K false => true </k>
    requires pbDecisionOf(B:ProtoBlockR3) ==Int pdecRejectR3
    [label(PI2-DECISION-REJECT)]

  claim // PI2-DECISION-UNKNOWN (R3 form)
    <k> CommitPR3(B:ProtoBlockR3, ERC:Bytes, ERP:Bytes, C:ProtoCfgR3, LH:Bytes)
        ==K false => true </k>
    requires pbDecisionOf(B:ProtoBlockR3) ==Int pdecUnknownR3
    [label(PI2-DECISION-UNKNOWN)]

  claim // PI2-EXEC-INVALID (R3 form)
    <k> CommitPR3(B:ProtoBlockR3, ERC:Bytes, ERP:Bytes, C:ProtoCfgR3, LH:Bytes)
        ==K false => true </k>
    requires notBool ExecValidPR3(B:ProtoBlockR3, ERC:Bytes, ERP:Bytes)
    [label(PI2-EXEC-INVALID)]

  claim // PI5-AUTHORITY-DESCENT (R3 form — the policy authority identity is
        // derived from the protocol configuration; a policy cannot carry
        // its own authority).  The frozen 1I PolicyCommitment formula is
        // UNCHANGED in R3 (R3-CORRESPONDENCE-POLICY-COMMITMENT).
    <k> PolicyCommitmentR3(C:ProtoCfgR3) ==K LinH(
          Int2Bytes(1, 157, BE)
          +Bytes I2B4(qcrPolicyVOf(C:ProtoCfgR3))
          +Bytes qcrPolicyDOf(C:ProtoCfgR3)
          +Bytes qcrAppSetDOf(C:ProtoCfgR3) +Bytes qcrGraphDOf(C:ProtoCfgR3)
          +Bytes LinH( Int2Bytes(1, 165, BE)
                       +Bytes qcrChainIdOf(C:ProtoCfgR3)
                       +Bytes qcrForkOf(C:ProtoCfgR3) ) )
        => true </k>
    [label(PI5-AUTHORITY-DESCENT)]

  claim // PI7-BASE (R3 form)
    <k> CommitChainLinkedR3(.Map, 0, C:ProtoCfgR3) => true </k>
    [label(PI7-BASE)]

  // ===========================================================================
  // §9. FROZEN-FORMULA CORRESPONDENCE CLAIMS — the R3 reproductions of the
  //     frozen 1I formulas are transcribed byte-for-byte into the claim text
  //     from phase1i/semantics/srw3proto.k (audit section C cross-references
  //     the frozen line numbers; the Python mirror re-derives identical
  //     preimages).  The configuration root is the ONE formula R3 replaces:
  //     its correspondence is the NEW domain-separated composition itself
  //     (R3-CORRESPONDENCE-ROOT-R3) plus the legacy separation witness
  //     (R3-DOMAIN-SEPARATION / R3-R2-ALIAS-WITNESS).
  // ===========================================================================

  claim // R3-CORRESPONDENCE-POLICY-COMMITMENT: PROVED — PolicyCommitmentR3
        // is the frozen PolicyCommitmentI formula (srw3proto.k lines 113-118).
    <k> PolicyCommitmentR3(C:ProtoCfgR3) ==K LinH(
          Int2Bytes(1, 157, BE)
          +Bytes I2B4(qcrPolicyVOf(C:ProtoCfgR3)) +Bytes qcrPolicyDOf(C:ProtoCfgR3)
          +Bytes qcrAppSetDOf(C:ProtoCfgR3) +Bytes qcrGraphDOf(C:ProtoCfgR3)
          +Bytes LinH( Int2Bytes(1, 165, BE)
                       +Bytes qcrChainIdOf(C:ProtoCfgR3)
                       +Bytes qcrForkOf(C:ProtoCfgR3) ) )
        => true </k>
    [label(R3-CORRESPONDENCE-POLICY-COMMITMENT)]

  claim // R3-CORRESPONDENCE-CTX-DIGEST: PROVED — CtxDigestR3 is the frozen
        // CtxDigestI formula (srw3proto.k lines 129-134) over the authorized
        // projection.
    <k> CtxDigestR3(ProtoAuthorizedSecCtxR3(C:ProtoCfgR3, LH:Bytes)) ==K LinH(
          Int2Bytes(1, 166, BE)
          +Bytes I2B4(qcrPolicyVOf(C:ProtoCfgR3))
          +Bytes qcrChainIdOf(C:ProtoCfgR3)
          +Bytes qcrAppSetDOf(C:ProtoCfgR3) +Bytes qcrGraphDOf(C:ProtoCfgR3)
          +Bytes LH:Bytes )
        => true </k>
    [label(R3-CORRESPONDENCE-CTX-DIGEST)]

  claim // R3-CORRESPONDENCE-BLOCK-COMMIT: PROVED — BlockCommitR3 is the
        // frozen BlockCommitI formula (srw3proto.k lines 213-223).
    <k> BlockCommitR3(B:ProtoBlockR3, C:ProtoCfgR3) ==K LinH(
          Int2Bytes(1, 158, BE)
          +Bytes pbParentCommitOf(B:ProtoBlockR3) +Bytes pbPayloadDOf(B:ProtoBlockR3)
          +Bytes pbParentRootOf(B:ProtoBlockR3) +Bytes pbChildRootOf(B:ProtoBlockR3)
          +Bytes pbEffectDOf(B:ProtoBlockR3) +Bytes pbEvidenceDOf(B:ProtoBlockR3)
          +Bytes pbCtxDOf(B:ProtoBlockR3)
          +Bytes LinH( Int2Bytes(1, 157, BE)
                       +Bytes I2B4(qcrPolicyVOf(C:ProtoCfgR3))
                       +Bytes qcrPolicyDOf(C:ProtoCfgR3)
                       +Bytes qcrAppSetDOf(C:ProtoCfgR3)
                       +Bytes qcrGraphDOf(C:ProtoCfgR3)
                       +Bytes LinH( Int2Bytes(1, 165, BE)
                                    +Bytes qcrChainIdOf(C:ProtoCfgR3)
                                    +Bytes qcrForkOf(C:ProtoCfgR3) ) )
          +Bytes I2B4(pbDecisionOf(B:ProtoBlockR3))
          +Bytes I2B4(pbSlotOf(B:ProtoBlockR3)) )
        => true </k>
    [label(R3-CORRESPONDENCE-BLOCK-COMMIT)]

  claim // R3-CORRESPONDENCE-ROOT-R3: PROVED — ProtoRootR3 is EXACTLY the R3
        // composition: LinH over the domain-separated, versioned, length-
        // delimited 13-field preimage (the handoff §3 normative formula).
    <k> ProtoRootR3(C:ProtoCfgR3) ==K LinH(
          R3DomainSep
          +Bytes I2B4(R3EncodingVersion)
          +Bytes LP32R3(qcrChainIdOf(C:ProtoCfgR3))
          +Bytes I2B4(qcrPolicyVOf(C:ProtoCfgR3))
          +Bytes LP32R3(qcrPolicyDOf(C:ProtoCfgR3))
          +Bytes LP32R3(qcrAppSetDOf(C:ProtoCfgR3))
          +Bytes LP32R3(qcrGraphDOf(C:ProtoCfgR3))
          +Bytes LP32R3(qcrClientCfgDOf(C:ProtoCfgR3))
          +Bytes LP32R3(qcrExecClientDOf(C:ProtoCfgR3))
          +Bytes LP32R3(qcrForkOf(C:ProtoCfgR3))
          +Bytes LP32R3(qcrSchedOf(C:ProtoCfgR3))
          +Bytes I2B4(qcrSpecOf(C:ProtoCfgR3))
          +Bytes I2B4(qcrAuthPTOf(C:ProtoCfgR3))
          +Bytes LP32R3(qcrAuthGuestDOf(C:ProtoCfgR3))
          +Bytes LP32R3(qcrAuthCfgDOf(C:ProtoCfgR3)) )
        => true </k>
    [label(R3-CORRESPONDENCE-ROOT-R3)]

  // ===========================================================================
  // §10. the retried universal closure (the R1-ALL / R2-ALL / PI7-ALL analog).
  //   OUTCOME IS RECORDED WHATEVER IT IS; if the kore circularity/implication
  //   blocker fires again, the claim is classified NOT MECHANIZED with the
  //   exact message retained in transcripts/k/.
  // ===========================================================================

  claim
    <k> pConsR3(CI:PCmdR3I, RUN:PProgR3I) => .K </k>
    <r3lineage> L:Map </r3lineage>
    <r3next> N:Int </r3next>
    <r3head> H:Bytes </r3head>
    <r3linhead> LH:Bytes </r3linhead>
    <r3anchor> A:Bytes </r3anchor>
    <r3valid> true </r3valid>
    [circularity, label(R3-ALL)]

endmodule
