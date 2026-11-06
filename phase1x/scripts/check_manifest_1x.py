#!/usr/bin/env python3
"""SRW3 Phase 1X — the final full-tree evidence-manifest generator/checker
(WS-J, 2026-11-06 evidence-integrity correction).

The original 138-entry manifest (evidence-manifest-1x.txt) was generated
BEFORE the final report was committed and therefore does not cover the
complete final delivered Phase 1X tree. This tool generates the FINAL
manifest (evidence-manifest-1x-final.txt) over EVERY tracked file under
phase1x/ — excluding ONLY the manifest itself (a file cannot contain its own
digest; this self-exclusion is documented in the manifest header and enforced
by the checker) — and verifies any manifest against the live tree.

Modes:
  --generate  enumerate the tracked phase1x/ files (git ls-files when the
              tree is a git work tree; os.walk fallback for fixture trees),
              SHA-256 each, and write the manifest:
                header (source commit, generation date, scope, toolchain
                note, self-exclusion note) + one `<sha256>  <relpath>` line
                per file, sorted by path, each path exactly once.
  --check     verify a manifest against the live tree and REJECT, with named
              reasons: missing files, digest mismatches (a file modified
              after generation), duplicate manifest paths, paths in the
              tree but absent from the manifest, paths in the manifest but
              absent from the tree, and a manifest that lists itself.

Exit 0 iff every check passes (prints `MANIFEST OK ...`); nonzero with named
alarms otherwise. Level III only.
"""
import argparse
import datetime
import hashlib
import os
import re
import subprocess
import sys

LINE_RX = re.compile(r"^([0-9a-f]{64})  (\S.*)$")


def sha256_file(p):
    h = hashlib.sha256()
    with open(p, "rb") as f:
        for chunk in iter(lambda: f.read(1 << 16), b""):
            h.update(chunk)
    return h.hexdigest()


def tree_files(root, scope_rel):
    """The authoritative file set for the scope: git ls-files when root is a
    git work tree (tracked files only — untracked scratch must never enter an
    evidence manifest), else os.walk (fixture trees have no git)."""
    try:
        out = subprocess.run(["git", "-C", root, "ls-files", "--", scope_rel],
                             capture_output=True, text=True, check=True).stdout
        files = [ln for ln in out.splitlines() if ln.strip()]
        if files or subprocess.run(["git", "-C", root, "rev-parse", "--git-dir"],
                                   capture_output=True).returncode == 0:
            return sorted(files), "git ls-files (tracked)"
    except (OSError, subprocess.CalledProcessError):
        pass
    got = []
    base = os.path.join(root, scope_rel)
    for dirpath, _dirs, names in os.walk(base):
        for n in names:
            got.append(os.path.relpath(os.path.join(dirpath, n), root))
    return sorted(got), "os.walk (fixture tree — no git)"


def git_head(root):
    try:
        return subprocess.run(["git", "-C", root, "rev-parse", "HEAD"],
                              capture_output=True, text=True, check=True).stdout.strip()
    except (OSError, subprocess.CalledProcessError):
        return "(not a git work tree — fixture tree)"


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--generate", action="store_true")
    ap.add_argument("--check", action="store_true")
    ap.add_argument("--root", required=True, help="the tree the manifest covers")
    ap.add_argument("--scope-rel", default="phase1x", help="scope directory, repo-relative")
    ap.add_argument("--out", default=None, help="(generate) manifest output path")
    ap.add_argument("--manifest", default=None, help="(check) manifest to verify")
    ap.add_argument("--toolchain-note", default="K v7.1.337, Z3 4.13.3 (pinned)")
    a = ap.parse_args()
    if a.generate == a.check:
        sys.exit("exactly one of --generate / --check is required")

    files, how = tree_files(a.root, a.scope_rel)

    if a.generate:
        if not a.out:
            sys.exit("--generate requires --out")
        man_rel = os.path.relpath(a.out, a.root)
        files = [f for f in files if f != man_rel]   # self-exclusion, documented
        lines = [
            "# SRW3 Phase 1X — FINAL full-tree evidence SHA-256 manifest (WS-J)",
            "# Generated: " + datetime.datetime.now(datetime.timezone.utc)
                .strftime("%Y-%m-%dT%H:%M:%SZ"),
            f"# Branch: phase1x-ghost-runner-hardening",
            f"# Source commit/tree: {git_head(a.root)} (digests generated against THIS tree)",
            f"# Scope: every file under {a.scope_rel}/ ({len(files)} files, enumerated via {how})",
            f"# Toolchain pinned for the recorded executions: {a.toolchain_note}",
            "# Self-exclusion: this manifest cannot contain its own digest — it is the",
            "# ONLY file under the scope not listed here (by design, not an omission).",
            "# A file modified after generation fails the checker (digest mismatch);",
            "# any added/removed file fails the coverage check (missing/unexpected path).",
            "# Supersedes evidence-manifest-1x.txt (138 entries) ONLY in coverage;",
            "# that manifest is PRESERVED verbatim as historical evidence.",
        ]
        for f in files:
            lines.append(f"{sha256_file(os.path.join(a.root, f))}  {f}")
        with open(a.out, "w") as fh:
            fh.write("\n".join(lines) + "\n")
        print(f"manifest written: {a.out} ({len(files)} digests; self-excluded: {man_rel}; "
              f"tree enumeration: {how})")
        return

    # --- check mode ---------------------------------------------------------
    alarms = []
    man = a.manifest
    if not man or not os.path.exists(man):
        sys.exit(f"FATAL: manifest not found: {man}")
    man_rel = os.path.relpath(man, a.root)
    listed, seen = {}, {}
    n_comment = 0
    for ln in open(man, errors="replace").read().splitlines():
        if not ln.strip() or ln.lstrip().startswith("#"):
            n_comment += 1
            continue
        m = LINE_RX.match(ln)
        if not m:
            alarms.append(f"MALFORMED line (not '<sha256>  <path>'): {ln!r}")
            continue
        digest, rel = m.group(1), m.group(2).rstrip()
        if rel in seen:
            alarms.append(f"DUPLICATE path in manifest: {rel} (lines {seen[rel]} and this one)")
        else:
            seen[rel] = len(seen) + 1
            listed[rel] = digest
    if man_rel in listed:
        alarms.append("SELF-INCLUSION: the manifest lists itself — a file cannot contain its "
                      f"own digest ({man_rel})")
    for rel in sorted(listed):
        p = os.path.join(a.root, rel)
        if not os.path.exists(p):
            alarms.append(f"MISSING file listed in manifest: {rel}")
            continue
        got = sha256_file(p)
        if got != listed[rel]:
            alarms.append(f"DIGEST MISMATCH (modified after generation): {rel} "
                          f"manifest={listed[rel]} actual={got}")
    man_set = set(listed)
    tree_set = set(files)
    missing = sorted(tree_set - man_set - {man_rel})
    unexpected = sorted(man_set - tree_set)
    for rel in missing:
        alarms.append(f"NOT COVERED (in tree, absent from manifest): {rel}")
    for rel in unexpected:
        alarms.append(f"UNEXPECTED (in manifest, not in tree): {rel}")
    print(f"manifest: {man} ({len(listed)} listed paths, {n_comment} header/comment lines, "
          f"tree enumeration: {how} over {len(files)} files)")
    if alarms:
        print("MANIFEST REJECTED:")
        for x in alarms:
            print("  -", x)
        sys.exit(1)
    print(f"MANIFEST OK — {len(listed)} paths, exactly-once coverage, all digests match; "
          f"self-exclusion of {man_rel} enforced")


if __name__ == "__main__":
    main()
