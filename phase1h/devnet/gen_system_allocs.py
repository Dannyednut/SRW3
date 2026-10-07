"""Generate phase1h/devnet/genesis.json with the post-Prague system contracts
(extracted programmatically from the pinned geth v1.17.7 source so no
transcription errors are possible)."""
import json
import re

SRC = "/home/z/my-project/tools/src/geth-src/params/protocol_params.go"
OUT = "/home/z/my-project/srw3-work/phase1h/devnet/genesis.json"

src = open(SRC).read()

SYSTEM = [
    "BeaconRootsAddress", "HistoryStorageAddress", "WithdrawalQueueAddress",
    "ConsolidationQueueAddress", "BuilderDepositAddress", "BuilderExitAddress",
    "DeterministicFactoryAddress",
]

alloc_add = {}
for name in SYSTEM:
    m = re.search(rf"{name}\s*=\s*common\.HexToAddress\(\"(0x[0-9a-fA-F]+)\"\)", src)
    addr = m.group(1)
    code_name = name.replace("Address", "Code")
    m2 = re.search(rf"{code_name}\s*=\s*common\.FromHex\(\"(?:0x)?([0-9a-fA-F]+)\"\)", src)
    code = m2.group(1)
    alloc_add[addr] = {"nonce": "0x1", "code": "0x" + code, "balance": "0x0"}
    print(f"{name}: {addr} code {len(code) // 2} bytes")

gen = json.load(open(OUT))
gen["alloc"].update(alloc_add)
json.dump(gen, open(OUT, "w"), indent=2)
print("genesis.json updated with", len(alloc_add), "system contracts")
