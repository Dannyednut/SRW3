;; SRW3 Phase 1H — client-boundary claim specification (section 28/29).
;;
;; STATUS: SPECIFICATION MODULE (not compiled in this environment — no K
;; toolchain; disclosed).  The K machinery this module REFERENCES is frozen
;; and PROVED in phases 1D-R1/1E/1F/1G (k/, phase1e/, phase1f/, phase1g/):
;; Gate_G with its 21-conjunct accept, VerifyLineageG, AuthorityCertificate
;; rules (NoCircularAuthority), and the 28 kprove claims of Phase 1G.
;;
;; Phase 1H adds the CLIENT-BOUNDARY sorts and states the theorem targets
;; H1..H10 of the phase specification.  Each claim's realized status is
;; classified in formal/THEOREM-CLASSIFICATION.md; claims that reduce to
;; the frozen Gate_G/VerifyLineageG machinery inherit that status, claims
;; about the REAL client are classified by the executed experiment.

requires "srw3authz.k"   [ frozen phase1g ]

module SRW3-GATE-H-CLAIMS
  imports SRW3-AUTHZ [ frozen ]

  // ------------------------------------------------------------
  // Client-boundary sorts (Phase 1H)
  // ------------------------------------------------------------

  // The client boundary evidence record = ClientExecutionEvidence of the
  // adapter, carrying the bindings of section 8:
  //   payloadDigest, parentRoot, executionIdentity, effectDigest,
  //   childStateRoot, executionConfiguration.

  // Ethereum payload validity (client-internal notion) is DISTINCT from
  // the SRW3 gate (section 29):
  //   EthereumValid(payload)  = client's InsertBlockWithoutSetHead verdict
  //   SRW3Gate(rec, ctx)      = frozen Gate_G over the evidence record

  // ------------------------------------------------------------
  // H1 — client-execution binding
  //   The effect digest binds the CLIENT-DERIVED trace: presented == executed.
  // Reduces at the client boundary to the frozen 1F LEVEL-3 CORE check
  // (declared == Writes(trace)) applied to client-derived records.
  claim H1:
    ClientExecutes(payload) 
    -> EffectDigest(DerivedTrace) =# EffectDigest(ClientExecutionEvidence)

  // H2 — deterministic SRW3 evaluation: same payload/context -> same verdict
  // (measured across instances and replay; see transcripts/srw3/determinism.json)

  // H3 — state/effect evidence binding: stateRoot binding (section 9)
  // reduces to the frozen 1E AUTH-READ/AUTH-UPDATE machinery over the
  // client's native commitment (adapter, not replacement).

  // H4 — authority-source preservation: NoCircularAuthority (frozen 1G)
  // holds with the client certificate chain substituted for the modeled one.

  // H5 — policy-context binding: SecurityContext_H fields enter the verdict
  // (frozen 1G authbind/policy layers).

  // H6 — shadow-mode safety: the shadow gate cannot change Ethereum validity
  // (architecture: the gate runs post-execution, pre-forkchoice; in shadow
  // mode canonicalization is unconditional).

  // H7 — reorg/lineage consistency: SRW3 lineage follows forkchoice; per-branch
  // records persist (demonstrated; transcripts/adversarial/adversarial_H.json H-A6/A16).

  // H8 — failure non-bypassability: SRW3_ERROR != SRW3_VALID (fail-closed in
  // enforcing mode; distinct verdict class in shadow mode).

  // H9 — consensus-boundary characterization: SPECIFICATION THEOREM (report
  // section 16): making SRW3 rejection consensus-visible requires a protocol
  // rule fixing the seven listed questions; demonstrated insufficient-in-
  // client by the consensus-visible simulation.

  // H10 — client-to-SRW3 commitment correspondence: the client's post-state
  // root (validated in-process against the re-derived state) is the anchor
  // the SRW3 state-root binding consumes; correspondence demonstrated by
  // byte-identical evidence across instances/replay.

endmodule
