# evm_gen_positive.srw3evm / evm_gen_overflow.srw3evm — Phase-1B generalized
# binding demos (additive extension module k/kevm/srw3-gen-binding.k).
#
# Contract: root 4097 writes price slot0=100 and aggregate budget slot2=100;
# delegate 4098 writes b1 to slot2; delegate 4099 writes b2 to slot2; both
# write the alias-pair slot3 (one logical resource mirrored across two
# physical keys). Base Phase-0 demo data on slots 0/1 is kept (IOL/ILD/IOLD
# unchanged and satisfied, mirroring evm_positive's committed snapshot).
#
#   evm_gen_positive : b1=30, b2=40 (30+40=70 <= 100), alias 7==7
#                      -> COMMIT (n=1, head advances; storages committed)
#   evm_gen_overflow : b1=60, b2=50 (60+50=110 > 100)  -> REJECT+RESTORE
#                      (all committed storages restored; n=0, h=-1)
#
# Verdict expected under BOTH backends (structural cells equal). The gate
# mechanism is unchanged: #w3GateG evaluates ONE conjunction (#w3OblG) over
# REAL prospective storage — CM2/CM3 appear purely as additional evaluated
# obligation classes (mandate Part VI architecture claim).
