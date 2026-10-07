"""Phase 1H smoke test: drive Geth v1.17.7 through one Amsterdam payload
via engine_forkchoiceUpdatedV4 -> engine_getPayloadV6 -> engine_newPayloadV5.
"""
import hashlib
import json
import sys
import time

sys.path.insert(0, "/home/z/my-project/srw3-work/phase1h/python")
from engine_client import Devnet  # noqa: E402

HERE = "/home/z/my-project/srw3-work/phase1h"


def main() -> int:
    jwt = open(f"{HERE}/devnet/jwt.hex").read().strip()
    dn = Devnet("http://127.0.0.1:8551", "http://127.0.0.1:8545", jwt)
    print("chainId:", dn.chain_id())
    head = dn.head()
    print("genesis head:", head["hash"], "number:", int(head["number"], 16))

    attrs = {
        "timestamp": hex(int(time.time()) + 1),
        "prevRandao": "0x" + hashlib.sha256(b"srw3-slot-1").hexdigest(),
        "suggestedFeeRecipient": "0x9965507D1a55bcC269514583FDeE676187EF7C6A",
        "withdrawals": [],
        "parentBeaconBlockRoot": "0x" + hashlib.sha256(b"srw3-beacon-1").hexdigest(),
        "slotNumber": hex(1),
    }
    fcu1 = dn.forkchoice_updated_v4(head["hash"], head["hash"], head["hash"], attrs)
    print("fcuV4(build):", json.dumps(fcu1))
    if not fcu1.get("payloadId"):
        print("NO payloadId — aborting")
        return 1
    pid = fcu1["payloadId"]

    env = dn.get_payload_v6(pid)
    payload = env["executionPayload"]
    print("payload keys:", sorted(payload.keys()))
    print("blockHash:", payload["blockHash"])
    print("has blockAccessList:", "blockAccessList" in payload,
          "len:", len(payload.get("blockAccessList", "")) // 2, "bytes")
    print("slotNumber:", payload.get("slotNumber"))

    res = dn.new_payload_v5(payload, [], attrs["parentBeaconBlockRoot"], [])
    print("newPayloadV5:", json.dumps(res))

    fcu2 = dn.forkchoice_updated_v4(payload["blockHash"], payload["blockHash"],
                                    payload["blockHash"])
    print("fcuV4(canonicalize):", json.dumps(fcu2))

    new_head = dn.head()
    print("new head:", new_head["hash"], "number:", int(new_head["number"], 16),
          "stateRoot:", new_head["stateRoot"])

    bodies = dn.payload_bodies_by_hash_v2([payload["blockHash"]])
    bal_present = bodies and bodies[0] and bodies[0].get("blockAccessList") is not None
    print("payloadBodiesV2 BAL present:", bal_present)

    with open(f"{HERE}/transcripts/engine/smoke_engine.json", "w") as f:
        json.dump({"engine": dn.engine.log, "rpc": dn.rpc.log}, f, indent=1)
    print("transcript written")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
