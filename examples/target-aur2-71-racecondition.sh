#!/usr/bin/env bash
# nlir TARGET-GOLF (aur-2 #71) — reverse game via ~> (summary of expand): a dense
# TECHNICAL one-liner defining a concurrency bug from a 28-char seed.
#
# TARGET (~195 chars):
#   "A race condition is a bug where two parts of a program access shared data at the
#    same time, and the result depends on which one happens to run first -- so it works
#    sometimes and fails other times."
#
# EXPRESSION (28 chars):
#   ~>'what is a race condition'
#
# Real output (claude-sonnet-5):
#   "A race condition is a bug where a program's correctness depends on unpredictable
#    timing between concurrent threads/processes accessing shared state without proper
#    synchronization, leading to issues like lost updates or security flaws, which are
#    typically prevented using synchronization tools like locks, mutexes, and atomic
#    operations."
# Closeness: same core (timing-dependent bug on shared state between concurrent
# threads), and ~> adds the fix (locks/mutexes/atomics) in a deep technical register
# (high). 86% shorter -- 28 characters into a full definition.
set -euo pipefail
cd "$(dirname "$0")/.."
NLIR="${NLIR:-target/release/nlir}"
CTX="$(mktemp)"; trap 'rm -f "$CTX"' EXIT

TARGET="A race condition is a bug where two parts of a program access shared data at the same time, and the result depends on which one happens to run first -- so it works sometimes and fails other times."
EXPR="~>'what is a race condition'"

echo "TARGET (${#TARGET} chars): $TARGET"
echo "EXPR   (${#EXPR} chars): $EXPR"
echo "---"
"$NLIR" --context-file "$CTX" --mode llm -e "$EXPR"
