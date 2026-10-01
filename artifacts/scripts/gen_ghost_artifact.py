#!/usr/bin/env python3
"""
Generate proofs/induction_ghost.k — the invariant-as-data (ghost-state) encoding
for the full lineage-length safety theorem (theorem-closure pass, item 1).

Construction protocol (faithfulness by construction):
  * Lines 24..530 of k/srw3.k (modules SRW3-SYNTAX .. SRW3-CLAIMS) are copied
    BYTE-IDENTICALLY, except that proof-layer additions are inserted as lines
    marked with the sentinel `//GHOST:` (never modifying an existing line).
  * The ghost extension modules (SRW3-GHOST-OBS, SRW3-GHOST-CLAIMS) are appended.

The script then verifies the faithfulness certificate mechanically:
  * strip every //GHOST: line from the generated file;
  * the remaining lines must contain srw3.k lines 24..530 as an exact ordered
    subsequence (difflib check, no edit, no reorder).
It prints the complete ghost delta (the //GHOST: lines) as the encoding record.
"""
import difflib, sys

SRC = "/home/z/my-project/srw3-kevm/k/srw3.k"
DST = "/home/z/my-project/srw3-kevm/proofs/induction_ghost.k"

src_lines = open(SRC).read().splitlines()
# 1-indexed lines 24..530 inclusive -> python slice [23:530]
BODY = src_lines[23:530]

def insert_after(lines, anchor, additions, occurrence=1):
    """insert addition lines after the occurrence-th line equal to anchor"""
    out, seen = [], 0
    for ln in lines:
        out.append(ln)
        if ln == anchor:
            seen += 1
            if seen == occurrence:
                out.extend(additions)
    if seen < occurrence:
        sys.exit(f"FATAL: anchor not found ({occurrence}x): {anchor!r}")
    return out

# ---------------------------------------------------------------- insertions
# 1. syntax: ghost certificate + theorem program grammar (end of SRW3-SYNTAX)
BODY = insert_after(BODY,
    "  syntax Srw3Pgm ::= List{Srw3Cmd,\",\"]}".replace("\"]", ",\",\"]}") if False else '  syntax Srw3Pgm ::= List{Srw3Cmd,","}',
    [
      '  // ---- invariant-as-data certificate + theorem program grammar (theorem-closure pass) ----',
      '  // G(xa,xb)       certified values of stK(appA,0), stK(appB,0)',
      '  // GW(I,S,prev,v) pending write of v to (I,S) over certificate prev',
      '  // GateRun        chkG-terminated programs of one-write cycles; the ghost',
      '  //                function EQUATIONS live in SRW3-GHOST-OBS below',
      '  syntax Ghost ::= "G" "(" Int "," Int ")" | "GW" "(" AppId "," Int "," Ghost "," Int ")"   //GHOST:',
      '  syntax GateRun ::= "chkG" | "chkM" | "tB" "(" Int ")" ":" GateRun   //GHOST:',
      '  syntax Bool ::= "ghostSafe" "(" Ghost ")" [function, total]   //GHOST:',
      '  syntax Bool ::= "ghostMatches" "(" Ghost "," st:Map ")" [function, total]   //GHOST:',
      '  syntax Ghost ::= "ghostApply" "(" Ghost "," st:Map ")" [function, total]   //GHOST:',
      '  syntax Ghost ::= "ghostUndo" "(" Ghost ")" [function, total]   //GHOST:',
      '  syntax Set ::= "gAUTH" "(" ")" [function, total]   //GHOST:',
      '  syntax Bool ::= "safeMin" "(" st:Map ")" [function, total]   //GHOST:',
    ])

# 2. configuration: the ghost cell (inside <srw3>)
BODY = insert_after(BODY,
    '                  <result> "" </result>',
    [
      '                  <ghost> G(0, 0) </ghost>   // invariant-as-data certificate  //GHOST:',
    ])

# 3. declared-write rule: record the pending write (single tracked-key-agnostic rule)
BODY = insert_after(BODY,
    '       <footprint-d> FD:Set => FD |Set SetItem(I) </footprint-d>',
    [
      '       <ghost> Gh:Ghost => GW(I, S, Gh, V) </ghost>   // pending-write record  //GHOST:',
    ],
    occurrence=1)  # first occurrence = the w rule (rd's identical line is later)

# 4. gate ACCEPT: certificate transformer at the commitment point
BODY = insert_after(BODY,
    '       <result> _R:String => "commit" </result>',
    [
      '       <ghost> Gh:Ghost => ghostApply(Gh, P) </ghost>   // certificate apply at commit  //GHOST:',
    ])

# 5. gate REJECT (invariant): pending delta discarded, previous certificate kept
BODY = insert_after(BODY,
    '       <result> _R:String => "reject" </result>',
    [
      '       <ghost> Gh:Ghost => ghostUndo(Gh) </ghost>   // certificate undo at reject  //GHOST:',
    ])

# 6. gate REJECT (auth): same
BODY = insert_after(BODY,
    '       <result> _R:String => "reject-auth" </result>',
    [
      '       <ghost> Gh:Ghost => ghostUndo(Gh) </ghost>   // certificate undo at reject-auth  //GHOST:',
    ])

HEADER = """// =============================================================================
// proofs/induction_ghost.k — THEOREM-CLOSURE PASS, ITEM 1 (final attempt class)
//
// Invariant-as-data / ghost-state encoding of the full lineage-length safety
// theorem, per the audit instruction:
//
//   InitialSafe(P, sigma_0) /\ SecurityClosed(P)  ->  forall n. Safe(P, sigma_n)
//   equivalently  Reach_committed(P) ⊆ Safe(P)
//
// STRUCTURE (exactly the prescribed one):
//   * The baseline semantics (k/srw3.k, modules SRW3-SYNTAX..SRW3-CLAIMS) is
//     present BYTE-IDENTICALLY (mechanical certificate:
//     scripts/audit_ghost_faithful.py); the ONLY edit class is //GHOST:-marked
//     additive lines (certificate cell, pending-write record, certificate
//     transformers at the commitment point). Real-cell behavior of every rule
//     is unchanged; the real gate decisions (allHold(applicable(R,FD), P)) are
//     kept VERBATIM as the accept/reject splitting conditions.
//   * <ghost> carries the safety certificate as DATA:
//       G(xa,xb)       certified values of the two tracked keys;
//       GW(I,S,prev,v) pending declared write, recorded by the w rule,
//                      consumed at the commitment point (apply on accept,
//                      undo on reject).
//   * GhostMatches(ghost, committed) is the EXPLICIT soundness relation
//     (lookupInt equalities on the tracked keys). It is NOT assumed:
//     GH-BASE checks the base instance by evaluation; GH-A / GH-R prove
//     preservation for the accepted / rejected transition (the 4a/4b analogues
//     at the certificate layer); GH-SOUND-I/F prove that a certified-safe
//     certificate matched to the real state implies the real-state safety
//     observer safeMin (the GhostMatches -> Safe bridge).
//   * The theorem claim GH-T is a [circularity] over chkG-terminated programs
//     (sort GateRun): the observer executes ONLY on a certified-safe
//     certificate, so a claim of universal termination proves iff no
//     admissible run ever commits an unsafe state (refutation-proof form,
//     as in attempts [B]/[C]). The induction hypothesis is re-established at
//     each unrolled tail: the certificate and the committed state are re-matched
//     through the GhostMatches-shaped shared variables (X0/Y0), and the reuse
//     requires discharge is exactly the preserved safety of the previous
//     certificate.
//
// NO UNPROVED AXIOM: no rule or claim asserts ghost == committed. The only
// link is GhostMatches, and every claim about it is a proof obligation that
// kprove checks (GH-BASE/GH-A/GH-R/GH-SOUND-I/GH-SOUND-F). The certificate
// transformer (ghostApply) is justified by GH-A, not by fiat.
//
// SCOPE (documented restriction, same scope as Claims 4a/4b and attempt [C]):
//   the minimal model universe minInvs() = {IA,IB,IAB,IC} over the two-key
//   shape {stK(appA,0), stK(appB,0)}, completeRegistry(), policy enforce,
//   actor appB, one declared write per cycle (tB). The certificate tracks the
//   two keys of that universe; writes to other keys are carried transparently
//   (GW) and provably leave GhostMatches unaffected. `init` (a direct
//   committed-state write outside the theorem's program class) is copied
//   verbatim but is outside the GH-A/GH-R preservation scope.
//
// OUTCOME: recorded verbatim in transcripts/audit/ghost_theorem.txt and
// analyzed in report section R.
// =============================================================================

"""

NEW_MODULES = r"""
// =============================================================================
// GHOST EXTENSION MODULES — everything below is NEW (theorem-closure pass).
// The ghost FUNCTION SYNTAX is declared in SRW3-SYNTAX above (visible to the
// copied gate rules); this module holds their defining EQUATIONS.
// =============================================================================

module SRW3-GHOST-OBS
  imports SRW3-GATE

  // ---- certified safety = the model's obligation universe evaluated on the
  //      certified values (the SAME evaluated obligations as the real gate;
  //      IC vacuous on the two-key shape — SF0 of the safe-form audit) --------
  rule ghostSafe(G(XA:Int, XB:Int))
    => allHold(minInvs(), stK(appA, 0) |-> XA stK(appB, 0) |-> XB)
  rule ghostSafe(GW(_I:AppId, _S:Int, Prev:Ghost, _V:Int)) => ghostSafe(Prev)

  // ---- GhostMatches: the explicit soundness relation ------------------------
  rule ghostMatches(G(XA:Int, XB:Int), M:Map)
    => lookupInt(M, stK(appA, 0)) ==Int XA
       andBool lookupInt(M, stK(appB, 0)) ==Int XB
  rule ghostMatches(GW(_I:AppId, _S:Int, Prev:Ghost, _V:Int), M:Map)
    => ghostMatches(Prev, M)

  // ---- certificate transformer at the commitment point ----------------------
  // tracked write  -> certified value updated;  untracked / none -> unchanged.
  rule ghostApply(GW(appB, 0, G(XA:Int, _XB:Int), V:Int), _P:Map) => G(XA, V)
  rule ghostApply(GW(appA, 0, G(_XA2:Int, XB:Int), V:Int), _P2:Map) => G(V, XB)
  rule ghostApply(Gh:Ghost, _P3:Map) => Gh [owise]

  rule ghostUndo(GW(_I2:AppId, _S2:Int, Gh:Ghost, _V2:Int)) => Gh
  rule ghostUndo(Gh2:Ghost) => Gh2 [owise]

  // ---- concrete authority set for the theorem instances ---------------------
  rule gAUTH() => SetItem(appA) |Set SetItem(appB) |Set SetItem(appC)

  // ---- one full admissible transition cycle (proof-layer command) -----------
  rule <k> tB(V:Int) : PG:GateRun
        => begin ~> w(appB, 0, V) ~> wfCheck ~> gate ~> PG ... </k>

  // ---- safety observer: executable ONLY on a certified-safe certificate -----
  rule <k> chkG => .K ... </k>
       <ghost> Gh:Ghost </ghost>
    requires ghostSafe(Gh)

  // ---- matching observer: executable ONLY if the certificate BOTH matches
  //      the real committed state (GhostMatches) AND is certified-safe. This
  //      is the refutation-proof observer for the preservation claims (GH-A /
  //      GH-R: a defective certificate transformer would desynchronize the
  //      certificate, chkM would stick, and the claim would FAIL) and for the
  //      strongest theorem form (GH-M: the soundness relation is re-checked at
  //      every program termination).
  rule <k> chkM => .K ... </k>
       <ghost> Gh:Ghost </ghost>
       <committed> M:Map </committed>
    requires ghostMatches(Gh, M) andBool ghostSafe(Gh)

  // ---- trusted simplification lemmas (verbatim from proofs/induction_full.k)
  rule lookupInt(M:Map [KEY:StKey <- V:Int], KEY:StKey) => V [simplification]
  rule lookupInt(M:Map [KEY:StKey <- V:Int], K2:StKey) => lookupInt(M, K2)
    requires K2 =/=K KEY [simplification]

  // ---- real-state safety observer (verbatim from proofs/induction_full.k) ---
  rule safeMin(M2:Map)
    => lookupInt(M2, stK(appA, 0)) <=Int 10
       andBool lookupInt(M2, stK(appB, 0)) <=Int 10
       andBool lookupInt(M2, stK(appA, 0)) +Int lookupInt(M2, stK(appB, 0)) <=Int 10
endmodule

// =============================================================================
// Claims: the GhostMatches obligation set + the full theorem.
//
// KORE DESTINATION NOTE (discovered in this pass, consistent with the [C]
// residuals of the record attempt): a claim whose destination mentions ONLY
// <k> .K fails the implication check with a stuck residual, while the SAME
// claim with explicit existential (?-prefixed) destination cells over ALL
// cells closes. GH-T (minimal destination) is retained as the documented
// probe; the theorem forms use the explicit-existential destinations.
// =============================================================================

module SRW3-GHOST-CLAIMS
  imports SRW3-GHOST-OBS

  claim // GH-BASE: the soundness relation HOLDS BY EVALUATION at the theorem's
        // initial shape (the certificate base case; no axiom)
    <k> ghostMatches(G(X0:Int, Y0:Int),
                     stK(appA, 0) |-> X0:Int stK(appB, 0) |-> Y0:Int) => true </k>
    [label(GH-BASE)]

  claim // GH-A: ACCEPT preservation (the 4a-analogue at the certificate layer):
        // after an accepted transition the certificate matches the committed
        // state AND is safe — checked dynamically by the chkM observer (a
        // defective certificate transformer would make chkM stick)
    <k> ( tB(V:Int) : chkM ) => .K </k>
    <committed> stK(appA, 0) |-> X0:Int stK(appB, 0) |-> Y0:Int => ?C2:Map </committed>
    <prospective> P2:Map => ?P3:Map </prospective>
    <footprint-t> F1:Set => ?F2:Set </footprint-t>
    <footprint-d> F3:Set => ?F4:Set </footprint-d>
    <ghost> G(X0:Int, Y0:Int) => ?Gh2:Ghost </ghost>
    <registry> completeRegistry() </registry>
    <policy> enforce </policy>
    <actor> appB </actor>
    <authorities> gAUTH() </authorities>
    <polver> PV1:Int => ?PV2:Int </polver>
    <lineage> LN1:Map => ?LN2:Map </lineage>
    <lineageNext> N1:Int => ?N2:Int </lineageNext>
    <head> CH1:Commitment => ?CH2:Commitment </head>
    <result> R1:String => ?R2:String </result>
    requires X0 <=Int 10 andBool Y0 <=Int 10 andBool X0 +Int Y0 <=Int 10
             andBool V <=Int 10 andBool X0 +Int V <=Int 10
    [label(GH-A)]

  claim // GH-R: REJECT preservation (the 4b-analogue): the PREVIOUS matching
        // relation is preserved (committed state and certificate unchanged)
    <k> ( tB(V:Int) : chkM ) => .K </k>
    <committed> stK(appA, 0) |-> X0:Int stK(appB, 0) |-> Y0:Int => ?C2:Map </committed>
    <prospective> P2:Map => ?P3:Map </prospective>
    <footprint-t> F1:Set => ?F2:Set </footprint-t>
    <footprint-d> F3:Set => ?F4:Set </footprint-d>
    <ghost> G(X0:Int, Y0:Int) => ?Gh2:Ghost </ghost>
    <registry> completeRegistry() </registry>
    <policy> enforce </policy>
    <actor> appB </actor>
    <authorities> gAUTH() </authorities>
    <polver> PV1:Int => ?PV2:Int </polver>
    <lineage> LN1:Map => ?LN2:Map </lineage>
    <lineageNext> N1:Int => ?N2:Int </lineageNext>
    <head> CH1:Commitment => ?CH2:Commitment </head>
    <result> R1:String => ?R2:String </result>
    requires X0 <=Int 10 andBool Y0 <=Int 10 andBool X0 +Int Y0 <=Int 10
             andBool notBool ( V <=Int 10 andBool X0 +Int V <=Int 10 )
    [label(GH-R)]

  claim // GH-SOUND-I: a certified-safe certificate, matched to the real state,
        // implies the REAL-state safety observer safeMin (residual-sharing
        // form: the stuck lookupInt terms are shared between goal and premise)
    <k> ( lookupInt(M:Map, stK(appA, 0)) <=Int 10
          andBool lookupInt(M, stK(appB, 0)) <=Int 10
          andBool lookupInt(M, stK(appA, 0)) +Int lookupInt(M, stK(appB, 0)) <=Int 10 )
        => true </k>
    requires lookupInt(M, stK(appA, 0)) ==Int XA:Int
             andBool lookupInt(M, stK(appB, 0)) ==Int XB:Int
             andBool ghostSafe(G(XA, XB))
    [label(GH-SOUND-I)]

  claim // GH-SOUND-F: the same bridge stated via the NAMED relation (the
        // definitional form of GH-SOUND-I; ghostMatches/ghostSafe unfold to
        // exactly the GH-SOUND-I premise)
    <k> safeMin(M:Map) => true </k>
    requires ghostMatches(G(XA:Int, XB:Int), M) andBool ghostSafe(G(XA, XB))
    [label(GH-SOUND-F)]

  claim // GATE-AGREE: the certificate-predicted accept condition == the REAL
        // gate's evaluated applicable-obligation conjunction on the
        // prospective state (SF2-shape of the safe-form audit, prospective form)
    <k> allHold(applicable(completeRegistry(), SetItem(appB)),
                stK(appA, 0) |-> XA:Int stK(appB, 0) |-> XB:Int [stK(appB, 0) <- V:Int])
        ==Bool ( V <=Int 10 andBool XA +Int V <=Int 10 ) => true </k>
    [label(GATE-AGREE)]

  claim // GH-ISO: one full cycle + observer, NON-circular (diagnostic; the
        // C-ISO isolate of the record attempt, at the ghost layer). Covers BOTH
        // gate branches (accept and reject) and the observer firing.
    <k> ( tB(V:Int) : chkG ) => .K </k>
    <committed> stK(appA, 0) |-> X0:Int stK(appB, 0) |-> Y0:Int => ?C2:Map </committed>
    <prospective> P2:Map => ?P3:Map </prospective>
    <footprint-t> F1:Set => ?F2:Set </footprint-t>
    <footprint-d> F3:Set => ?F4:Set </footprint-d>
    <ghost> G(X0:Int, Y0:Int) => ?Gh2:Ghost </ghost>
    <registry> completeRegistry() </registry>
    <policy> enforce </policy>
    <actor> appB </actor>
    <authorities> gAUTH() </authorities>
    <polver> PV1:Int => ?PV2:Int </polver>
    <lineage> LN1:Map => ?LN2:Map </lineage>
    <lineageNext> N1:Int => ?N2:Int </lineageNext>
    <head> CH1:Commitment => ?CH2:Commitment </head>
    <result> R1:String => ?R2:String </result>
    requires X0 <=Int 10 andBool Y0 <=Int 10 andBool X0 +Int Y0 <=Int 10
    [label(GH-ISO)]

  claim // GH-T1: TWO cycles + observer, NON-circular (bounded-depth probe:
        // separates per-step machinery + tail carrying from the reuse mechanism)
    <k> ( tB(V1:Int) : (tB(V2:Int) : chkG) ) => .K </k>
    <committed> stK(appA, 0) |-> X0:Int stK(appB, 0) |-> Y0:Int => ?C2:Map </committed>
    <prospective> P2:Map => ?P3:Map </prospective>
    <footprint-t> F1:Set => ?F2:Set </footprint-t>
    <footprint-d> F3:Set => ?F4:Set </footprint-d>
    <ghost> G(X0:Int, Y0:Int) => ?Gh2:Ghost </ghost>
    <registry> completeRegistry() </registry>
    <policy> enforce </policy>
    <actor> appB </actor>
    <authorities> gAUTH() </authorities>
    <polver> PV1:Int => ?PV2:Int </polver>
    <lineage> LN1:Map => ?LN2:Map </lineage>
    <lineageNext> N1:Int => ?N2:Int </lineageNext>
    <head> CH1:Commitment => ?CH2:Commitment </head>
    <result> R1:String => ?R2:String </result>
    requires X0 <=Int 10 andBool Y0 <=Int 10 andBool X0 +Int Y0 <=Int 10
    [label(GH-T1)]

  claim // GH-T (minimal-destination probe): the SAME theorem as GH-T2 but with
        // a destination mentioning only <k> .K. EXPECTED STUCK per the kore
        // destination behavior documented above (same residual class as the
        // [C] record attempt). Retained as the diagnostic; do not weaken.
    <k> ( tB(V1:Int) : PG:GateRun ) => .K </k>
    <committed> stK(appA, 0) |-> X0:Int stK(appB, 0) |-> Y0:Int </committed>
    <ghost> G(X0:Int, Y0:Int) </ghost>
    <registry> completeRegistry() </registry>
    <policy> enforce </policy>
    <actor> appB </actor>
    <authorities> gAUTH() </authorities>
    requires X0 <=Int 10 andBool Y0 <=Int 10 andBool X0 +Int Y0 <=Int 10
             andBool securityClosedUniv(completeRegistry(), enforce, minInvs())
    [circularity, label(GH-T)]

  claim // GH-T2: THE FULL LINEAGE-LENGTH SAFETY THEOREM (circularity).
        //   InitialSafe(P, sigma_0) /\ SecurityClosed(P) -> forall n. Safe(P, sigma_n)
        // InitialSafe(P, sigma_0) is the evaluated requires; SecurityClosed(P)
        // is the evaluated securityClosedUniv premise. The observer chkG
        // executes only on a certified-safe certificate, so universal
        // termination of admissible chkG-terminated programs proves iff no
        // admissible run ever commits an unsafe state (refutation-proof form).
        // The shared variables X0/Y0 between <committed> and <ghost> bake the
        // GhostMatches shape into the induction; its preservation is GH-A/GH-R;
        // the certificate-to-real-state bridge is GH-SOUND-I/F. Existential
        // destinations over all cells (see the kore destination note).
    <k> ( tB(V1:Int) : PG:GateRun ) => .K </k>
    <committed> stK(appA, 0) |-> X0:Int stK(appB, 0) |-> Y0:Int => ?C2:Map </committed>
    <prospective> P2:Map => ?P3:Map </prospective>
    <footprint-t> F1:Set => ?F2:Set </footprint-t>
    <footprint-d> F3:Set => ?F4:Set </footprint-d>
    <ghost> G(X0:Int, Y0:Int) => ?Gh2:Ghost </ghost>
    <registry> completeRegistry() </registry>
    <policy> enforce </policy>
    <actor> appB </actor>
    <authorities> gAUTH() </authorities>
    <polver> PV1:Int => ?PV2:Int </polver>
    <lineage> LN1:Map => ?LN2:Map </lineage>
    <lineageNext> N1:Int => ?N2:Int </lineageNext>
    <head> CH1:Commitment => ?CH2:Commitment </head>
    <result> R1:String => ?R2:String </result>
    requires X0 <=Int 10 andBool Y0 <=Int 10 andBool X0 +Int Y0 <=Int 10
             andBool securityClosedUniv(completeRegistry(), enforce, minInvs())
    [circularity, label(GH-T2)]

  claim // GH-M: the STRONGEST form — the same forall-n theorem with the
        // GhostMatches soundness relation RE-CHECKED at every termination
        // (chkM observer): every admissible chkM-terminated run terminates,
        // i.e. the committed lineage states remain certified-safe AND matched
        // to their certificates for all n.
    <k> ( tB(V1:Int) : PG:GateRun ) => .K </k>
    <committed> stK(appA, 0) |-> X0:Int stK(appB, 0) |-> Y0:Int => ?C2:Map </committed>
    <prospective> P2:Map => ?P3:Map </prospective>
    <footprint-t> F1:Set => ?F2:Set </footprint-t>
    <footprint-d> F3:Set => ?F4:Set </footprint-d>
    <ghost> G(X0:Int, Y0:Int) => ?Gh2:Ghost </ghost>
    <registry> completeRegistry() </registry>
    <policy> enforce </policy>
    <actor> appB </actor>
    <authorities> gAUTH() </authorities>
    <polver> PV1:Int => ?PV2:Int </polver>
    <lineage> LN1:Map => ?LN2:Map </lineage>
    <lineageNext> N1:Int => ?N2:Int </lineageNext>
    <head> CH1:Commitment => ?CH2:Commitment </head>
    <result> R1:String => ?R2:String </result>
    requires X0 <=Int 10 andBool Y0 <=Int 10 andBool X0 +Int Y0 <=Int 10
             andBool securityClosedUniv(completeRegistry(), enforce, minInvs())
    [circularity, label(GH-M)]

  claim // GH-T2-NEG (non-vacuity control): GH-T2 with the InitialSafe premise
        // dropped MUST FAIL (an initially-unsafe certified value sticks at the
        // observer; kprove must reject the under-premised theorem).
    <k> ( tB(V1:Int) : PG:GateRun ) => .K </k>
    <committed> stK(appA, 0) |-> X0:Int stK(appB, 0) |-> Y0:Int => ?C2:Map </committed>
    <prospective> P2:Map => ?P3:Map </prospective>
    <footprint-t> F1:Set => ?F2:Set </footprint-t>
    <footprint-d> F3:Set => ?F4:Set </footprint-d>
    <ghost> G(X0:Int, Y0:Int) => ?Gh2:Ghost </ghost>
    <registry> completeRegistry() </registry>
    <policy> enforce </policy>
    <actor> appB </actor>
    <authorities> gAUTH() </authorities>
    <polver> PV1:Int => ?PV2:Int </polver>
    <lineage> LN1:Map => ?LN2:Map </lineage>
    <lineageNext> N1:Int => ?N2:Int </lineageNext>
    <head> CH1:Commitment => ?CH2:Commitment </head>
    <result> R1:String => ?R2:String </result>
    requires securityClosedUniv(completeRegistry(), enforce, minInvs())
    [circularity, label(GH-T2-NEG)]
endmodule"""

gen = HEADER + "\n".join(BODY) + "\n" + NEW_MODULES
open(DST, "w").write(gen)
print(f"written: {DST} ({len(gen.splitlines())} lines)")

# ------------------------------------------------------------- faithfulness
gen_lines = gen.splitlines()
kept = [ln for ln in gen_lines if "//GHOST:" not in ln]
ghost_delta = [ln for ln in gen_lines if "//GHOST:" in ln]

body_src = src_lines[23:530]  # lines 24..530, 1-indexed
sm = difflib.SequenceMatcher(a=body_src, b=kept, autojunk=False)
blocks = [b for b in sm.get_matching_blocks() if b.size > 0]
matched = sum(b.size for b in blocks)
# verify the source body is fully consumed IN ORDER
consumed = []
for b in blocks:
    consumed.extend(body_src[b.a:b.a + b.size])
ok = consumed == body_src
print(f"faithfulness: {matched}/{len(body_src)} source lines matched in order: {'PASS' if ok else 'FAIL'}")
if not ok:
    # show first divergence for debugging
    for i, (x, y) in enumerate(zip(consumed, body_src)):
        if x != y:
            print(f"first divergence at source-relative line {i+1}:")
            print(f"  consumed: {x!r}")
            print(f"  source  : {y!r}")
            break
    sys.exit(1)

print("\n--- complete ghost delta (the ONLY edits to the copied semantics) ---")
for ln in ghost_delta:
    print(ln)
print(f"--- {len(ghost_delta)} //GHOST: lines; all other copied lines byte-identical ---")
