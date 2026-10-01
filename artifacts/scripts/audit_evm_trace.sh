#!/bin/bash
# Audit P5: KEVM execution-path traces — stale-price example, stage by stage
source /home/z/my-project/tools/env.sh
cd /home/z/my-project/srw3-kevm
OUT=transcripts/audit/evm_trace_stale.txt
: > "$OUT"
{
echo "## P5 audit — KEVM binding execution path: stale-price example"
echo "## Method: command-granularity prefix programs of the negative stale demo."
echo "## Each stage runs the FULL KEVM pipeline (real EVM execution) for the"
echo "## commands executed so far, then halts; storages/carrier extracted below."
echo "## date: $(date -u +'%Y-%m-%dT%H:%M:%SZ')"
echo
} >> "$OUT"

ORACLE='PUSH(1,100) ; PUSH(1,0) ; SSTORE ; PUSH(1,1) ; PUSH(1,1) ; SSTORE ; STOP ; .OpCodes'
LENDING_STALE='PUSH(1,32) ; PUSH(1,0) ; PUSH(1,0) ; PUSH(1,0) ; PUSH(1,0) ; PUSH(2,4097) ; PUSH(2,10000) ; CALL ; POP ; PUSH(1,90) ; PUSH(1,0) ; SSTORE ; PUSH(1,5) ; PUSH(1,1) ; SSTORE ; STOP ; .OpCodes'
LENDING_HONEST='PUSH(1,32) ; PUSH(1,0) ; PUSH(1,0) ; PUSH(1,0) ; PUSH(1,0) ; PUSH(2,4097) ; PUSH(2,10000) ; CALL ; POP ; PUSH(1,0) ; MLOAD ; PUSH(1,0) ; SSTORE ; PUSH(1,5) ; PUSH(1,1) ; SSTORE ; STOP ; .OpCodes'
LIQ='PUSH(1,32) ; PUSH(1,0) ; PUSH(1,0) ; PUSH(1,0) ; PUSH(1,0) ; PUSH(2,4098) ; PUSH(2,10000) ; CALL ; POP ; PUSH(1,4) ; PUSH(1,0) ; SSTORE ; PUSH(1,0) ; MLOAD ; PUSH(1,1) ; SSTORE ; STOP ; .OpCodes'
ORACLE90='PUSH(1,90) ; PUSH(1,0) ; SSTORE ; PUSH(1,1) ; PUSH(1,1) ; SSTORE ; STOP ; .OpCodes'

extract() {
python3 - "$1" "$2" <<'PYEOF'
import re, sys
txt=open(sys.argv[1]).read()
label=sys.argv[2]
blocks=re.findall(r'<kevm>.*?</kevm>', txt, re.S)
f=blocks[-1] if blocks else ''
def cell(c, blk):
    m=re.search(r'<%s>\s*(.*?)\s*</%s>'%(c,c), blk, re.S)
    return ' '.join(m.group(1).split()) if m else '?'
kcell = cell('k', f)
m=re.search(r'#w3State\s*\(\s*\.\.\.\s*s:\s*(.*?)\s*,\s*ln:\s*(.*?)\s*,\s*n:\s*(\S+)\s*,\s*h:\s*(\S+)\s*\)', kcell, re.S)
if m:
    print('  carrier : s=%s ln=%s n=%s h=%s' % (' '.join(m.group(1).split()), ' '.join(m.group(2).split()), m.group(3), m.group(4)))
else:
    print('  carrier : (none — program consumed)')
for addr,name in ((4097,'oracle'),(4098,'lending'),(4099,'liq')):
    m=re.search(r'<acctID>\s*%d\s*</acctID>.*?<storage>\s*(.*?)\s*</storage>'%addr, f, re.S)
    print('  %-8s: storage = %s' % (name, ' '.join(m.group(1).split()) if m else '?'))
PYEOF
}

run_stage() {
  local label="$1"; local prog="$2"
  echo "=== $label ===" >> "$OUT"
  echo "$prog" > /tmp/stage.srw3evm
  timeout 900 krun /tmp/stage.srw3evm -d k/kevm/kevm-hs-out -cMODE=NORMAL -cSCHEDULE=CANCUN -cUSEGAS=false -cCHAINID=1 > /tmp/stage_out.txt 2>&1
  echo "krun exit: $?" >> "$OUT"
  extract /tmp/stage_out.txt "$label" >> "$OUT"
  echo >> "$OUT"
}

run_stage "STAGE 1 — #w3Setup #w3Snap0 (accounts created; committed snapshot = empty storages)" \
"#w3Setup #w3Snap0 #w3Nil"

run_stage "STAGE 2 — oracle segment: REAL SSTORE x2 (price=100, auth=1)" \
"#w3Setup #w3Snap0 #w3Run(4097, $ORACLE) #w3Nil"

run_stage "STAGE 3 — lending segment: REAL CALL(oracle) [return buffer ignored], SSTORE price=90 (STALE), debt=5" \
"#w3Setup #w3Snap0 #w3Run(4097, $ORACLE) #w3Run(4098, $LENDING_STALE) #w3Nil"

run_stage "STAGE 4 — liquidator segment: REAL CALL(lending) -> returned stale price 90; SSTORE transfer=4, MLOAD->priceLineage=90" \
"#w3Setup #w3Snap0 #w3Run(4097, $ORACLE) #w3Run(4098, $LENDING_STALE) #w3Run(4099, $LIQ) #w3Nil"

run_stage "STAGE 5 — SRW3 gate: IOL fails (lending 90 != oracle 100) -> REJECT + RESTORE all storages from snapshot" \
"#w3Setup #w3Snap0 #w3Run(4097, $ORACLE) #w3Run(4098, $LENDING_STALE) #w3Run(4099, $LIQ) #w3Gate0 #w3Nil"

run_stage "SENSITIVITY PROBE — oracle writes 90; lending HONESTLY stores the CALL-returned value (MLOAD of return buffer)" \
"#w3Setup #w3Snap0 #w3Run(4097, $ORACLE90) #w3Run(4098, $LENDING_HONEST) #w3Run(4099, $LIQ) #w3Gate0 #w3Nil"

echo "=== done ===" >> "$OUT"
cat "$OUT"
