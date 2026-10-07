"""SRW3 Phase 1H — Engine API client (CL-side).

Speaks JWT-authenticated JSON-RPC to the Geth Engine API (authrpc, port 8551)
and to the public RPC (port 8545).  The harness plays the role of the
consensus client: engine_forkchoiceUpdatedV4 -> engine_getPayloadV6 ->
engine_newPayloadV5 -> engine_forkchoiceUpdatedV4.

Only Python stdlib is required (JWT = HMAC-SHA256 per Engine API auth spec).
"""
from __future__ import annotations

import base64
import hashlib
import hmac
import json
import os
import time
import urllib.request
from typing import Any

ZERO_HASH = "0x" + "00" * 32


def _b64url(data: bytes) -> str:
    return base64.urlsafe_b64encode(data).rstrip(b"=").decode()


class JsonRpc:
    """Plain JSON-RPC over HTTP."""

    def __init__(self, url: str):
        self.url = url
        self._id = 0
        self.log: list[dict] = []

    def call(self, method: str, params: list | dict) -> Any:
        self._id += 1
        body = {"jsonrpc": "2.0", "id": self._id, "method": method, "params": params}
        req = urllib.request.Request(
            self.url,
            data=json.dumps(body).encode(),
            headers={"Content-Type": "application/json"},
        )
        t0 = time.perf_counter()
        with urllib.request.urlopen(req, timeout=120) as resp:
            raw = resp.read()
        dt = time.perf_counter() - t0
        out = json.loads(raw)
        self.log.append(
            {"method": method, "params": params, "resp": out, "ms": round(dt * 1000, 3)}
        )
        if "error" in out:
            raise RuntimeError(f"{method} error: {out['error']}")
        return out.get("result")


class EngineClient(JsonRpc):
    """JWT-authenticated Engine API client."""

    def __init__(self, url: str, jwt_secret_hex: str):
        super().__init__(url)
        self.secret = bytes.fromhex(jwt_secret_hex)

    def _token(self) -> str:
        header = _b64url(json.dumps({"alg": "HS256", "typ": "JWT"}).encode())
        claim = _b64url(json.dumps({"iat": int(time.time())}).encode())
        signing = f"{header}.{claim}".encode()
        sig = _b64url(hmac.new(self.secret, signing, hashlib.sha256).digest())
        return f"{header}.{claim}.{sig}"

    def call(self, method: str, params: list | dict) -> Any:
        self._id += 1
        body = {"jsonrpc": "2.0", "id": self._id, "method": method, "params": params}
        req = urllib.request.Request(
            self.url,
            data=json.dumps(body).encode(),
            headers={"Content-Type": "application/json", "Authorization": f"Bearer {self._token()}"},
        )
        t0 = time.perf_counter()
        with urllib.request.urlopen(req, timeout=120) as resp:
            raw = resp.read()
        dt = time.perf_counter() - t0
        out = json.loads(raw)
        self.log.append(
            {"method": method, "params": params, "resp": out, "ms": round(dt * 1000, 3)}
        )
        if "error" in out:
            raise RuntimeError(f"{method} error: {out['error']}")
        return out.get("result")


class Devnet:
    """Engine + public RPC bundle for one Geth devnet instance."""

    def __init__(self, engine_url: str, rpc_url: str, jwt_secret_hex: str):
        self.engine = EngineClient(engine_url, jwt_secret_hex)
        self.rpc = JsonRpc(rpc_url)

    # ---------- convenience wrappers ----------

    def forkchoice_updated_v4(self, head: str, finalized: str, safe: str,
                              attributes: dict | None = None) -> dict:
        state = {
            "headBlockHash": head,
            "safeBlockHash": safe or head,
            "finalizedBlockHash": finalized or ZERO_HASH,
        }
        params = [state, attributes] if attributes is not None else [state]
        return self.engine.call("engine_forkchoiceUpdatedV4", params)

    def get_payload_v6(self, payload_id: str) -> dict:
        return self.engine.call("engine_getPayloadV6", [payload_id])

    def new_payload_v5(self, execution_payload: dict,
                       expected_blob_versioned_hashes: list | None = None,
                       parent_beacon_block_root: str = ZERO_HASH,
                       execution_requests: list | None = None) -> dict:
        return self.engine.call(
            "engine_newPayloadV5",
            [
                execution_payload,
                expected_blob_versioned_hashes or [],
                parent_beacon_block_root,
                execution_requests or [],
            ],
        )

    def payload_bodies_by_hash_v2(self, hashes: list[str]) -> list:
        return self.engine.call("engine_getPayloadBodiesByHashV2", [hashes])

    # ---------- eth / debug ----------

    def block_by_hash(self, h: str, full: bool = True) -> dict | None:
        return self.rpc.call("eth_getBlockByHash", [h, full])

    def block_receipts(self, h: str) -> list | None:
        return self.rpc.call("eth_getBlockReceipts", [h])

    def chain_id(self) -> int:
        return int(self.rpc.call("eth_chainId", []), 16)

    def head(self) -> dict:
        return self.rpc.call("eth_getBlockByNumber", ["latest", False])

    def send_raw_tx(self, raw: str) -> str:
        return self.rpc.call("eth_sendRawTransaction", [raw])

    def trace_block_call_tracer(self, h: str) -> Any:
        return self.rpc.call(
            "debug_traceBlockByHash",
            [h, {"tracer": "callTracer",
                 "tracerConfig": {"withLog": True, "onlyTopCall": False}}],
        )

    def trace_block_prestate_diff(self, h: str) -> Any:
        return self.rpc.call(
            "debug_traceBlockByHash",
            [h, {"tracer": "prestateTracer",
                 "tracerConfig": {"diffMode": True}}],
        )

    def trace_block_structlog(self, h: str) -> Any:
        return self.rpc.call(
            "debug_traceBlockByHash",
            [h, {"disableStorage": False, "disableStack": True,
                 "disableMemory": True}],
        )

    def raw_block(self, h: str) -> str:
        return self.rpc.call("debug_getRawBlock", [h])
