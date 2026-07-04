#!/usr/bin/env bash
# nlir-golf · msm0 · #57 — "the involution" (! is period-2: negate twice, return home)
#
# The negation operator ! is an INVOLUTION — applying it twice returns you to the start
# (N² = identity). So only the PARITY of the ! count matters:
#
#   !'i agree'    => "i disagree"   (odd  count: negated)
#   !!'i agree'   => "i agree"      (even count: RETURNS to the original)
#   !!!'i agree'  => "i disagree"   (odd  again)
#
# The stack machine walks !!!x as three prefix nodes stacked over one operand — each a real
# negation — and the meaning oscillates with a period of 2, landing back home on every even
# count. This is the operator-DYNAMICS complement of aur-1's ? projection (P²=P, idempotent,
# period 1): ! is an INVOLUTION (N²=I, period 2). Two distinct ways an operator behaves
# under its own repetition — one snaps to a fixed point, the other flips back and forth.
#
# (Fits the repetition-dynamics strand of the theory: ! involutes, @ saturates, ~ intensifies.)
set -euo pipefail
cd "$(dirname "$0")/.."
NLIR="${NLIR:-./target/release/nlir}"
[ -x "$NLIR" ] || { echo "build first: cargo build --release (or set NLIR=...)"; exit 1; }
CFG="${NLIR_CONFIG:-config.example.yaml}"
if [ -z "${LITELLM_MASTER_KEY:-}" ] && [ -n "${CACOPHONY_LITELLM_MASTER_KEY_FILE:-}" ]; then
  export LITELLM_MASTER_KEY="$(cat "$CACOPHONY_LITELLM_MASTER_KEY_FILE")"
fi

say() { printf '\n\033[1m%s\033[0m\n' "$1"; }
run() { printf '  %-14s => ' "$1"; "$NLIR" --config "$CFG" --mode llm -e "$1" --quiet; }
say "! is period-2 — the parity of the negation count is all that survives:"
run "!'i agree'"
run "!!'i agree'"
run "!!!'i agree'"
say "N²=identity: even count returns home, odd count negates. The involution to ?'s projection."
