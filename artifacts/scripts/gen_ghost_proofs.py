#!/usr/bin/env python3
"""SRW3 Phase 1B — generate the three self-contained ghost proof files from
k/srw3gen.k (Phase-1A discipline: the semantics portion is byte-identical to
the demo semantics except for //GHOST:-marked additive lines).

Outputs:
  proofs/gen/cm2_alias.k   (CM2 alias model: GH2-* claims, program class tK2/tK1)
  proofs/gen/cm3_auth.k    (CM3 authority model: GH3-* claims, program class tC/tD)
  proofs/gen/gen_full.k    (generalized multi-write model: GH4-* claims, class tG)
  proofs/gen/ghost_manifest_gen.json  (fidelity manifest for the audit)

The audit script (audit_ghost_gen.py) independently re-verifies:
  strip(//GHOST: lines) applied to proof file == srw3gen.k bytes.
"""
import json, os, hashlib

BASE = "/home/z/my-project/srw3-kevm"
SEM = os.path.join(BASE, "k/srw3gen.k")
OUTDIR = os.path.join(BASE, "proofs/gen")
os.makedirs(OUTDIR, exist_ok=True)

sem = open(SEM).read()

# ---- insertion anchors (must occur exactly once each) -----------------------
A_RESULT = '<result> "" </result>'
A_W = "       <footprint-d> FD:Set => FD |Set SetItem(stK(I, S)) </footprint-d>\n"
A_CONS = "       <footprint-d> FD:Set => FD |Set SetItem(A) </footprint-d>\n"
A_COMMIT = '       <result> _R:String => "commit" </result>\n'
A_REJECT = '       <result> _R:String => "reject" </result>\n'
A_REJECT_AUTH = '       <result> _R:String => "reject-auth" </result>\n'

for a in (A_RESULT, A_W, A_CONS, A_COMMIT, A_REJECT, A_REJECT_AUTH):
    assert sem.count(a) == 1, f"anchor not unique: {a!r} count={sem.count(a)}"

SPECS = {
    "cm2_alias": dict(
        prefix="SRW3G2", ghostsort="Ghost2", ghostcell="G2(0, 0)",
        w_hook="       <ghost> Gh:Ghost2 => GW2(I, S, Gh, V) </ghost>   //GHOST:\n",
        cons_hook=None,  # cm2 model does not exercise authority effects
        apply="ghostApply2(Gh, P)", undo="ghostUndo2(Gh)",
        frag="cm2_frag.k",
    ),
    "cm3_auth": dict(
        prefix="SRW3G3", ghostsort="Ghost3", ghostcell="U2(0, 0)",
        w_hook=None,  # usage certificate is unaffected by storage writes
        cons_hook="       <ghost> Gh:Ghost3 => GWU(A, N, Gh) </ghost>   //GHOST:\n",
        apply="ghostApply3(Gh, UP)", undo="ghostUndo3(Gh)",
        frag="cm3_frag.k",
    ),
    "gen_full": dict(
        prefix="SRW3G4", ghostsort="Ghost4", ghostcell="GG(0, 0, 0, 0, 0, 0)",
        w_hook="       <ghost> Gh:Ghost4 => gW4(Gh, I, S, V) </ghost>   //GHOST:\n",
        cons_hook="       <ghost> Gh:Ghost4 => gC4(Gh, A, N) </ghost>   //GHOST:\n",
        apply="ghostApply4(Gh, P)", undo="ghostUndo4(Gh)",
        frag="gen_frag.k",
    ),
}

manifest = []
for name, sp in SPECS.items():
    txt = sem
    ins = []
    # ghost syntax insert: inside SRW3G-SYNTAX, before its endmodule (the
    # configuration parser in SRW3G-STATE must see the ghost constructors)
    frag_raw = open(os.path.join("/home/z/my-project/scripts/gen_fragments", sp["frag"])).read()
    frag_syntax, _m, frag_modules = frag_raw.partition("####MODULES####")
    frag_syntax = frag_syntax.replace("####SYNTAX-INSERT####\n", "")
    SYN_ANCHOR = '  syntax Srw3PgmG ::= List{Srw3CmdG,","}\nendmodule'
    assert txt.count(SYN_ANCHOR) == 1
    txt = txt.replace(SYN_ANCHOR,
                      '  syntax Srw3PgmG ::= List{Srw3CmdG,","}\n\n' + frag_syntax + 'endmodule', 1)
    ins.append("ghost-syntax-insert")
    # config ghost cell
    ghost_cell_line = f"                  <ghost> {sp['ghostcell']} </ghost>   //GHOST:\n"
    txt = txt.replace(A_RESULT + "\n", A_RESULT + "\n" + ghost_cell_line, 1)
    ins.append("config-ghost-cell")
    # w hook
    if sp["w_hook"]:
        assert txt.count(A_W) == 1
        txt = txt.replace(A_W, A_W + sp["w_hook"], 1)
        ins.append("w-ghost-hook")
    # consume hook
    if sp["cons_hook"]:
        assert txt.count(A_CONS) == 1
        txt = txt.replace(A_CONS, A_CONS + sp["cons_hook"], 1)
        ins.append("consume-ghost-hook")
    # gate hooks
    txt = txt.replace(A_COMMIT, A_COMMIT + f"       <ghost> Gh:{sp['ghostsort']} => {sp['apply']} </ghost>   //GHOST:\n", 1)
    ins.append("gate-accept-hook")
    txt = txt.replace(A_REJECT, A_REJECT + f"       <ghost> Gh:{sp['ghostsort']} => {sp['undo']} </ghost>   //GHOST:\n", 1)
    ins.append("gate-reject-hook")
    txt = txt.replace(A_REJECT_AUTH, A_REJECT_AUTH + f"       <ghost> Gh:{sp['ghostsort']} => {sp['undo']} </ghost>   //GHOST:\n", 1)
    ins.append("gate-reject-auth-hook")
    # appended ghost modules
    txt = txt + frag_modules
    out = os.path.join(OUTDIR, f"{name}.k")
    open(out, "w").write(txt)
    manifest.append(dict(
        file=f"proofs/gen/{name}.k",
        base="k/srw3gen.k",
        base_sha256=hashlib.sha256(sem.encode()).hexdigest(),
        file_sha256=hashlib.sha256(txt.encode()).hexdigest(),
        marked_insertions=ins,
        fragment=sp["frag"],
    ))
    print(f"wrote {out} ({txt.count(chr(10))} lines, insertions: {ins})")

mpath = os.path.join(OUTDIR, "ghost_manifest_gen.json")
open(mpath, "w").write(json.dumps(manifest, indent=2) + "\n")
print(f"wrote {mpath}")
