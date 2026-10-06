// =============================================================================
// SRW3 Phase 1F — RECORD BINDING (LinRecF)
//                          (phase1f/proofs/exec_record_binding.k)
//
// Backend: HASKELL (kprove). The additive record extension binds the
// execution identity, the trace digest, the witness digest, and the config
// digest into the commitment chain WITHOUT touching any frozen field.
// =============================================================================

requires "srw3exec.k"

module SRW3EXEC-RECBIND-PROOFS
  imports SRW3EXEC

  claim // EX5a: CanonCoreF exact form — CanonCoreE is a strict PREFIX
    // (associativity form; the 1E canonical bytes are the leading segment)
    <k> ( ExecCanonCoreF(RE:LinRecE, EID:Bytes, TD:Bytes, WD:Bytes, CD:Bytes)
          ==K AuthCanonCoreE(linRecOfE(RE:LinRecE), linStateRootOf(RE:LinRecE))
              +Bytes ( EID:Bytes
                       +Bytes ( TD:Bytes
                                +Bytes ( WD:Bytes +Bytes CD:Bytes ) ) ) )
        => true </k>
    requires true

  claim // EX5b: childE invariance under the Level-3 extension
    <k> ( linChildEOf( linRecFBase( linRecF( RE:LinRecE, _:Bytes, _:Bytes,
                                             _:Bytes, _:Bytes ) ) )
          ==K linChildEOf(RE:LinRecE) )
        => true </k>
    requires true

  claim // EX5c: childF digest form (MODEL.md §7)
    <k> ( ExecChildF(RE:LinRecE, EID:Bytes, TD:Bytes, WD:Bytes, CD:Bytes)
          ==K LinH( ExecCanonCoreF(RE:LinRecE, EID:Bytes, TD:Bytes,
                                   WD:Bytes, CD:Bytes) ) )
        => true </k>
    requires true

  claim // EX5e: witness digest binding — ExecWitDigest is exactly the canon
    // digest over the eight witness fields (definitional pin)
    <k> ( ExecWitDigest(W:ExecWit) ==K LinH(ExecWitCanon(W:ExecWit)) )
        => true </k>
    requires true

endmodule
