#!/usr/bin/env bash
# Reset the phase1h devnet to a fresh genesis and start Geth.
set -eu
HERE="$(cd "$(dirname "$0")" && pwd)"
GETH=/home/z/my-project/tools/geth/geth-linux-amd64-1.17.7-3d858f85/geth
pkill -f "geth --datadir" 2>/dev/null || true
sleep 1
rm -rf "$HERE/chain"
"$GETH" --datadir "$HERE/chain" init "$HERE/genesis.json" 2>&1 | tail -1
"$HERE/run_geth.sh" "${1:-}"
sleep 5
curl -s -X POST http://127.0.0.1:8545 -H 'Content-Type: application/json' \
  -d '{"jsonrpc":"2.0","id":1,"method":"eth_blockNumber","params":[]}'
echo
