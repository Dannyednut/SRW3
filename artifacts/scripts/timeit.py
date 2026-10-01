#!/usr/bin/env python3
"""timeit.py — run a command, record wall time + peak child RSS (KB).

Usage: timeit.py <logfile> <cmd> [args...]
Appends a summary block to <logfile>; prints the command's exit code to stdout
as EXIT:<code> and mirrors the command's stdout/stderr into <logfile>.
"""
import resource
import subprocess
import sys
import time

log, cmd = sys.argv[1], sys.argv[2:]
t0 = time.time()
with open(log, "w") as f:
    f.write(f"$ {' '.join(cmd)}\n")
    p = subprocess.run(cmd, stdout=f, stderr=subprocess.STDOUT)
wall = time.time() - t0
peak = resource.getrusage(resource.RUSAGE_CHILDREN).ru_maxrss  # KB (Linux)
with open(log, "a") as f:
    f.write(f"\n[timeit] exit={p.returncode} wall={wall:.2f}s peak_rss={peak}KB "
            f"({peak/1024:.1f}MiB)\n")
print(f"EXIT:{p.returncode} wall={wall:.2f}s peak_rss={peak/1024:.1f}MiB")
