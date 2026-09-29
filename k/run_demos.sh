#!/bin/bash
# SRW3 Phase 0-D demo suite — abstract layer (haskell backend)
source /home/z/my-project/tools/env.sh
cd $SRW3/k

extract() {
  # $1 = raw krun output file; prints decision-relevant cells
  grep -E '<result>|<committed>|<head>|<lineageNext>|"[a-z-]+"' "$1" | head -12
}

run_demo() {
  local name="$1"; local file="$2"
  echo "==================================================================="
  echo "DEMO: $name"
  echo "--- program:"
  cat "$file"
  echo "--- outcome:"
  krun "$file" -d hs-out 2>&1 | tail -n +1 > /tmp/krout.txt
  if grep -qE "^\[Error" /tmp/krout.txt; then cat /tmp/krout.txt | head -5; fi
  # final config = last <srw3> block; extract key cells
  python3 - "$name" <<'PYEOF'
import re, sys
name = sys.argv[1]
txt = open('/tmp/krout.txt').read()
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

mkdir -p demos ../transcripts

# ---- minimal model (handoff §9, §11) ----
cat > demos/demo1_min_reject.srw3 <<'EOF'
useRegistry(complete) , init(appA,0,7) , init(appB,0,3) , as(appB) , begin , w(appB,0,7) , wfCheck , gate
EOF
cat > demos/demo2_negmodel_accept.srw3 <<'EOF'
useRegistry(negative) , init(appA,0,7) , init(appB,0,3) , as(appB) , begin , w(appB,0,7) , wfCheck , gate
EOF
cat > demos/demo2b_negmodel_two_steps.srw3 <<'EOF'
useRegistry(negative) , init(appA,0,7) , init(appB,0,3) , as(appB) , begin , w(appB,0,7) , wfCheck , gate , as(appB) , begin , w(appB,0,2) , wfCheck , gate
EOF
# ---- hidden effect (handoff §13, CM7) ----
cat > demos/demo3_hidden_trust.srw3 <<'EOF'
useRegistry(complete) , setPolicy(trust) , init(appA,0,7) , init(appB,0,3) , init(appC,0,3) , as(appB) , begin , w(appB,0,2) , wH(appC,0,11) , wfCheck , gate
EOF
cat > demos/demo3b_hidden_write_to_A_trust.srw3 <<'EOF'
useRegistry(complete) , setPolicy(trust) , init(appA,0,7) , init(appB,0,3) , as(appB) , begin , w(appB,0,2) , wH(appA,0,9) , wfCheck , gate
EOF
cat > demos/demo4_hidden_enforce.srw3 <<'EOF'
useRegistry(complete) , setPolicy(enforce) , init(appA,0,7) , init(appB,0,3) , init(appC,0,3) , as(appB) , begin , w(appB,0,2) , wH(appC,0,11) , wfCheck , gate
EOF
# ---- authority / lineage evidence ----
cat > demos/demo5_auth_reject.srw3 <<'EOF'
useRegistry(complete) , init(appA,0,7) , init(appB,0,3) , begin , w(appB,0,2) , wfCheck , gate
EOF
# ---- chain: oracle -> lending -> liquidator (handoff §15-17) ----
cat > demos/demo6_chain_ok.srw3 <<'EOF'
useRegistry(chainComplete) , init(oracle,0,100) , init(oracle,1,1) , init(lending,0,100) , init(lending,1,5) , init(liq,0,0) , init(liq,1,100) , as(lending) , begin , rd(oracle) , w(lending,0,100) , wfCheck , gate , as(liq) , begin , rd(lending) , w(liq,0,4) , w(liq,1,100) , wfCheck , gate
EOF
cat > demos/demo7_chain_stale_price.srw3 <<'EOF'
useRegistry(chainComplete) , init(oracle,0,100) , init(oracle,1,1) , init(lending,0,100) , init(lending,1,5) , init(liq,0,0) , init(liq,1,100) , as(lending) , begin , rdH(oracle) , w(lending,0,90) , wfCheck , gate
EOF
cat > demos/demo8_chain_three_way_ok.srw3 <<'EOF'
useRegistry(chainComplete) , init(oracle,0,100) , init(oracle,1,1) , init(lending,0,100) , init(lending,1,5) , init(liq,0,0) , init(liq,1,100) , as(lending) , begin , rd(oracle) , w(lending,0,100) , wfCheck , gate , as(liq) , begin , rd(lending) , w(liq,0,4) , w(liq,1,90) , wfCheck , gate
EOF
cat > demos/demo9_chain_threeway_violation.srw3 <<'EOF'
useRegistry(chainComplete) , init(oracle,0,100) , init(oracle,1,1) , init(lending,0,100) , init(lending,1,5) , init(liq,0,0) , init(liq,1,100) , as(lending) , begin , rd(oracle) , w(lending,0,100) , wfCheck , gate , as(liq) , begin , rd(lending) , w(liq,0,4) , w(liq,1,99) , wfCheck , gate
EOF
# ---- CM6: three-way dependency, pairwise contracts only ----
cat > demos/demo10_pairwise_only_threeway_hole.srw3 <<'EOF'
useRegistry(pairwiseOnly) , init(oracle,0,100) , init(oracle,1,1) , init(lending,0,100) , init(lending,1,5) , init(liq,0,0) , init(liq,1,100) , as(lending) , begin , rd(oracle) , w(lending,0,100) , wfCheck , gate , as(liq) , begin , rd(lending) , w(liq,0,4) , w(liq,1,99) , wfCheck , gate
EOF

run_demo "D1 minimal (7,3)->(7,7), complete registry [expect reject, committed (7,3)]" demos/demo1_min_reject.srw3
run_demo "D2 negative registry (IAB missing) [expect accept -> committed (7,7) = CM1]" demos/demo2_negmodel_accept.srw3
run_demo "D2b negative registry, second in-bounds step [expect accept, (7,2)]" demos/demo2b_negmodel_two_steps.srw3
run_demo "D3 CM7: hidden write to appC (outside declared foot) + trust [expect COMMIT of violation appC:=11]" demos/demo3_hidden_trust.srw3
run_demo "D3b hidden write to appA (co-edge with appB) + trust [expect reject via IAB: defense-in-depth]" demos/demo3b_hidden_write_to_A_trust.srw3
run_demo "D4 hidden write + enforce policy [expect blocked-effect-incomplete]" demos/demo4_hidden_enforce.srw3
run_demo "D5 no actor (unauthorized) [expect reject-auth, committed unchanged]" demos/demo5_auth_reject.srw3
run_demo "D6 chain: honest lending+settlement [expect 2 commits]" demos/demo6_chain_ok.srw3
run_demo "D7 chain: lending uses stale/undeclared price 90 [expect reject via IOL]" demos/demo7_chain_stale_price.srw3
run_demo "D8 chain: settlement at price 90 != lending 100, 3-way lineage check [expect reject via IOLD]" demos/demo8_chain_three_way_ok.srw3
run_demo "D9 chain: settlement at 99 with complete registry [expect reject via IOLD]" demos/demo9_chain_threeway_violation.srw3
run_demo "D10 CM6: pairwise contracts only, three-way edge missing [expect accept = violation committed]" demos/demo10_pairwise_only_threeway_hole.srw3
# D7b: declared read of oracle, but lending writes stale price (IOL violation, wfCheck passes)
cat > demos/demo7b_chain_stale_declared.srw3 <<'EOF'
useRegistry(chainComplete) , init(oracle,0,100) , init(oracle,1,1) , init(lending,0,100) , init(lending,1,5) , init(liq,0,0) , init(liq,1,100) , as(lending) , begin , rd(oracle) , w(lending,0,90) , wfCheck , gate
EOF
run_demo "D7b chain: declared read, stale price write 90 [expect reject via IOL]" demos/demo7b_chain_stale_declared.srw3
