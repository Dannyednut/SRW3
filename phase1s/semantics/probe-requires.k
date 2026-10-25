// Probe requires shim: pulls the three frozen modules so the probe file
// can require a single path. Never imported by any machine of record.

requires "../../phase1q/semantics/abs-machine-q.k"
requires "../../phase1r/semantics/abs-machine-qs.k"
requires "../../phase1p/semantics/abs-machine-tdrr.k"

module SRW3N-REL-PROBE-BASE
  imports SRW3N-ABS-QS
  imports SRW3N-ABS-TDRR
endmodule
