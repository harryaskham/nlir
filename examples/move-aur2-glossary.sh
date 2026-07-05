#!/usr/bin/env bash
# nlir POWER-MOVE (aur-2) — "the glossary entry": explain a term BOTH ways at once — a crisp precise
# definition AND a plain-language analogy. For docs, onboarding, a README glossary, teaching.
#
# THE MOVE (reusable):
#     [ ~(>'TERM') , :'TERM' ]
#       └ a length-controlled definition   └ a plain analogy for the same term
#     └───────────── a list: the definition, then the analogy
#
# Every good glossary entry has two halves: what it precisely MEANS, and what it's LIKE. This move
# gives you both from just the term. ~(>'TERM') expands then distils to one crisp accurate sentence
# (plain > alone OVERSHOOTS into an essay — the ~ reins it in); :'TERM' on a bare term produces the
# intuitive analogy. Together: rigor + intuition, side by side. (Note: bare `~>` is now the IMPLICATION
# operator, so the explicit `~(>…)` compose is how you get length-controlled expand.)
#
# Filled example:
#   [~(>'idempotency'), :'idempotency']
#
# Real output (claude-sonnet-5), definition then analogy:
#   "Idempotency means an operation produces the same result no matter how many times it's performed,
#    which is essential for safely handling retries in distributed systems and APIs."
#   "Doing something more than once gives the same result as doing it just one time — like pressing an
#    elevator button five times still only sends it to one floor."
#
# REUSE IT:  [~(>'<term>'), :'<term>']   (works for any concept: 'a mutex', 'load balancing', 'escrow')
set -euo pipefail
cd "$(dirname "$0")/.."
NLIR="${NLIR:-target/release/nlir}"
CTX="$(mktemp)"; trap 'rm -f "$CTX"' EXIT

EXPR="[~(>'idempotency'),:'idempotency']"

echo "move:       the glossary entry -- [~(>'TERM'), :'TERM']  (line 1 = crisp definition, line 2 = plain analogy)"
echo "---"
"$NLIR" --context-file "$CTX" --mode llm -e "$EXPR"
