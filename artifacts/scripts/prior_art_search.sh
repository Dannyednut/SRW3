#!/bin/bash
# Prior-art search batch for Round-2 audit item 3 (revised prior-art boundary)
mkdir -p /home/z/my-project/tool-results/prior-art
cd /home/z/my-project/tool-results/prior-art

run() {  # $1 = slug, $2 = query, $3 = num
  echo "== $1 =="
  z-ai function -n web_search -a "{\"query\": \"$2\", \"num\": $3}" -o "pa_$1.json" 2>&1 | tail -1
}

run phylax_credible   "Phylax Systems Credible Layer pre-inclusion assertions how it works" 8
run phylax_tech       "Phylax Credible Layer credible assertions sequencer enforcement cross-contract invariants" 8
run preinclusion      "pre-inclusion enforcement cross-contract invariants blockchain sequencer" 8
run scribble         "Certora Scribble instrumentation runtime assertion smart contract invariants" 6
run erc4337          "ERC-4337 bundler UserOperation validation policy pre-inclusion enforcement" 6
run solcmc           "SolCMC cross-contract smart contract models model checking Solana CAV paper" 6
run smartinv         "SmartInv invariant mining cross-contract smart contracts paper" 6
run firewall         "Vanguard transaction firewall Ethereum runtime verification pre-execution" 6
run enshrined        "enshrined protocol invariants Ethereum consensus validity rules discussion" 8
run sequencer_policy  "rollup sequencer transaction policy invariants enforcement before ordering" 8
run zk_coprocessor   "ZK coprocessor historical state proof Axiom Brevis on-chain invariants" 6
run move_vm          "Move VM resource safety linear types runtime enforcement Sui Aptos" 6
run mev_bundles      "Flashbots bundle constraints builder transaction bundles all-or-nothing invariant" 6
run forta_monitoring "Forta runtime monitoring smart contract threat detection post-hoc" 5
run rv_blockchain    "runtime verification Ethereum transactions invariants before block inclusion paper" 8
echo DONE
