#!/bin/bash
# LLVM demo suite — run the 13 abstract demos against a given definition dir,
# with byte-compatible extraction format to scripts/../k/run_demos.sh output.
# usage: llvm_demo_suite.sh <definition-dir> <output-file>
set -u
source /home/z/my-project/tools/env.sh
DEF="$1"; OUT="$2"
cd "$SRW3/k" || exit 1

run_demo() {
  local name="$1"; local file="$2"
  echo "==================================================================="
  echo "DEMO: $name"
  echo "--- program:"
  cat "$file"
  echo "--- outcome:"
  krun "$file" -d "$DEF" 2>&1 > /tmp/krout_1a.txt
  if grep -qE "^\[Error" /tmp/krout_1a.txt; then head -5 /tmp/krout_1a.txt; fi
  python3 - "$name" <<'PYEOF'
import re, sys
name = sys.argv[1]
txt = open('/tmp/krout_1a.txt').read()
blocks = re.findall(r'<srw3>.*?</srw3>', txt, re.S)
final = blocks[-1] if blocks else ''
def cell(c):
    m = re.search(r'<%s>\s*(.*?)\s*</%s>' % (c, c), final, re.S)
    return ' '.join(m.group(1).split()) if m else '?'
print('  result      :', cell('result'))
print('  committed   :', cell('committed'))
print('  head        :', cell('head'))
print('  lineageNext :', cell('lineageNext'))
print('  lineage     :', cell('lineage'))
print('  prospective :', cell('prospective'))
PYEOF
}

for f in $(ls demos/*.srw3 | sort); do
  run_demo "$(basename "$f" .srw3)" "$f"
done
echo "SUITE-DONE"
