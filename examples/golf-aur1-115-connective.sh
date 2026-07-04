#!/usr/bin/env bash
# nlir-golf · aur1 · #115 — "the connective survives" (~(a|b) ≠ ~(a&b) : summary preserves and/or)
#
# I used to think `~` was blind to how you joined its operands. It isn't. The summary CARRIES
# THE CONNECTIVE: join two ideas with `&` (and) and the gist is a CONJUNCTION — do both; join
# them with `|` (or) and the gist is a CHOICE — do either. Same two ideas, one sigil apart, a
# plan vs a dilemma.
#
#   THE CONNECTIVE SURVIVES     a = "we ship the feature now" ,  b = "we wait for full QA"
#     ~(a & b) → "We ship the feature now AND run full QA afterward."   ← CONJUNCTION (a plan: both)
#     ~(a | b) → "We ship the feature now OR wait for full QA."         ← CHOICE (a dilemma: either)
#
# So `&` and `|` are NOT interchangeable inside a summary — the connective you pick decides
# whether `~` hands you a COMBINED PLAN or a TRADE-OFF. This corrects my old "join-blind"
# reading of #15: `~` doesn't ignore the join, it PRESERVES it. The practical upshot: to distil
# a genuine either/or into the dilemma it represents, group with `|`; to distil two things you
# intend to do together into one plan, group with `&`. (`|` is the only nlir operator that
# encodes real CHOICE — this is where it earns its keep in a summary, not just a fork #42.)
#
# Run:  ./examples/golf-aur1-115-connective.sh
set -euo pipefail
cd "$(dirname "$0")/.."
NLIR="${NLIR:-./target/release/nlir}"
[ -x "$NLIR" ] || { echo "build first: cargo build --release (or set NLIR=...)"; exit 1; }
if [ -z "${LITELLM_MASTER_KEY:-}" ] && [ -n "${CACOPHONY_LITELLM_MASTER_KEY_FILE:-}" ]; then
  export LITELLM_MASTER_KEY="$(cat "$CACOPHONY_LITELLM_MASTER_KEY_FILE")"
fi
say() { printf '\n\033[1m%s\033[0m\n' "$1"; }
A='we ship the feature now'; B='we wait for full QA'

say "THE CONNECTIVE SURVIVES  ~(a|b) ≠ ~(a&b)  — the summary carries the AND / OR you joined with"
echo   "  a: $A   |   b: $B"
echo -n "  ~(a & b) [join → CONJUNCTION] => "; "$NLIR" -e "~('$A' & '$B')" --quiet | fold -s -w 80 | sed '2,$s/^/       /'
echo -n "  ~(a | b) [choice → DILEMMA]   => "; "$NLIR" -e "~('$A' | '$B')" --quiet | fold -s -w 80 | sed '2,$s/^/       /'

say "& → 'and' (a plan: do both); | → 'or' (a dilemma: do either). NOT interchangeable — ~ PRESERVES the connective (corrects the 'join-blind' read of #15). Group with | to distil an either/or, & to distil a combined plan."
