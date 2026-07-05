#!/usr/bin/env bash
# nlir POWER-MOVE (aur-2) — "the compare-and-contrast": one crisp sentence on how two things differ.
#
# THE MOVE (reusable):
#     ~ ( > 'the difference between X and Y' )
#     └ ~(>…) = expand THEN distil: draw out the real distinction, reined into one accurate sentence
#
# `> alone` overshoots into a multi-paragraph essay; wrapping it as `~(>…)` distils the expansion to
# the single sentence that names the actual distinction. (Note: since Harry's change, bare `~>` is the
# IMPLICATION operator — use the explicit `~(>…)` compose for length-controlled expand.)
#
# Filled example:
#   ~(>'the difference between a mutex and a semaphore')
#
# Real output (claude-sonnet-5):
#   "A mutex enforces exclusive, ownership-based access to a single resource, while a semaphore uses a
#    counter to manage and signal availability across multiple threads without ownership."
#
# REUSE IT:  ~(>'the difference between <X> and <Y>')   (pair with :'…' for a plain-language version)
set -euo pipefail
cd "$(dirname "$0")/.."
NLIR="${NLIR:-target/release/nlir}"
CTX="$(mktemp)"; trap 'rm -f "$CTX"' EXIT

EXPR="~(>'the difference between a mutex and a semaphore')"

echo "move:       the compare-and-contrast -- ~(>'the difference between X and Y')  (one crisp distinction)"
echo "---"
"$NLIR" --context-file "$CTX" --mode llm -e "$EXPR"
