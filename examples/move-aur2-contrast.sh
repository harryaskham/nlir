#!/usr/bin/env bash
# nlir POWER-MOVE (aur-2) — "the compare-and-contrast": get the ONE crisp sentence that says how two
# concepts actually differ. The classic "what's the difference between X and Y?" — for docs, interview
# prep, teaching, design reviews.
#
# THE MOVE (reusable):
#     ~>'the difference between X and Y'
#     └ ~> = expand THEN distil: draws out the real distinction, in one accurate sentence (not an essay)
#
# Plain > alone would spill into a multi-paragraph essay; ~> reins it to the single sentence that names
# what SEPARATES them (ownership, timing, scope — whatever the true axis is). Add a plain version with :
#   [~>'the difference between X and Y', :'the difference between X and Y, in plain terms']
# and you get the technical contrast + an everyday analogy for it.
#
# Filled example:
#   ~>'the difference between a mutex and a semaphore'
#
# Real output (claude-sonnet-5):
#   "A mutex enforces ownership-based exclusive locking for a single resource, while a semaphore uses a
#    non-owned counter to allow flexible, multi-threaded access to a pool of resources."
#
# REUSE IT:  ~>'the difference between <X> and <Y>'   (pair with :'...' for a plain-language version)
set -euo pipefail
cd "$(dirname "$0")/.."
NLIR="${NLIR:-target/release/nlir}"
CTX="$(mktemp)"; trap 'rm -f "$CTX"' EXIT

EXPR="~>'the difference between a mutex and a semaphore'"

echo "move:       the compare-and-contrast -- ~>'the difference between X and Y'  (one crisp distinction)"
echo "---"
"$NLIR" --context-file "$CTX" --mode llm -e "$EXPR"
