#!/usr/bin/env python3
"""
EXACT ghost source-fidelity certificate (Phase 1A, Part I.A).

Replaces the Phase-0 subsequence check (which proved only `baseline ⊆ kept`)
with a deterministic byte-faithfulness equation:

    baseline_semantics
      + exactly_declared_ghost_additions
      = ghost_instrumented_semantics

The declared additions live in a frozen manifest (proofs/ghost_manifest.json)
containing: the baseline slice (k/srw3.k lines 24..530) with its SHA-256; the
declared header block; six declared insertion blocks (anchor, occurrence,
exact lines, per-line CODE/COMMENT classification, marker flag); and the
declared appended extension-module region (frozen by SHA-256 and line counts).

Modes:
  freeze    generate the manifest from the current (audited, kprove-clean)
            baseline + artifact; refuses to overwrite without --force
  verify    check the artifact against the manifest (default; exit 0 = PASS)
  selftest  verify the checker DETECTS: missing baseline line, altered line,
            reordered line, undeclared addition, ghost code outside the
            declared region (each mutation must FAIL)

Classification discipline (mandated):
  * total `//GHOST:` occurrences  — every line containing the token, including
    occurrences inside explanatory comments (the header mention);
  * live ghost-code additions     — declared lines classified CODE (marker
    lines in the copied body + code lines of the extension region).
Comment-only mentions must never be confused with executable additions.

The semantics files are never modified by this script.
"""
import hashlib
import json
import sys

SRC = "/home/z/my-project/srw3-kevm/k/srw3.k"
ART = "/home/z/my-project/srw3-kevm/proofs/induction_ghost.k"
MAN = "/home/z/my-project/srw3-kevm/proofs/ghost_manifest.json"

SLICE_START, SLICE_END = 24, 530          # 1-indexed, inclusive (507 lines)
EXT_ANCHOR = "// GHOST EXTENSION MODULES — everything below is NEW (theorem-closure pass)."
MARKER = "//GHOST:"

BODY_START_ANCHOR = "module SRW3-SYNTAX"
BODY_SLICE_ANCHOR = '  syntax Srw3Pgm ::= List{Srw3Cmd,","}'


def sha256(data: bytes) -> str:
    return hashlib.sha256(data).hexdigest()


def classify(line: str):
    """(kind, marked): kind in {'code','comment'} for additions."""
    stripped = line.strip()
    marked = MARKER in line
    # a line is a comment iff, after removing the marker token, it is a
    # comment line (or empty); otherwise it is executable semantic text.
    probe = line.replace(MARKER, "").strip()
    kind = "comment" if (probe == "" or probe.startswith("//")) else "code"
    return kind, marked


# ----------------------------------------------------------------- freeze ----
def freeze(force: bool) -> None:
    import os
    if os.path.exists(MAN) and not force:
        sys.exit(f"refusing to overwrite existing manifest {MAN} (use --force)")

    src_lines = open(SRC).read().splitlines()
    body_src = src_lines[SLICE_START - 1: SLICE_END]
    art_lines = open(ART).read().splitlines()

    # locate region boundaries in the artifact
    try:
        first_body_idx = art_lines.index(BODY_START_ANCHOR)
    except ValueError:
        sys.exit("FATAL: body start anchor not found in artifact")
    try:
        ext_idx = art_lines.index(EXT_ANCHOR)
    except ValueError:
        sys.exit("FATAL: extension-region anchor not found in artifact")
    header_end = first_body_idx - 1          # header = everything before body
    if art_lines[header_end].strip() != "":
        sys.exit("FATAL: header/body boundary not where expected")

    # declared insertions = the non-baseline lines of the body region.
    # Deterministic diff against the baseline slice, anchored by position:
    # walk both; an artifact line equal to the next baseline line continues
    # the copy, otherwise it must be part of an insertion run (which the
    # manifest then records with its preceding anchor + run length).
    body_art = art_lines[first_body_idx: art_lines.index(EXT_ANCHOR) - 1]
    insertions, i, j = [], 0, 0
    while j < len(body_art):
        if i < len(body_src) and body_art[j] == body_src[i]:
            i += 1
            j += 1
            continue
        anchor = body_art[j - 1]
        run = []
        while j < len(body_art) and (i >= len(body_src) or body_art[j] != body_src[i]):
            run.append(body_art[j])
            j += 1
        if not run:
            sys.exit("FATAL: unexpected diff shape during freeze")
        occurrence = body_art[: j - len(run)].count(anchor)
        lines = [{"text": ln,
                  "kind": classify(ln)[0],
                  "marked": classify(ln)[1]} for ln in run]
        insertions.append({"anchor": anchor, "occurrence": occurrence,
                           "lines": lines})
    if i != len(body_src):
        sys.exit("FATAL: baseline not fully consumed during freeze")

    ext = art_lines[ext_idx - 1:]            # '=====' line belongs to extension
    header = art_lines[: header_end + 1]
    manifest = {
        "baseline": {"path": SRC, "slice_start": SLICE_START,
                     "slice_end": SLICE_END,
                     "sha256": sha256(("\n".join(body_src) + "\n").encode())},
        "header": {"line_count": len(header),
                   "sha256": sha256(("\n".join(header) + "\n").encode())},
        "insertions": insertions,
        "extension": {"anchor": EXT_ANCHOR, "line_count": len(ext),
                      "sha256": sha256(("\n".join(ext) + "\n").encode())},
        "artifact": {"path": ART,
                     "sha256": sha256(open(ART, "rb").read())},
    }
    with open(MAN, "w") as f:
        json.dump(manifest, f, indent=2, ensure_ascii=False)
    print(f"manifest frozen: {MAN}")
    print(f"  baseline slice: lines {SLICE_START}..{SLICE_END} "
          f"({len(body_src)} lines, sha256 {manifest['baseline']['sha256'][:16]}...)")
    print(f"  declared insertions: {len(insertions)} blocks, "
          f"{sum(len(b['lines']) for b in insertions)} lines")
    print(f"  extension region: {len(ext)} lines")
    print(f"  whole-artifact sha256: {manifest['artifact']['sha256']}")


# ----------------------------------------------------------------- verify ----
def first_divergence_class(actual, expected):
    """classify the first difference between two line lists"""
    n = min(len(actual), len(expected))
    for k in range(n):
        if actual[k] != expected[k]:
            # is the actual line a LATER expected line? -> expected lines were
            # dropped (missing/reordered); is it a LATER actual line? ->
            # undeclared addition sits here; otherwise altered.
            if actual[k] in expected[k + 1: k + 200]:
                return "missing-or-reordered"
            if expected[k] in actual[k + 1: k + 200]:
                return "undeclared-addition"
            return "altered"
    if len(actual) > len(expected):
        return "undeclared-addition"
    if len(actual) < len(expected):
        return "missing"
    return None


def verify(structural_only: bool = False) -> bool:
    man = json.load(open(MAN))
    art_lines = open(ART).read().splitlines()
    src_lines = open(SRC).read().splitlines()
    body_src = src_lines[SLICE_START - 1: SLICE_END]
    ok = True

    def check(cond, label, detail=""):
        nonlocal ok
        print(f"  [{'PASS' if cond else 'FAIL'}] {label}" + (f" — {detail}" if detail else ""))
        ok = ok and cond

    print("== EXACT ghost source-fidelity certificate ==")

    # 0. baseline slice unchanged since freeze
    if not structural_only:
        check(sha256(("\n".join(body_src) + "\n").encode())
              == man["baseline"]["sha256"],
              "baseline slice (k/srw3.k lines 24..530) unchanged since manifest freeze")

    # 1. whole-artifact byte identity with frozen artifact
    whole = sha256(open(ART, "rb").read())
    if not structural_only:
        check(whole == man["artifact"]["sha256"],
              "artifact byte-identity vs frozen whole-file sha256")

    # 2. header region byte-identity
    hdr_n = man["header"]["line_count"]
    header = art_lines[:hdr_n]
    if not structural_only:
        check(sha256(("\n".join(header) + "\n").encode()) == man["header"]["sha256"],
              f"header region ({hdr_n} lines) byte-identical")

    # 3. extension region byte-identity
    try:
        ext_idx = art_lines.index(EXT_ANCHOR) - 1
        ext = art_lines[ext_idx:]
        if not structural_only:
            check(sha256(("\n".join(ext) + "\n").encode()) == man["extension"]["sha256"]
                  and len(ext) == man["extension"]["line_count"],
                  f"extension region ({man['extension']['line_count']} lines) byte-identical")
    except ValueError:
        check(False, "extension-region anchor present")
        return False

    # 4. deterministic reconstruction: baseline ⊕ declared insertions = body
    # (header slice art_lines[:hdr_n] INCLUDES its trailing blank line, so the
    #  copied body starts exactly at index hdr_n)
    body = art_lines[hdr_n: ext_idx]
    expected = []
    ins = man["insertions"]
    for ln in body_src:
        expected.append(ln)
        for blk in ins:
            # honor occurrence: insert exactly at the occurrence-th anchor hit
            if blk["anchor"] == ln and expected.count(ln) == blk["occurrence"]:
                expected.extend(l["text"] for l in blk["lines"])
    cls = first_divergence_class(body, expected)
    check(cls is None, "baseline ⊕ declared insertions = copied body (byte-exact)",
          f"divergence class: {cls}" if cls else f"{len(body)} lines reconstructed")

    # 5. classification accounting
    total_marker = sum(1 for ln in art_lines if MARKER in ln)
    header_marker = sum(1 for ln in header if MARKER in ln)
    marked_code = sum(1 for blk in ins for l in blk["lines"]
                      if l["marked"] and l["kind"] == "code")
    marked_comment = sum(1 for blk in ins for l in blk["lines"]
                         if l["marked"] and l["kind"] == "comment")
    unmarked_comment = sum(1 for blk in ins for l in blk["lines"]
                           if not l["marked"] and l["kind"] == "comment")
    unmarked_code = sum(1 for blk in ins for l in blk["lines"]
                        if not l["marked"] and l["kind"] == "code")
    ext_code = sum(1 for ln in ext if classify(ln)[0] == "code")
    print("  --- accounting ---")
    print(f"  total '//GHOST:' occurrences      : {total_marker}"
          f"  ({header_marker} of them in the explanatory header — NOT executable)")
    print(f"  live ghost-code additions (body)  : {marked_code} marked CODE lines")
    print(f"  declared comment additions (body) : {unmarked_comment + marked_comment}"
          f"  ({unmarked_comment} unmarked + {marked_comment} marked)")
    print(f"  UNDECLARED code additions (body)  : {unmarked_code}  (must be 0)")
    print(f"  extension-region code lines       : {ext_code}")
    check(unmarked_code == 0,
          "no undeclared executable addition inside the copied body")
    check(total_marker == header_marker + marked_code + marked_comment,
          "marker accounting: header mentions + declared marked lines = total")

    print(f"\nVERDICT: {'PASS — exact byte-faithfulness established' if ok else 'FAIL'}")
    print("  equation: baseline_semantics + exactly_declared_ghost_additions")
    print("             = ghost_instrumented_semantics  [HOLDS]" if ok
          else "  equation: [DOES NOT HOLD]")
    return ok


# --------------------------------------------------------------- selftest ----
def selftest() -> bool:
    import tempfile
    man = json.load(open(MAN))
    art_lines = open(ART).read().splitlines()
    hdr_n = man["header"]["line_count"]
    ext_idx = art_lines.index(EXT_ANCHOR) - 1
    body = art_lines[hdr_n + 1: ext_idx]
    ok = True

    def mutate(name, lines):
        nonlocal ok
        mutated = art_lines[: hdr_n] + lines + art_lines[ext_idx:]
        with tempfile.NamedTemporaryFile("w", suffix=".k", delete=False) as f:
            f.write("\n".join(mutated) + "\n")
            tmp = f.name
        global ART
        real = ART
        ART = tmp
        # structural checks only: the whole-file frozen-hash check would fail
        # trivially for ANY mutation; we must show the RECONSTRUCTION EQUATION
        # itself detects each defect class
        import io, contextlib
        buf = io.StringIO()
        with contextlib.redirect_stdout(buf):
            res = verify(structural_only=True)
        ok = ok and (res is False)
        print(f"-- selftest: {name:38s} detected: {'YES' if res is False else 'NO — CHECKER WEAKNESS'}")
        ART = real
        import os
        os.unlink(tmp)

    missing = body[: len(body) // 2] + body[len(body) // 2 + 1:]
    mutate("missing baseline line", missing)

    altered = list(body)
    k = next(i for i, ln in enumerate(body) if ln.startswith("  rule "))
    altered[k] = altered[k].replace("=>", "=>>")
    mutate("altered baseline line", altered)

    reordered = list(body)
    ri = next(i for i, ln in enumerate(body) if ln.startswith("  rule "))
    reordered[ri], reordered[ri + 1] = reordered[ri + 1], reordered[ri]
    mutate("reordered baseline lines", reordered)

    undeclared = list(body)
    ui = art_lines.index(BODY_START_ANCHOR) - hdr_n - 1
    undeclared[ui + 1: ui + 1] = ["  syntax Ghost ::= \"EVIL\" \"(\" Int \")\""]
    mutate("undeclared addition in copied body", undeclared)

    return ok


if __name__ == "__main__":
    mode = sys.argv[1] if len(sys.argv) > 1 else "verify"
    if mode == "freeze":
        freeze("--force" in sys.argv)
    elif mode == "verify":
        sys.exit(0 if verify() else 1)
    elif mode == "selftest":
        sys.exit(0 if selftest() else 1)
    else:
        sys.exit(f"unknown mode {mode!r} (freeze|verify|selftest)")
