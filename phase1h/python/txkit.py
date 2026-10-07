"""SRW3 Phase 1H — transaction helpers: raw signing (eth_account), function
encoding (manual ABI), deployment through the real txpool + payload flow."""
from __future__ import annotations

from eth_account import Account
from eth_utils import keccak, to_checksum_address

Account.enable_unaudited_hdwallet_features()

# The ten standard deterministic dev accounts (anvil/hardhat mnemonic),
# derived at runtime — addresses are guaranteed to match genesis.json.
MNEMONIC = "test test test test test test test test test test test junk"

_acct_cache: dict[int, Account] = {}


def acct(i: int) -> Account:
    if i not in _acct_cache:
        _acct_cache[i] = Account.from_mnemonic(
            MNEMONIC, account_path=f"m/44'/60'/0'/0/{i}")
    return _acct_cache[i]


def all_accounts() -> list[Account]:
    return [acct(i) for i in range(10)]


def selector(sig: str) -> bytes:
    return keccak(sig.encode())[:4]


def enc_uint(v: int) -> bytes:
    return v.to_bytes(32, "big")


def enc_addr(a: str) -> bytes:
    return bytes.fromhex(a.removeprefix("0x").rjust(64, "0"))


def call_data(sig: str, *args) -> bytes:
    data = selector(sig)
    for a in args:
        if isinstance(a, int):
            data += enc_uint(a)
        elif isinstance(a, str) and a.startswith("0x") and len(a) == 42:
            data += enc_addr(a)
        else:
            raise TypeError(f"cannot encode {a!r}")
    return data


def sign_tx(priv: str, nonce: int, to: str | None, value: int, data: bytes,
            gas: int = 400_000, gas_price: int = 1_000_000_000,
            chain_id: int = 93471) -> str:
    """Legacy EIP-155 transaction."""
    tx = {
        "nonce": nonce,
        "gasPrice": gas_price,
        "gas": gas,
        "chainId": chain_id,
        "value": value,
        "data": data,
    }
    tx["to"] = to_checksum_address(to) if to else ""
    signed = Account.sign_transaction(tx, priv)
    raw = signed.raw_transaction.hex() if hasattr(signed, "raw_transaction") \
        else signed["rawTransaction"].hex()
    return raw if raw.startswith("0x") else "0x" + raw


class TxPlan:
    """A deterministic batch of transactions from one sender."""

    def __init__(self, sender_index: int, chain_id: int, start_nonce: int):
        self.sender_index = sender_index
        self.chain_id = chain_id
        self.nonce = start_nonce
        self.raws: list[str] = []
        self.desc: list[str] = []

    def add(self, priv_acct: Account, to: str | None, value: int, data: bytes,
            desc: str, gas: int = 400_000, gas_price: int = 1_000_000_000):
        raw = sign_tx(priv_acct.key.hex(), self.nonce, to, value, data, gas,
                      gas_price, self.chain_id)
        self.nonce += 1
        self.raws.append(raw)
        self.desc.append(desc)
        return self
