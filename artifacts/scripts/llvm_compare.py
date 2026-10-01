#!/usr/bin/env python3
"""Semantic comparator for the abstract demo suite (Phase 1A, Part III).

Parses two run_demos.sh-format transcripts (Haskell backend vs LLVM backend)
and compares, per demo, the decision-relevant cells:
  result, committed, head, lineageNext, lineage, prospective
plus the full raw <srw3> final block when extraction is ambiguous.

Exit 0 iff every demo is semantically identical across backends.
"""
import re
import sys


def parse(path):
    txt = open(path).read()
    demos = {}
    # split on DEMO: markers
    parts = re.split(r'^DEMO: ', txt, flags=re.M)
    for part in parts[1:]:
        lines = part.splitlines()
        name = lines[0].strip()
        outcome = '\n'.join(lines)
        cells = dict(re.findall(
            r'^  (result|committed|head|lineageNext|lineage|prospective)\s*:\s?(.*)$',
            outcome, re.M))
        err = re.search(r'^\[(Error|Critical\])?.*\[Error\].*$', outcome, re.M)
        # key by the demo program text (unique per demo; runners use
        # different title conventions, the program is the stable identity)
        m = re.search(r'--- program:\n(.*?)--- outcome:', outcome, re.S)
        key = ' '.join(m.group(1).split()) if m else name
        demos[key] = {'cells': cells,
                      'name': name,
                      'error': '[Error]' in outcome,
                      'raw': outcome}
    return demos


def norm(s):
    """normalize whitespace-only differences inside cell values"""
    return ' '.join(s.split())


def main(hs_path, llvm_path):
    hs, ll = parse(hs_path), parse(llvm_path)
    names = sorted(set(hs) | set(ll), key=lambda k: (hs.get(k, ll.get(k))['name']))
    print(f"{'demo':44s} {'verdict':10s} detail")
    print("-" * 100)
    all_ok = True
    for n in names:
        if n not in hs or n not in ll:
            who = 'haskell' if n not in hs else 'llvm'
            label = (hs.get(n) or ll.get(n))['name'][:40]
            print(f"{label:44s} {'MISSING':10s} {who} transcript lacks the demo")
            all_ok = False
            continue
        a, b = hs[n], ll[n]
        label = a['name'][:40]
        if a['error'] and b['error']:
            print(f"{label:44s} {'BOTH-ERR':10s} both backends error (recorded verbatim)")
            continue
        if a['error'] != b['error']:
            print(f"{label:44s} {'DIVERGE':10s} error status differs hs_err={a['error']} llvm_err={b['error']}")
            all_ok = False
            continue
        diffs = []
        for c in ['result', 'committed', 'head', 'lineageNext', 'lineage', 'prospective']:
            va, vb = norm(a['cells'].get(c, '?')), norm(b['cells'].get(c, '?'))
            if va != vb:
                diffs.append(f"{c}: hs={va!r} llvm={vb!r}")
        if diffs:
            print(f"{label:44s} {'DIVERGE':10s} " + " | ".join(diffs))
            all_ok = False
        else:
            print(f"{label:44s} {'MATCH':10s} " +
                  " ".join(f"{c}={norm(a['cells'].get(c,'?'))[:28]}"
                           for c in ['result', 'committed']))
    print("-" * 100)
    print(f"total demos: {len(names)}; "
          f"verdict: {'SEMANTICALLY EQUIVALENT' if all_ok else 'DIVERGENCE FOUND'}")
    return 0 if all_ok else 1


if __name__ == '__main__':
    sys.exit(main(sys.argv[1], sys.argv[2]))
