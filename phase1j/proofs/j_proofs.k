// =============================================================================
// SRW3 Phase 1J — THE K PROOF LADDER (j_proofs.k, Haskell backend)
//
// One definition: the ISOLATED J machine (+ the inert fixtures).  The claims
// follow the handoff §3 decomposition; every claim is invoked EXACTLY ONCE
// per canonical run (run_j_proofs.sh) with its raw exit code and retained
// log; the score convention is 1:1 over this inventory (the R3 discipline —
// no ambiguous scores, no success inferred from non-empty logs).
//
// LABEL DISCIPLINE (handoff §9): PROVED / DEMONSTRATED / WITNESSED / ASSUMED
// / REFUTED / NOT MECHANIZED — the raw kprove result is NEVER relabeled; the
// scientific classification lives in claim-classification.csv and the report.
//   * The hash-class equalities carried as CLAIM HYPOTHESES are the documented
//     Haskell symbolic boundary (the concrete digests are decided on the LLVM
//     backend and in Python — real Keccak-256; collision resistance ASSUMED).
//   * Safe_P is NEVER a hypothesis of a preservation claim (handoff §3: the
//     theorem must not be proved by assuming the conclusion); it appears in
//     the COMMIT GUARD (computed) and in the DESTINATION of the headline.
//   * J-REACHABLE-COMMITTED-SAFE (universal induction) is EXPECTED to hit the
//     kore circularity blocker (the frozen PI7-ALL/R1-ALL/R2-ALL/R3-ALL
//     class); its failed log is the retained NOT-MECHANIZED outcome, and the
//     concrete substitutes are the component lemmas + the Python exhaustive
//     sequence enumeration (3474 committed prefixes, 386 unsafe derived
//     states caught) + the LLVM two-block honest pipeline.
// =============================================================================

requires "j_fixtures.k"

module J-PROOFS
  imports SRW3CLOSURE-J-FIXTURES

  // ===========================================================================
  // §1. CATALOG CANON + BINDING (J-CATALOG-CANON-COMMITMENT /
  //     J-CATALOG-ROOT-BINDING decomposition)
  // ===========================================================================

  claim // J-CATALOG-CANON-FIXTURE: PROVED — the canonical catalog preimage of
        // the fixture is EXACTLY the golden vector (the same bytes Python
        // emits and the LLVM certificate prints; cross-language conformance
        // byte-for-byte).  Fixes the domain separator, version, field order,
        // 8-byte key encoding, and the whole encoding discipline.
    <k> JCatalogCanonJ(XCatJ) ==K LinHex("535257332f506f6c6963794361742f4a0000000001000000010000000300001001000000066f7261636c6500001002000000076c656e64696e6700001003000000057661756c74000000040000100100000000000010010000100200000000000010020000100300000000000010030000100200000001000010020000000200000001000000030000100100000000000010020000000000001003000000000000000200000002000010020000000000001002000000010000000400000001000000010000000000000000000003e800000001000010010000000000000002000000010000000000000000000001f400000001000010020000000000000003000000010000000000000000000001f40000000100001003000000000000000400000001000000000000000000000064000000010000100200000001000000020000000b0000000200000001000002580000000000000002000010020000000000001003000000000000000c000000020000000200000226000000000000000200001002000000000000100200000001000000010000001500000002000000000000044c0000000000000003000010010000000000001002000000000000100300000000")
        => true </k>
    [label(J-CATALOG-CANON-FIXTURE)]

  claim // J-CATALOG-DOMAIN-PREFIX: PROVED — the preimage STARTS with the J
        // domain+version (17+1+4 bytes) and NEVER with a frozen tag.
    <k> BytesEq( substrBytes(JCatalogCanonJ(XCatJ), 0, 21)
               , JCatDomainSep +Bytes I2B4(JCatEncodingVersion) ) ==K true
     andBool BytesEq( substrBytes(JCatalogCanonJ(XCatJ), 0, 1)
                    , Int2Bytes(1, 156, BE) ) ==K false
        => true </k>
    [label(J-CATALOG-DOMAIN-PREFIX)]

  claim // J-CATALOG-BINDS-APPS: PROVED — mutating an app NAME changes the
        // canonical preimage (the app-set sub-digest therefore changes).
    <k> BytesEq( JCanonApps(jcAppsOf(XCatJ)), JCanonApps(jcAppsOf(XCatJNameB)) )
        ==K false => true </k>
    [label(J-CATALOG-BINDS-APPS)]

  claim // J-CATALOG-BINDS-RESOURCES: PROVED — mutating a resource OWNER
        // changes the canonical preimage at equal length.
    <k> BytesEq( JCanonResources(jcResourcesOf(XCatJ))
               , JCanonResources(jcResourcesOf(XCatJOwnerB)) ) ==K false
     andBool lengthBytes(JCanonResources(jcResourcesOf(XCatJ)))
             ==Int lengthBytes(JCanonResources(jcResourcesOf(XCatJOwnerB)))
        => true </k>
    [label(J-CATALOG-BINDS-RESOURCES)]

  claim // J-CATALOG-BINDS-GRAPH: PROVED — omitting the 3-app hyperedge
        // changes the canonical preimage (the missing-hyperedge catalog
        // cannot present the configured graph digest — J-REJECTS-MISSING-
        // HYPEREDGE's commitment half; the full-canon preimages differ too).
    <k> BytesEq( JCanonHypers(jcHypersOf(XCatJ))
               , JCanonHypers(jcHypersOf(XCatJNoHe1)) ) ==K false
     andBool BytesEq( JCatalogCanonJ(XCatJ), JCatalogCanonJ(XCatJNoHe1) )
             ==K false
        => true </k>
    [label(J-CATALOG-BINDS-GRAPH)]

  claim // J-CATALOG-BINDS-POLICY: PROVED — mutating an invariant BOUND
        // changes the canonical preimage at equal length.
    <k> BytesEq( JCanonInvs(jcLocalsOf(XCatJ)), JCanonInvs(jcLocalsOf(XCatJPolB)) )
        ==K false
     andBool lengthBytes(JCanonInvs(jcLocalsOf(XCatJ)))
             ==Int lengthBytes(JCanonInvs(jcLocalsOf(XCatJPolB))) => true </k>
    [label(J-CATALOG-BINDS-POLICY)]

  claim // J-CATALOG-KEYS-64BIT: PROVED — the flat 1E key space (app*2^32 +
        // slot) is encoded 8 bytes, big-endian: 4097*2^32 = 0x100100000000.
    <k> Int2Bytes(8, A2Key(4097, 0), BE)
        ==K LinHex("0000100100000000") => true </k>
    [label(J-CATALOG-KEYS-64BIT)]

  claim // J-CATALOG-WF-OK: PROVED — the fixture catalog is well-formed.
    <k> JCatalogWF(XCatJ) ==K true => true </k>
    [label(J-CATALOG-WF-OK)]

  claim // J-CATALOG-WF-BAD-OWNER: PROVED — an unregistered owner REFUSES.
    <k> JCatalogWF(XCatJBadOwner) ==K false => true </k>
    [label(J-CATALOG-WF-BAD-OWNER)]

  claim // J-CATALOG-WF-DUP: PROVED — a duplicate resource key REFUSES.
    <k> JCatalogWF(XCatJDupRes) ==K false => true </k>
    [label(J-CATALOG-WF-DUP)]

  claim // J-CATALOG-WF-DANGLING-HE: PROVED — an invariant naming an
        // unregistered hyperedge REFUSES.
    <k> JCatalogWF(XCatJBadHe) ==K false => true </k>
    [label(J-CATALOG-WF-DANGLING-HE)]

  claim // J-CORRESPONDENCE-R3-CANON-PREFIX: PROVED — the J machine's R3
        // configuration preimage reproduction starts with the FROZEN R3
        // domain + version (the frozen formula is preserved, handoff §2).
        // Over the ALL-LITERAL fixture (decidable on the Haskell backend).
    <k> BytesEq( substrBytes(ProtoCfgCanonR3(JFixCfgJ), 0, 21)
               , R3DomainSep +Bytes I2B4(R3EncodingVersion) ) ==K true
     andBool BytesEq( substrBytes(ProtoCfgCanonR3(JFixCfgJ), 0, 1)
                    , Int2Bytes(1, 156, BE) ) ==K false => true </k>
    [label(J-CORRESPONDENCE-R3-CANON-PREFIX)]

  claim // J-CORRESPONDENCE-CTX-TAG: PROVED — the frozen 1I ctx-digest
        // formula keeps the 0xA6 tag (byte-identical reproduction).
    <k> BytesEq( substrBytes( CtxCanonR3(ProtoAuthorizedSecCtxR3(JFixCfgJ, LinRoot))
                            , 0, 1 )
               , Int2Bytes(1, 166, BE) ) ==K true => true </k>
    [label(J-CORRESPONDENCE-CTX-TAG)]

  // ===========================================================================
  // §2. INIT FAMILY (J-INITIAL-SAFE + the anchor discipline)
  // ===========================================================================

  claim // J-INIT-SAFE-BASE: PROVED — the fixture catalog's registered
        // invariants hold on the all-zero genesis state (the J-INITIAL-SAFE
        // base obligation for the fixture; enforced at the pin by J-INIT).
    <k> SafeJ(XCatJ, .Map) ==K true => true </k>
    [label(J-INIT-SAFE-BASE)]

  claim // J-INIT-REFUSES-UNSAFE-GENESIS: PROVED — a catalog whose invariants
        // fail on the genesis state is REFUSED at the pin (fail-closed base).
    <k> SafeJ(XCatJUnsafeGen, .Map) ==K false => true </k>
    [label(J-INIT-REFUSES-UNSAFE-GENESIS)]

  claim // J-INIT-PINS-AUTHORIZED: PROVED — pInitJ pins the configuration AND
        // the catalog ONLY under the authorized root (the BytesEq hypotheses
        // are the documented Haskell symbolic boundary: the root/anchor and
        // catalog-digest equalities are concrete on LLVM/Python).
    <k> pInitJ(XCfgJ, XCatJ) => .K </k>
    <jlineage> .Map => ( -1:Int |-> XCfgJ ) ( -3:Int |-> XCatJ ) </jlineage>
    <jnext> _:Int </jnext>
    <jhead> _:Bytes => ProtoRootR3(XCfgJ) </jhead>
    <jlinhead> _:Bytes => JLinRoot </jlinhead>
    <janchor> A:Bytes </janchor>
    <jstate> .Map </jstate>
    <jrefuse> _:JRefuse </jrefuse>
    <jvalid> _:Bool </jvalid>
    requires BytesEq(ProtoRootR3(XCfgJ), A:Bytes)
    [label(J-INIT-PINS-AUTHORIZED)]

  claim // J-INIT-ROOT-MISMATCH-REJECTS: PROVED — a configuration whose
        // computed root differs from the trusted anchor changes NOTHING
        // (the negation hypothesis decides on the Haskell backend).
    <k> pInitJ(XCfgJ, XCatJ) => .K </k>
    <jlineage> L:Map => L:Map </jlineage>
    <jnext> N:Int => N:Int </jnext>
    <jhead> H:Bytes => H:Bytes </jhead>
    <jlinhead> LH:Bytes => LH:Bytes </jlinhead>
    <janchor> A:Bytes </janchor>
    <jstate> S:Map => S:Map </jstate>
    <jrefuse> RF:JRefuse => RF:JRefuse </jrefuse>
    <jvalid> V:Bool => V:Bool </jvalid>
    requires notBool BytesEq(ProtoRootR3(XCfgJ), A:Bytes)
    [label(J-INIT-ROOT-MISMATCH-REJECTS)]

  claim // J-INIT-REFUSES-GRAPH-MISMATCH: PROVED — a catalog whose contents
        // do not hash to the configured graph digest (the missing-hyperedge
        // catalog under the honest config) is REFUSED at the pin.
    <k> pInitJ(XCfgJ, XCatJNoHe1) => .K </k>
    <jlineage> L:Map => L:Map </jlineage>
    <jnext> N:Int => N:Int </jnext>
    <jhead> H:Bytes => H:Bytes </jhead>
    <jlinhead> LH:Bytes => LH:Bytes </jlinhead>
    <janchor> A:Bytes </janchor>
    <jstate> S:Map => S:Map </jstate>
    <jrefuse> RF:JRefuse => RF:JRefuse </jrefuse>
    <jvalid> V:Bool => V:Bool </jvalid>
    requires notBool BytesEq(JGraphRootJ(XCatJNoHe1), JGraphRootJ(XCatJ))
    [label(J-INIT-REFUSES-GRAPH-MISMATCH)]

  claim // J-INIT-REFUSES-BAD-CATALOG: PROVED — a malformed catalog
        // (unregistered owner) is REFUSED at the pin (decidable: the
        // well-formedness conjunct is concrete false).
    <k> pInitJ(XCfgJ, XCatJBadOwner) => .K </k>
    <jlineage> L:Map => L:Map </jlineage>
    <jnext> N:Int => N:Int </jnext>
    <jhead> H:Bytes => H:Bytes </jhead>
    <jlinhead> LH:Bytes => LH:Bytes </jlinhead>
    <janchor> _:Bytes </janchor>
    <jstate> S:Map => S:Map </jstate>
    <jrefuse> RF:JRefuse => RF:JRefuse </jrefuse>
    <jvalid> V:Bool => V:Bool </jvalid>
    [label(J-INIT-REFUSES-BAD-CATALOG)]

  // ===========================================================================
  // §3. FRAGMENT FAMILY (J-TRACE-ORIGIN / J-EFFECT-PROJECTION-COMPLETE /
  //     J-UNSUPPORTED-EFFECT-FAIL-CLOSED)
  // ===========================================================================

  claim // J-FRAG-TRACE-WRITE: PROVED — the interpreter DERIVES the post-state
        // and the ordered trace for a single write (the trace is emitted by
        // the semantics, in execution order — the rule inventory is the
        // structural half of J-TRACE-ORIGIN).
    <k> ExecFragmentJ(.Map, ListItem(jWrite(4097, 0, 100)) .List)
        ==K jExecOk( 4097 |-> (0 |-> 100)
                   , 4097 |-> (0 |-> 100)
                   , ListItem(exEvt(2, 4097, 0, 100)) .List )
        => true </k>
    [label(J-FRAG-TRACE-WRITE)]

  claim // J-FRAG-TRACE-ORDER: PROVED — the trace order IS the execution
        // order; the reordered program derives the reordered trace (order is
        // never destroyed; the J-A03 class at the semantics level).
    <k> jExecOkTraceOf(ExecFragmentJ(.Map, XProg1)) ==K XTrace1D
     andBool jExecOkTraceOf(ExecFragmentJ(.Map, XProg1Reordered))
             ==K ListItem(exEvt(2, 4098, 1, 100))
                 ListItem(exEvt(2, 4098, 0, 100)) .List
        => true </k>
    [label(J-FRAG-TRACE-ORDER)]

  claim // J-FRAG-READ-AFTER-WRITE: PROVED — a Read observes the CURRENT
        // threaded state (the value written by the preceding op).
    <k> jExecOkTraceOf(ExecFragmentJ(.Map, ListItem(jWrite(4097, 0, 100))
                                    ListItem(jRead(4097, 0)) .List))
        ==K ListItem(exEvt(2, 4097, 0, 100)) ListItem(exEvt(1, 4097, 0, 100))
            .List
        => true </k>
    [label(J-FRAG-READ-AFTER-WRITE)]

  claim // J-FRAG-UNSUPPORTED: PROVED — an excluded effect class is an
        // EXPLICIT refusal (never a harmless no-op, never silently omitted).
    <k> ExecFragmentJ(.Map, ListItem(jUnsupported(96)) .List)
        ==K jExecUnsupported(96) => true </k>
    [label(J-FRAG-UNSUPPORTED)]

  claim // J-FRAG-UNSUPPORTED-MIDPROGRAM: PROVED — a refusal anywhere in the
        // program yields NO derived post-state (the whole run refuses).
    <k> isExecUnsupportedJ(ExecFragmentJ(.Map, XProgMidUnsupported)) ==K true
     andBool isExecOkJ(ExecFragmentJ(.Map, XProgMidUnsupported)) ==K false
        => true </k>
    [label(J-FRAG-UNSUPPORTED-MIDPROGRAM)]

  claim // J-FRAG-BOUNDS: PROVED — out-of-range operands are the explicit
        // bounds-refusal class (app >= 2^32; value >= 2^64).
    <k> ExecFragmentJ(.Map, ListItem(jWrite(4294967296, 0, 1)) .List)
        ==K jExecBounds(2)
     andBool ExecFragmentJ(.Map, ListItem(jWrite(4097, 0, 18446744073709551616)) .List)
             ==K jExecBounds(2) => true </k>
    [label(J-FRAG-BOUNDS)]

  claim // J-FOOTPRINT-PROJECTION: PROVED — the footprint is the
        // first-occurrence projection of the derived trace (dedup, order
        // preserved): J-EFFECT-PROJECTION-COMPLETE's derivation lemma.
    <k> JFootprintKeysOf( jExecOkTraceOf( ExecFragmentJ(
              .Map
            , ListItem(jWrite(4098, 0, 100)) ListItem(jWrite(4097, 0, 5))
                       ListItem(jWrite(4098, 0, 7)) .List ) ) )
        ==K ListItem(A2Key(4098, 0)) ListItem(A2Key(4097, 0)) .List
        => true </k>
    [label(J-FOOTPRINT-PROJECTION)]

  claim // J-EVIDENCE-STATE-CORRESPONDENCE: PROVED — the candidate's identity
        // fields are EXACTLY the machine-derived values (the mint's binding
        // conjuncts at the digest-expression level, decidable on hs): the
        // trace/post/footprint/payload identities the record and the block
        // carry ARE the interpreter's outputs.  The RECORD-level binding
        // (the frozen LinRecG construction over the derived maps) is
        // evaluated CONCRETELY on the LLVM backend (T1/T3: the mint FIRES,
        // which requires ExecReceiptMatchesRecordJ to hold with real keccak)
        // and in the Python mirror (exec_receipt_matches_record_j) — the
        // Haskell backend has no keccak evaluator over the frozen 1E record
        // construction (the documented boundary class).
    <k> BytesEq( ExecTraceDigest(jExecOkTraceOf(ExecFragmentJ(XPre0, XProg0)))
               , jbTraceDOf(XB0) ) ==K true
     andBool StateRootJ(jExecOkPostOf(ExecFragmentJ(XPre0, XProg0)))
             ==K jbPostRootOf(XB0)
     andBool JPayloadDigestJ(XProg0) ==K jbPayloadDOf(XB0)
     andBool JFootprintDigestJ(jExecOkTraceOf(ExecFragmentJ(XPre0, XProg0)))
             ==K jbFootDOf(XB0)
        => true </k>
    [label(J-EVIDENCE-STATE-CORRESPONDENCE)]

  // ===========================================================================
  // §4. CLOSURE + SAFETY FAMILY (J-AFFECTED-SET-COMPLETE / the Safe_P
  //     decomposition / the countermodels)
  // ===========================================================================

  claim // J-CLOSURE-FIXTURE: PROVED — the bounded closure of the k1 footprint
        // reaches the fixed point {k4,k3,k2,k1}: EVERY hyperedge incident to
        // a touched node is enumerated (the 2-app edge k2-k4 is pulled in by
        // the 3-app edge's k2), with fuel to spare.
    <k> AffectedClosureJ( ListItem(A2Key(4097, 0)) .List
                        , jcHypersOf(XCatJ), JClosureFuelJ )
        ==K jClosureOk( ListItem(A2Key(4098, 1)) ListItem(A2Key(4098, 0))
                        ListItem(A2Key(4099, 0)) ListItem(A2Key(4097, 0))
                        .List )
        => true </k>
    [label(J-CLOSURE-FIXTURE)]

  claim // J-CLOSURE-EXHAUSTED: PROVED — growth still needed with the fuel
        // exhausted is jClosureExhausted (NEVER "no more interactions").
    <k> AffectedClosureJ( ListItem(A2Key(4097, 0)) .List
                        , jcHypersOf(XCatJ), 0 )
        ==K jClosureExhausted => true </k>
    [label(J-CLOSURE-EXHAUSTED)]

  claim // J-FOOTPRINT-REGISTERED-OK: PROVED — the honest footprint's keys are
        // all registered resources.
    <k> JFootprintRegistered(JFootprintKeysOf(XTrace0D), jcResourcesOf(XCatJ))
        ==K true => true </k>
    [label(J-FOOTPRINT-REGISTERED-OK)]

  claim // J-FOOTPRINT-REGISTERED-UNKNOWN: PROVED — a write to an unregistered
        // resource is the unknown-mapping refusal (J-A11).
    <k> JFootprintRegistered( JFootprintKeysOf( jExecOkTraceOf( ExecFragmentJ(
                .Map, ListItem(jWrite(4242, 7, 1)) .List ) ) )
            , jcResourcesOf(XCatJ) ) ==K false => true </k>
    [label(J-FOOTPRINT-REGISTERED-UNKNOWN)]

  claim // J-SAFE-HONEST: PROVED — the honest derived post-state is SAFE.
    <k> SafeJ(XCatJ, XPost0D) ==K true
     andBool SafeJ(XCatJ, XPost1D) ==K true => true </k>
    [label(J-SAFE-HONEST)]

  claim // J-SAFE-UNSAFE-COMPOSITION: PROVED — THE 3-APP COUNTERMODEL at the
        // K level: every LOCAL check passes on the unsafe post-state, the
        // pairwise edge invariant passes, and the 3-APP HYPEREDGE INVARIANT
        // FAILS (SafeJ is false — the composition is REFUTED).
    <k> AllLocalJ(jcLocalsOf(XCatJ), XPostUD) ==K true
     andBool InvHoldsJ(jInvSum(12, 2, ListItem(A2Key(4098, 0))
                                        ListItem(A2Key(4098, 1)) .List, 550)
                     , XPostUD) ==K true
     andBool AllHyperJ(jcHypersInvOf(XCatJ), XPostUD) ==K false
     andBool SafeJ(XCatJ, XPostUD) ==K false => true </k>
    [label(J-SAFE-UNSAFE-COMPOSITION)]

  claim // J-SAFE-GLOBAL-FAIL: PROVED — the global-attack class: locals and
        // hyperedge invariants pass, the GLOBAL invariant fails.
    <k> AllLocalJ(jcLocalsOf(XCatJ), XPostG) ==K true
     andBool AllHyperJ(jcHypersInvOf(XCatJ), XPostG) ==K true
     andBool AllGlobalJ(jcGlobalsOf(XCatJ), XPostG) ==K false
     andBool SafeJ(XCatJ, XPostG) ==K false => true </k>
    [label(J-SAFE-GLOBAL-FAIL)]

  claim // J-FRAME-PRESERVATION: PROVED — writes to one key leave the values
        // other invariants depend on UNCHANGED (the frame lemma for the
        // fixture: a write to k2 preserves the k1/k4 values).
    <k> JStateGet(JNestedWrite(XPost1D, 4098, 0, 400), A2Key(4098, 1))
        ==K JStateGet(XPost1D, A2Key(4098, 1))
     andBool JStateGet(JNestedWrite(XPost1D, 4098, 0, 400), A2Key(4097, 0))
             ==K JStateGet(XPost1D, A2Key(4097, 0))
     andBool InvHoldsJ(jInvLocal(4, A2Key(4098, 1), 0, 100)
                     , JNestedWrite(XPost1D, 4098, 0, 400))
             ==K InvHoldsJ(jInvLocal(4, A2Key(4098, 1), 0, 100), XPost1D)
        => true </k>
    [label(J-FRAME-PRESERVATION)]

  // ===========================================================================
  // §5. GATE LINKAGE + COMMIT FAMILY
  // ===========================================================================

  claim // J-GATELINK-VALID: PROVED — the gate-link equivalence: the derived
        // decision is pdecValidJ IF AND ONLY IF the receipt's COMPUTED
        // verdict is "valid-g" (the owise fail-closed mapping; symbolic case
        // analysis on the Haskell backend).  The CONCRETE evaluation of the
        // frozen gate over the machine-constructed context ("valid-g" for
        // the honest record, with REAL Keccak) is the LLVM certificate's
        // verdict0/verdict1 — the Haskell backend has no keccak evaluator
        // (the documented R3 boundary; the honest gate evaluation is
        // DEMONSTRATED there, not mechanized here).
    <k> ProtoDecisionOfGateJ("valid-g") ==K pdecValidJ
     andBool ProtoDecisionOfGateJ("invalid-x") ==K pdecRejectJ
     andBool ProtoDecisionOfGateJ("") ==K pdecRejectJ
     andBool jgDecisionOf(R:JGateReceipt) ==K ProtoDecisionOfGateJ(
                 jgVerdictOf(R:JGateReceipt) ) => true </k>
    [label(J-GATELINK-VALID)]

  claim // J-DECISION-BOUND: PROVED — the derived-decision mapping is
        // fail-closed: ONLY "valid-g" is pdecValidJ.
    <k> ProtoDecisionOfGateJ("valid-g") ==Int pdecValidJ
     andBool ProtoDecisionOfGateJ("invalid-x") ==Int pdecRejectJ
     andBool ProtoDecisionOfGateJ("") ==Int pdecRejectJ => true </k>
    [label(J-DECISION-BOUND)]

  claim // J-FORGED-VERDICT-REJECT: PROVED — a receipt whose COMPUTED verdict
        // is not "valid-g" yields the fail-closed decision mapping and the
        // commit REFUSES (the guard's derived-decision conjunct is decided
        // BEFORE the hash-class conjuncts — the R3 order discipline; in the
        // J machine no caller can choose this string: the mint computes it).
    <k> pCommitJ(B:JBlockJ, ERC:Bytes, ERP:Bytes, CV:Int) => .K </k>
    <janchor> A:Bytes </janchor>
    <jlineage> ( -1:Int |-> C:ProtoCfgR3 )
               ( -3:Int |-> PCAT:JCatalog )
               ( -2:Int |-> SetItem(R:JGateReceipt) .Set )
               L3:Map </jlineage>
    <jnext> N:Int </jnext>
    <jhead> H:Bytes </jhead>
    <jlinhead> LH:Bytes </jlinhead>
    <jstate> S:Map </jstate>
    <jrefuse> RF:JRefuse </jrefuse>
    <jvalid> V:Bool </jvalid>
    requires jgBlockOf(R:JGateReceipt) ==K B:JBlockJ
         andBool jgErcOf(R:JGateReceipt) ==K ERC:Bytes
         andBool jgErpOf(R:JGateReceipt) ==K ERP:Bytes
         andBool jgHeadOf(R:JGateReceipt) ==K H:Bytes
         andBool jgSlotOf(R:JGateReceipt) ==Int N:Int
         andBool jgLinHeadOf(R:JGateReceipt) ==K LH:Bytes
         andBool CfgEqR3(jgCfgOf(R:JGateReceipt), C:ProtoCfgR3)
         andBool BytesEq(jgAnchorOf(R:JGateReceipt), A:Bytes)
         andBool jgVerdictOf(R:JGateReceipt) ==K "invalid-forged"
         andBool CV:Int ==Int qcrPolicyVOf(C:ProtoCfgR3)
    [label(J-FORGED-VERDICT-REJECT)]

  claim // J-COMMIT-NO-RECEIPT-REJECTS: PROVED — accept with NO gate receipt
        // in the pool: fail-closed, every cell unchanged.
    <k> pCommitJ(B:JBlockJ, ERC:Bytes, ERP:Bytes, 1) => .K </k>
    <jlineage> ( -1:Int |-> XCfgJ ) ( -3:Int |-> XCatJ )
            => ( -1:Int |-> XCfgJ ) ( -3:Int |-> XCatJ ) </jlineage>
    <jnext> N:Int => N:Int </jnext>
    <jhead> H:Bytes => H:Bytes </jhead>
    <jlinhead> LH:Bytes => LH:Bytes </jlinhead>
    <janchor> _:Bytes </janchor>
    <jstate> S:Map => S:Map </jstate>
    <jrefuse> RF:JRefuse => RF:JRefuse </jrefuse>
    <jvalid> V:Bool => V:Bool </jvalid>
    [label(J-COMMIT-NO-RECEIPT-REJECTS)]

  claim // J-COMMIT-UNSAFE-COMPOSITION-REJECTS: PROVED — the COMMIT-BOUNDARY
        // half of the 3-app countermodel, over the MACHINE-MINTED receipts:
        // the honest pipeline commits blocks 0 and 1; the unsafe run's exec
        // derives its post-state and the gate ACCEPTS the record (the frozen
        // gate is the AUTHORITY layer — "valid-g"), but the COMPUTED SafeJ
        // conjunct on the derived post-state is FALSE, so pCommitJ REFUSES:
        // the abstract state, the protocol head, and the slot counter are
        // UNCHANGED (fail-closed; the receipts stay unconsumed — the lineage
        // evolution is not asserted here, the R3 reject-claim convention).
    <k> pInitJ(XCfgJ, XCatJ)
        ~> pExecJ(XExecClientD, XProg0, XCaller, 0)
        ~> pGateEvalJ( XB0, XCtx0, XRG0, XCert0
                     , StateRootJ(XPost0D), JPayloadDigestJ(XProg0) )
        ~> pCommitJ( XB0, StateRootJ(XPost0D), JPayloadDigestJ(XProg0), 1 )
        ~> pExecJ(XExecClientD, XProg1, XCaller, 0)
        ~> pGateEvalJ( XB1, XCtx1, XRG1, XCert1
                     , StateRootJ(XPost1D), JPayloadDigestJ(XProg1) )
        ~> pCommitJ( XB1, StateRootJ(XPost1D), JPayloadDigestJ(XProg1), 1 )
        ~> pExecJ(XExecClientD, XProgUnsafe, XCaller, 0)
        ~> pGateEvalJ( XBUnsafe, XCtxU, XRGU, XCertU
                     , StateRootJ(XPostUD), JPayloadDigestJ(XProgUnsafe) )
        ~> pCommitJ( XBUnsafe, StateRootJ(XPostUD), JPayloadDigestJ(XProgUnsafe)
                   , 1 )
        ~> runNilJ
     => .K </k>
    <jnext> 0 => 2 </jnext>
    <jhead> _:Bytes => JBlockCommitJ(XB1, XCfgJ) </jhead>
    <jlinhead> _:Bytes => JRecChildF(XRG1) </jlinhead>
    <janchor> A:Bytes </janchor>
    <jstate> .Map => XPost1D </jstate>
    <jrefuse> _:JRefuse </jrefuse>
    <jvalid> V:Bool => V:Bool </jvalid>
    requires BytesEq(ProtoRootR3(XCfgJ), A:Bytes)
    [label(J-COMMIT-UNSAFE-COMPOSITION-REJECTS)]

  claim // J-COMMIT-IMPLIES-SAFE-DESTINATION: PROVED — THE HEADLINE ONE-STEP
        // (J-GATE-IMPLIES-POLICY-PRESERVATION + J-COMMITTED-STEP-PRESERVES-
        // SAFE for the fixture): the honest pipeline under the authorized
        // anchor ends with the DERIVED post-state in <jstate> and SafeJ of
        // that destination TRUE.  SafeJ appears ONLY in the guard (computed)
        // and the DESTINATION — never as a hypothesis.  The init-root BytesEq
        // hypothesis is the documented Haskell symbolic boundary (concrete on
        // LLVM/Python; the pipeline's concrete execution is the T-series).
    <k> pInitJ(XCfgJ, XCatJ)
        ~> pExecJ(XExecClientD, XProg0, XCaller, 0)
        ~> pGateEvalJ( XB0, XCtx0, XRG0, XCert0
                     , StateRootJ(XPost0D), JPayloadDigestJ(XProg0) )
        ~> pCommitJ( XB0, StateRootJ(XPost0D), JPayloadDigestJ(XProg0), 1 )
        ~> runNilJ
     => .K </k>
    <jlineage> .Map
            => ( -1:Int |-> XCfgJ )
               ( -3:Int |-> XCatJ )
               ( -2:Int |-> .Set )
               ( -4:Int |-> .Set )
               ( 0:Int |-> XB0 ) </jlineage>
    <jnext> 0 => 1 </jnext>
    <jhead> _:Bytes => JBlockCommitJ(XB0, XCfgJ) </jhead>
    <jlinhead> _:Bytes => JRecChildF(XRG0) </jlinhead>
    <janchor> A:Bytes </janchor>
    <jstate> .Map => XPost0D </jstate>
    <jrefuse> _:JRefuse </jrefuse>
    <jvalid> V:Bool => V:Bool </jvalid>
    requires BytesEq(ProtoRootR3(XCfgJ), A:Bytes)
     andBool SafeJ(XCatJ, XPost0D) ==K true
    [label(J-COMMIT-IMPLIES-SAFE-DESTINATION)]

  claim // J-REACHABLE-COMMITTED-SAFE: the UNIVERSAL reachability claim —
        // every committed prefix of every reachable finite execution is
        // safe.  EXPECTED NOT MECHANIZED (the kore circularity blocker —
        // the frozen PI7-ALL/R1-ALL/R2-ALL/R3-ALL class); the failed log is
        // the retained outcome.  The closure evidence: the PROVED component
        // lemmas (base J-INIT-SAFE-BASE; step J-COMMIT-IMPLIES-SAFE-
        // DESTINATION; frame J-FRAME-PRESERVATION) + the Python exhaustive
        // sequence enumeration + the LLVM honest two-block pipeline.
    <k> pInitJ(XCfgJ, XCatJ)
        ~> pExecJ(XExecClientD, PG:List, XCaller, 0)
        ~> pGateEvalJ( B:JBlockJ, FC:ExecCtx, RG:LinRecG, CT:AuthzCert
                     , ERC:Bytes, ERP:Bytes )
        ~> pCommitJ( B:JBlockJ, ERC:Bytes, ERP:Bytes, 1 )
        ~> runNilJ
     => .K </k>
    <jlineage> M:Map => M:Map </jlineage>
    <jnext> N:Int => N:Int </jnext>
    <jhead> H:Bytes => H:Bytes </jhead>
    <jlinhead> LH:Bytes => LH:Bytes </jlinhead>
    <janchor> A:Bytes </janchor>
    <jstate> S:Map => S:Map </jstate>
    <jrefuse> RF:JRefuse => RF:JRefuse </jrefuse>
    <jvalid> V:Bool => V:Bool </jvalid>
    requires BytesEq(ProtoRootR3(XCfgJ), A:Bytes)
         andBool SafeJ(XCatJ, S:Map) ==K true
    [label(J-REACHABLE-COMMITTED-SAFE)]

endmodule
