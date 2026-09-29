# evm_min2.srw3evm — KEVM minimal rejection/restore demo.
# CHANGELOG (theorem-closure pass, 2026-09-28): the #w3Run target account was
# updated from 1 to 4097 (w3Oracle). The original target predates the driver's
# account renaming (srw3-kevm.k now creates 4097/4098/4099 only), so the old
# program stuck at SSTORE on the no-longer-existing account 1. The demo's
# verdict semantics are UNCHANGED from the canonical record (round-1
# transcripts/evm_minimal_reject.txt): one declared write of 100 to slot 0,
# the applicable chain obligation IOL fails on the prospective, the gate
# REJECTS and restores all committed storages (n=0, h=-1). Diffable via
# srw3-work git history (this directory is project-added, not baseline zip).
