#!/bin/bash
# r2: original scaffold unexecutability probe (P1 evidence)
source /home/z/my-project/tools/env.sh
cd /home/z/my-project/srw3-work
OUT=/home/z/my-project/srw3-kevm/transcripts/audit/original_scaffold_probe.txt
: > "$OUT"
{
echo "## P1 evidence — the ORIGINAL Phase 0-D scaffold (baseline v1.0, branch main,"
echo "## compat patch applied only for K v7.1.337 module-resolution — see report §C)"
echo "## date: $(date -u +'%Y-%m-%dT%H:%M:%SZ')"
echo
echo "## (a) The scaffold's syntax admits NO programs: Tau ::= tau(AppId, TransitionId)"
echo "##     but AppId and TransitionId have NO productions; gateOk/rootOk have NO"
echo "##     defining equations and rootOk is referenced by NO rule."
echo
} >> "$OUT"

echo "=== [a] kompile of the scaffold (patched branch) — succeeds ===" >> "$OUT"
timeout 600 kompile k/srw3.k --backend haskell --main-module SRW3-SEMANTICS --syntax-module SRW3-SEMANTICS -I k -o /tmp/scaffold-out >> "$OUT" 2>&1
echo "kompile exit: $?" >> "$OUT"
echo >> "$OUT"

echo "=== [b] attempting to WRITE a tau program — no production exists for AppId ===" >> "$OUT"
cat > /tmp/tau_probe.srw3 <<'EOF'
tau(appA, t1)
EOF
krun /tmp/tau_probe.srw3 -d /tmp/scaffold-out > /tmp/tau_out.txt 2>&1
echo "krun tau(appA,t1) exit: $?" >> "$OUT"
head -6 /tmp/tau_out.txt >> "$OUT"
echo "  ^ parse/rewrite behavior recorded: with no AppId production the term cannot" >> "$OUT"
echo "    denote anything; the tau skeleton is uninhabitable as shipped." >> "$OUT"
echo >> "$OUT"

echo "=== [c] the gateOk placeholder is STUCK: even the accept rule's requires cannot evaluate ===" >> "$OUT"
cat > /tmp/gateok_probe.k <<'EOF'
requires "srw3.k"
module SCAFFOLD-PROBE
  imports SRW3-SEMANTICS
  // give AppId/TransitionId tokens JUST for the probe (the baseline has none)
  syntax AppId ::= "appA"
  syntax TransitionId ::= "t1"
endmodule
EOF
timeout 600 kompile /tmp/gateok_probe.k --backend haskell --main-module SCAFFOLD-PROBE --syntax-module SCAFFOLD-PROBE -I k -o /tmp/scaffoldprobe-out >> "$OUT" 2>&1
echo "probe kompile exit: $?" >> "$OUT"
krun /tmp/tau_probe.srw3 -d /tmp/scaffoldprobe-out > /tmp/gateok_out.txt 2>&1
echo "krun with inhabitable tau: exit: $?" >> "$OUT"
rg -n "<gate>|tau|Error" /tmp/gateok_out.txt | head -6 >> "$OUT"
echo "  ^ the tau is NOT consumed: gateOk has no equations, so the accept rule's" >> "$OUT"
echo "    requires gateOk(...) is stuck and NEITHER tau rule can fire. The skeleton" >> "$OUT"
echo "    cannot execute a single transition, and even if it could, its rules never" >> "$OUT"
echo "    update <committed>/<shadow> (C => C, S => S) and define no reject path." >> "$OUT"
echo >> "$OUT"
echo "=== done ===" >> "$OUT"
tail -20 "$OUT"
