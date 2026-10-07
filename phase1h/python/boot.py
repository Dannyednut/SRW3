"""SRW3 Phase 1H — devnet boot + deployment + policy materialization.

Deploys SimpleOracle, MiniLending, SimpleLiquidator through REAL Engine API
payloads, then writes srw3_policy.json (with the real deployed addresses)
and the governance-side deployment.json pinning its digest.
"""
from __future__ import annotations

import json
import os

from eth_utils import keccak

import txkit
from txkit import TxPlan, acct, call_data, selector
from cl_sim import ChainSim
from engine_client import Devnet

HERE = "/home/z/my-project/srw3-work/phase1h"
BIN = f"{HERE}/fixtures/contracts"
CHAIN_ID = 93471
CAP = 100 * 10**18
DEPOSIT = 1000 * 10**18


def boot_devnet() -> Devnet:
    jwt = open(f"{HERE}/devnet/jwt.hex").read().strip()
    return Devnet("http://127.0.0.1:8551", "http://127.0.0.1:8545", jwt)


class Boot:
    def __init__(self, dn: Devnet):
        self.dn = dn
        self.sim = ChainSim.create(dn, CHAIN_ID)
        self.deploy_payloads: list[dict] = []
        self._capture = True
        self.oracle = None
        self.lending = None
        self.liquidator = None
        self.owner = acct(0).address
        self.nonces: dict[str, int] = {}

    def nonce_of(self, addr: str) -> int:
        if addr not in self.nonces:
            r = self.dn.rpc.call("eth_getTransactionCount", [addr, "latest"])
            self.nonces[addr] = int(r, 16)
        return self.nonces[addr]

    def bump(self, addr: str, k: int = 1) -> None:
        self.nonces[addr] = self.nonce_of(addr) + k

    def deploy_block(self, sender: int, binfile: str, args_enc: bytes,
                     label: str):
        plan = TxPlan(sender, CHAIN_ID, self.nonce_of(acct(sender).address))
        code = open(binfile).read().strip()
        if not code.startswith("0x"):
            code = "0x" + code
        plan.add(acct(sender), None, 0, bytes.fromhex(code[2:]) + args_enc,
                 label, gas=3_000_000)
        self.bump(acct(sender).address)
        return plan

    def deploy_all(self):
        self.deploy_payloads = []
        # wrap sim.produce to capture deploy payload bytes
        orig_produce = self.sim.produce

        self.deploy_rebuilt: list[bool] = []

        def capturing_produce(*a, **k):
            res = orig_produce(*a, **k)
            if res.payload is not None:
                self.deploy_payloads.append(res.payload)
                self.deploy_rebuilt.append(bool(getattr(res, "rebuilt", False)))
            return res

        self.sim.produce = capturing_produce
        # 1) SimpleOracle (no ctor args)
        res = self.sim.produce(
            self.deploy_block(0, f"{BIN}/SimpleOracle.bin", b"", "deploy oracle").raws)
        assert res.new_payload_status["status"] == "VALID", res.new_payload_status
        txh = self.dn.block_by_hash(res.payload["blockHash"])["transactions"][0]["hash"]
        rec = self.dn.rpc.call("eth_getTransactionReceipt", [txh])
        self.oracle = rec["contractAddress"]

        # 2) MiniLending(oracle, cap)
        enc = enc_ctor(["address", "uint256"], [self.oracle, CAP])
        res = self.sim.produce(
            self.deploy_block(0, f"{BIN}/MiniLending.bin", enc, "deploy lending").raws)
        assert res.new_payload_status["status"] == "VALID", res.new_payload_status
        rec = self.dn.rpc.call(
            "eth_getTransactionReceipt",
            [self.dn.block_by_hash(res.payload["blockHash"])["transactions"][0]["hash"]])
        self.lending = rec["contractAddress"]

        # 3) SimpleLiquidator(oracle, lending)
        enc = enc_ctor(["address", "address"], [self.oracle, self.lending])
        res = self.sim.produce(
            self.deploy_block(0, f"{BIN}/SimpleLiquidator.bin", enc, "deploy liq").raws)
        assert res.new_payload_status["status"] == "VALID", res.new_payload_status
        rec = self.dn.rpc.call(
            "eth_getTransactionReceipt",
            [self.dn.block_by_hash(res.payload["blockHash"])["transactions"][0]["hash"]])
        self.liquidator = rec["contractAddress"]
        self.sim.produce = orig_produce  # stop capturing

    # ---------- policy ----------

    def policy_object(self) -> dict:
        owner_slot_val = "0x" + self.owner.removeprefix("0x").lower().rjust(64, "0")
        return {
            "policyVersion": "srw3-policy-1h-v1",
            "applicationSet": [self.oracle, self.lending, self.liquidator],
            "invariants": [
                {
                    "id": "INV-AGG-CAP",
                    "type": "slot_le",
                    "contract": self.lending,
                    "slot": "0x02",       # totalBorrowed
                    "boundSlot": "0x03",  # borrowCap
                    "note": "aggregate CM3-style authority/cap invariant; "
                            "intentionally NOT enforced by the contract",
                },
                {
                    "id": "INV-ORACLE-OWNER-IMMUTABLE",
                    "type": "slot_unchanged",
                    "contract": self.oracle,
                    "slot": "0x02",       # owner
                    "expected": owner_slot_val,
                },
            ],
            "interactionGraph": {
                "obligations": [
                    {
                        "id": "IO-ORACLE-ORDER",
                        "type": "write_before_read_same_block",
                        "writer": {"contract": self.oracle,
                                   "fnSel": "0x" + selector("setPrice(uint256)").hex()},
                        "reader": {"contract": self.lending,
                                   "fnSel": "0x" + selector("borrow(uint256)").hex()},
                        "note": "if a block contains both a borrow and a "
                                "setPrice, the price write must be ordered "
                                "before the borrow",
                    }
                ]
            },
            "authorityConfiguration": {
                "protocolRoot": {"kind": "devnet-genesis", "chainId": CHAIN_ID},
                "authorizedEvidenceSources": ["engine-api-execution"],
                "authorizedProofTypes": ["client-re-execution"],
            },
            "executionFragment": {
                "name": "evm-storage-call-log-v1",
                "events": ["READ", "WRITE", "CALL", "LOG"],
                "ordering": "tx order (receipt order); canonical (addr,slot) within tx",
            },
        }

    def write_policy(self, policy_dir: str, version_suffix: str = "") -> tuple[str, str]:
        pol = self.policy_object()
        if version_suffix:
            pol["policyVersion"] += version_suffix
        os.makedirs(policy_dir, exist_ok=True)
        from policy import digest_of
        d = digest_of(pol, drop=["policyDigest"])
        pol["policyDigest"] = d
        pol_path = os.path.join(policy_dir, "srw3_policy.json")
        json.dump(pol, open(pol_path, "w"), indent=2)
        dep = {
            "deploymentVersion": "srw3-1h-deployment-v1",
            "chainId": CHAIN_ID,
            "genesisHash": self.dn.head()["hash"],
            "pinnedPolicyDigest": d,
        }
        dep_path = os.path.join(policy_dir, "deployment.json")
        json.dump(dep, open(dep_path, "w"), indent=2)
        return pol_path, dep_path

    # ---------- scenario helpers ----------

    def txs(self, sender: int, calls: list[tuple[str, str, tuple, int]],
            label: str = "") -> TxPlan:
        """calls: list of (to, sig, args, value)."""
        plan = TxPlan(sender, CHAIN_ID, self.nonce_of(acct(sender).address))
        for (to, sig, args, value) in calls:
            data = call_data(sig, *args) if sig else b""
            plan.add(acct(sender), to, value, data, label or (sig or "transfer"),
                     gas=1_000_000)
        self.bump(acct(sender).address, len(calls))
        return plan


def enc_ctor(types: list[str], vals: list) -> bytes:
    """Minimal ABI ctor encoding for (address, uint256) tuples."""
    out = b""
    for t, v in zip(types, vals):
        if t == "address":
            out += bytes.fromhex(v.removeprefix("0x").rjust(64, "0"))
        elif t == "uint256":
            out += int(v).to_bytes(32, "big")
        else:
            raise TypeError(t)
    return out
