#!/bin/bash
# =============================================================================
# SRW3 Phase 1B — generalized demo suite runner (self-checking).
# Runs k/gen-demos/*.srw3 against a pre-built srw3gen definition and checks
# decision-relevant cells (normalized: pairs sorted, label-formats folded).
# Usage: bash scripts/run_gen_demos.sh <def-dir> <backend-label>
# The expected table encodes the Phase-1B demo contract (mandate Part IX):
#   CM2 counterexample (naive registry) -> commits the alias-unsafe state
#   CM2 alias-aware  -> reject (overflow) / accept (safe bound)
#   CM3 counterexample (naive registry) -> commits aggregate overflow
#   CM3 authority-aware -> reject (overflow) / accept (within budget)
#   multi-write + multi-resource complete declaration -> proceeds
#   hidden effect under trust      -> unsafe state can be committed
#   hidden effect under enforce    -> blocked
#   alias-hidden effect (enforce)  -> blocked
# =============================================================================
export LD_LIBRARY_PATH="${LD_LIBRARY_PATH:-}"
source /home/z/my-project/tools/env.sh
DEF=${1:?usage: run_gen_demos.sh <def-dir> <label>}
LBL=${2:?usage: run_gen_demos.sh <def-dir> <label>}
KDIR=/home/z/my-project/srw3-kevm
cd "$KDIR"
mkdir -p transcripts

pass=0; fail=0
check() { # name expected_result expected_committed(expected_usage)
  local name="$1" er="$2" ec="$3" eu="$4" raw="/tmp/genkr_$name.txt"
  krun "k/gen-demos/$name.srw3" -d "$DEF" > "$raw" 2>&1
  local rex=$?
  python3 - "$name" "$er" "$ec" "$eu" "$raw" "$rex" <<'PYEOF'
import re, sys
name, er, ec, eu, raw, rex = sys.argv[1:7]
txt = open(raw).read()
if rex != '0' or '[Error' in txt:
    print(f'  [{name}] KRUN-ERROR'); sys.exit(1)
blocks = re.findall(r'<srw3g>.*?</srw3g>', txt, re.S)
final = blocks[-1] if blocks else ''
def cell(c):
    m = re.search(r'<%s>\s*(.*?)\s*</%s>' % (c, c), final, re.S)
    return ' '.join(m.group(1).split()) if m else '?'
def canon(m):
    """canonical list of (app, slot-or-None, value) sorted; .Map -> []"""
    m = m.strip()
    if m in ('.', '.Map', ''): return []
    out = []
    for key, val in re.findall(r'(.+?)\|->\s*(-?\d+)', m):
        key = key.strip()
        ms = re.search(r'app:\s*(\w+)\s*,\s*slot:\s*(\d+)', key) or \
             re.search(r'stK\s*\(\s*(\w+)\s*,\s*(\d+)\s*\)', key)
        if ms: out.append((ms.group(1), int(ms.group(2)), int(val)))
        else:
            ma = re.search(r'app:\s*(\w+)', key) or re.search(r'(\w+)\s*$', key)
            out.append((ma.group(1), None, int(val)))
    return sorted(out)
result = cell('result').strip('"')
committed = cell('committed')
usage = cell('usage-c')
ok = (er == result) and (canon(ec) == canon(committed)) and (canon(eu) == canon(usage))
print(f'  [{name}] result={result}')
print(f'      committed={canon(committed)}  usage-c={canon(usage)}')
print(f'      expected  ={canon(ec)}  usage-c={canon(eu)}  -> {"PASS" if ok else "FAIL"}')
sys.exit(0 if ok else 1)
PYEOF
  if [ $? -eq 0 ]; then pass=$((pass+1)); else fail=$((fail+1)); fi
}

echo "=== SRW3 Phase 1B generalized demo suite (backend: $LBL) ==="
# name                              result                       committed                                     usage-c
check cm2_counterexample           "commit"                    "stK(appA,7) |-> 5 stK(appB,3) |-> 6"          "."
check cm2_alias_reject             "reject"                    "stK(appA,7) |-> 5 stK(appB,3) |-> 0"          "."
check cm2_alias_accept             "commit"                    "stK(appA,7) |-> 5 stK(appB,3) |-> 4"          "."
check cm3_overflow_counterexample  "commit"                    "."                                            "appC |-> 6 appD |-> 6"
check cm3_auth_reject              "reject"                    "."                                            "appC |-> 6"
check cm3_safe_aggregate           "commit"                    "."                                            "appC |-> 4 appD |-> 5"
check gen_multiwrite_multiresource "commit"                    "stK(appA,7) |-> 2 stK(appB,3) |-> 3 stK(appC,0) |-> 1 stK(appD,0) |-> 1" "appC |-> 4"
check gen_hidden_trust             "commit"                    "stK(appA,7) |-> 5 stK(appB,3) |-> 3 stK(appC,0) |-> 1 stK(appD,0) |-> 9" "."
check gen_hidden_enforce           "blocked-effect-incomplete" "stK(appA,7) |-> 5 stK(appB,3) |-> 0 stK(appC,0) |-> 1 stK(appD,0) |-> 1" "."
check gen_alias_hidden_enforce     "blocked-effect-incomplete" "stK(appA,7) |-> 5 stK(appB,3) |-> 0"          "."
echo "=== gen demos ($LBL): PASS=$pass FAIL=$fail ==="
[ "$fail" -eq 0 ]
