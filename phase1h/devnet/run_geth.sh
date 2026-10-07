#!/usr/bin/env bash
# SRW3 Phase 1H devnet launcher — Geth v1.17.7 post-merge Amsterdam devnet.
# The execution client runs with NO miner; all block production goes through
# the Engine API (authrpc) driven by the SRW3 CL-simulator harness.
set -u
HERE="$(cd "$(dirname "$0")" && pwd)"
GETH_DIR=/home/z/my-project/tools/geth/geth-linux-amd64-1.17.7-3d858f85
GETH="$GETH_DIR/geth"
CHAIN="$HERE/chain"
LOG="${1:-$HERE/../transcripts/client/geth.log}"

mkdir -p "$(dirname "$LOG")"
pkill -f "geth --datadir" 2>/dev/null || true
sleep 1

nohup "$GETH" \
  --datadir "$CHAIN" \
  --networkid 93471 \
  --nat none --maxpeers 0 --nodiscover --syncmode full \
  --gcmode archive \
  --http --http.addr 127.0.0.1 --http.port 8545 \
  --http.api eth,web3,net,debug,txpool,admin \
  --http.corsdomain '*' --http.vhosts '*' \
  --authrpc.addr 127.0.0.1 --authrpc.port 8551 \
  --authrpc.vhosts '*' --authrpc.jwtsecret "$HERE/jwt.hex" \
  --rpc.allow-unprotected-txs \
  --txpool.globalslots 20000 --txpool.globalqueue 20000 \
  --verbosity 3 \
  >> "$LOG" 2>&1 &

echo "geth pid: $!"
echo "$!" > "$HERE/geth.pid"
