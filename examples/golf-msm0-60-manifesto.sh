#!/usr/bin/env bash
# nlir-golf · msm0 · #60 (MILESTONE) — "the manifesto" (nlir describing itself)
#
# Sixty concepts in, the machine states its own thesis. Assign the two halves of the whole
# theory, interpolate them into one sentence, and formalise it:
#
#   sel="ranges address which turns to read"
#   tra="operators reshape what you read"
#   @"the whole of nlir is two moves: SELECT, where $sel, and TRANSFORM, where $tra"
#   │  │                                        └ $sel / $tra   interpolated at eval (#17)
#   │  └ "…" a cooked template with two interpolation slots
#   └── @( … )   formalise the assembled sentence into a manifesto
#
# Real output (claude-sonnet-5):
#   "NLIR fundamentally consists of two operations: SELECT, in which ranges specify which
#    turns are to be read, and TRANSFORM, in which operators reshape the content thus read."
#
# Every one of the 60 concepts is an instance of that one sentence: a range SELECTs which
# part of a conversation to look at, the operator basis TRANSFORMs what you address,
# coercion feeds the values, and the transform is input-bound (#59 — a lens, not an oracle).
# Two assignments, one template, one operator — the machine, describing the machine.
set -euo pipefail
cd "$(dirname "$0")/.."
NLIR="${NLIR:-./target/release/nlir}"
[ -x "$NLIR" ] || { echo "build first: cargo build --release (or set NLIR=...)"; exit 1; }
CFG="${NLIR_CONFIG:-config.example.yaml}"
if [ -z "${LITELLM_MASTER_KEY:-}" ] && [ -n "${CACOPHONY_LITELLM_MASTER_KEY_FILE:-}" ]; then
  export LITELLM_MASTER_KEY="$(cat "$CACOPHONY_LITELLM_MASTER_KEY_FILE")"
fi

say() { printf '\n\033[1m%s\033[0m\n' "$1"; }
say 'THE MANIFESTO   sel="ranges address which turns to read" ; tra="operators reshape what you read" ; @"…SELECT, where $sel, and TRANSFORM, where $tra"'
printf '  => '
"$NLIR" --config "$CFG" --mode llm --quiet -e 'sel="ranges address which turns to read";tra="operators reshape what you read";@"the whole of nlir is two moves: SELECT, where $sel, and TRANSFORM, where $tra"'
say "every one of the 60 concepts is an instance of that sentence. The machine, describing the machine."
