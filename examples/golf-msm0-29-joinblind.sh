#!/usr/bin/env bash
# nlir-golf · msm0 · #29 — "~ is join-blind" (the connective before ~ is inert)
#
# aur-1's #29 showed ~ SYNTHESIZES over & (finds the relationship, doesn't distribute).
# Natural next question: does the CHOICE of join steer the synthesis? Hypothesis:
#   & -> a "combination" synthesis;   | -> a "decision/alternative" synthesis.
# Tested on two database options — and the hypothesis is FALSE:
#
#   ~(a&b)  =>  "Postgres offers strong consistency and rich SQL, while MongoDB
#               offers flexible schemas and easy horizontal scaling."
#   ~(a|b)  =>  "Postgres offers strong consistency and rich SQL, while MongoDB
#               offers flexible schemas and easy horizontal scaling."     (IDENTICAL)
#
# The intermediate join text differs ("…and…" vs "…or…"), but ~ collapses both to the
# SAME "while X, Y" contrast. LAW: ~ is JOIN-BLIND — ~(a JOIN b) depends on a and b,
# NOT on JOIN. A synthesizing op re-reads the operands' relationship and discards the
# connective, so the join before ~ is semantically inert.
#
# That's WHY ~-over-& (aur-1 #29) and ~-over-| give the same result: the join was
# never the point — the operand relationship is. (Contrast the CONTENT extractors:
# ~ ignores the connective just as it ignores register (#28) and framing (#27) —
# ~ keeps converging on the underlying relation.)
set -euo pipefail
cd "$(dirname "$0")/.."
NLIR="${NLIR:-./target/release/nlir}"
[ -x "$NLIR" ] || { echo "build first: cargo build --release (or set NLIR=...)"; exit 1; }
CFG="${NLIR_CONFIG:-config.example.yaml}"
if [ -z "${LITELLM_MASTER_KEY:-}" ] && [ -n "${CACOPHONY_LITELLM_MASTER_KEY_FILE:-}" ]; then
  export LITELLM_MASTER_KEY="$(cat "$CACOPHONY_LITELLM_MASTER_KEY_FILE")"
fi

say() { printf '\n\033[1m%s\033[0m\n' "$1"; }
run() { "$NLIR" --config "$CFG" --mode llm -e "$1" --quiet; }
A='Postgres gives strong consistency and rich SQL'
B='MongoDB gives flexible schemas and easy horizontal scaling'

say 'does the join steer the synthesis? ~(a&b) vs ~(a|b) on the same two options'
printf '  ~(a&b) => '; run "~('$A'&'$B')"
printf '  ~(a|b) => '; run "~('$A'|'$B')"
say "identical — ~ is join-blind: it re-synthesizes the operand relationship, the &/| connective is inert."
