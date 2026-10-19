#!/usr/bin/env bash
# SRW3 Phase 1M — Workstream B vector validation runner for Keccak256T.
# Usage: bash kek_vector_run.sh <kompiled-dir> <out-log> <label> [timeout-per-vec]
set -u
DEF="$1"; OUT="$2"; LABEL="$3"; TMO="${4:-600}"
WORK=$(mktemp -d)
VECS=(
  '|c5d2460186f7233c927e7db2dcc703c0e500b653ca82273b7bfad8045d85a470'
  'abc|4e03657aea45a94fc7d47ba826c8d667c0d1e6e33a64a036ec44f58fa12d6c45'
)
X135=$(printf 'x%.0s' $(seq 1 135))
X136=$(printf 'x%.0s' $(seq 1 136))
X137=$(printf 'x%.0s' $(seq 1 137))
FOX="The quick brown fox jumps over the lazy dog"
VECS+=("$X135|16570bdb055e663ea1cb57ac6f09194f4bc7b7070847971fc0b86710366dc34f")
VECS+=("$X136|50da8ef3747b7a7f01d08563aa11c72a2a668563fb928adc6e8d2a1ab4e36096")
VECS+=("$X137|01e0852c139fa337a5d3f746ab3b2d3400442195225e2f10c34702f8f37ae8d3")
VECS+=("$FOX|4d741b6f1eb29cb2a9b9911c82f56fa8d73b04959d3d9d222895df6c0b28aa15")
VECS+=("$FOX$FOX$FOX$FOX$FOX|2bca465790fbe952f1e3768e10357fe439df1a1253d3dbfaf2a2a583911c68d8")

{
  echo "# Keccak256T vector validation — $LABEL"
  echo "# definition dir: $DEF"
  echo "# date: $(date -u +%Y-%m-%dT%H:%M:%SZ)"
  echo "# 7 vectors: empty, abc, 135/136/137-byte boundaries, 43-byte, 215-byte (two-block)"
  echo "# reference digests cross-checked: kek_ref.py == pycryptodome"
} > "$OUT"

PASS=0; FAIL=0
i=0
for v in "${VECS[@]}"; do
  i=$((i+1))
  msg="${v%%|*}"; want="${v##*|}"
  printf 'kekT("%s")' "$msg" > "$WORK/pgm.k"
  raw=$(timeout "$TMO" krun "$WORK/pgm.k" -d "$DEF" 2>&1); rc=$?
  got=$(echo "$raw" | python3 "$(dirname "$0")/decode_kbytes.py")
  nlen=$(echo -n "$msg" | wc -c)
  if [ "$got" = "$want" ] && [ $rc -eq 0 ]; then
    st="PASS"; PASS=$((PASS+1))
  else
    st="FAIL"; FAIL=$((FAIL+1))
    echo "$raw" > "$OUT.fail$i"
  fi
  {
    echo "[$st] vector $i (len=$nlen, krun rc=$rc)"
    echo "  want: $want"
    echo "  got : ${got:-<none>}"
  } >> "$OUT"
done
echo "# RESULT: $PASS PASS / $FAIL FAIL over 7 vectors ($LABEL)" >> "$OUT"
cat "$OUT"
[ "$FAIL" -eq 0 ]
