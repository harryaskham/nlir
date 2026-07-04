#!/usr/bin/env bash
# nlir-golf · aur1 · #17 — "the accumulator" (collect → fold → distill)
#
# Push several separate items onto the stack, collapse them with a nullary fold,
# then distil the result — a standup-to-headline machine. The stack is the
# inbox; `&` (with no operands) folds the WHOLE stack into one and-joined value;
# `~$` summarises that.
#
#   ACCUMULATOR   a ; b ; c ; & ; ~$
#     a ; b ; c   push three raw items (metrics, updates, bullet points)
#     &           nullary fold — collapse the entire stack into "a and b and c"
#     ~$          summarise the peeked collection → one headline
#
# Three quarterly metrics — "sales up 20%", "churn rose 5%", "NPS fell 3 points" —
# go in as separate pushes and come out as "Sales grew 20% this quarter, but churn
# rose 5% and NPS fell 3 points." The nullary `&` is the trick: it doesn't need
# operands because it eats whatever the stack has accumulated. Give it five bullets
# or ten; it folds them all.
#
# Run:  ./examples/golf-aur1-17-accumulator.sh
set -euo pipefail
cd "$(dirname "$0")/.."
NLIR="${NLIR:-./target/release/nlir}"
[ -x "$NLIR" ] || { echo "build first: cargo build --release (or set NLIR=...)"; exit 1; }
if [ -z "${LITELLM_MASTER_KEY:-}" ] && [ -n "${CACOPHONY_LITELLM_MASTER_KEY_FILE:-}" ]; then
  export LITELLM_MASTER_KEY="$(cat "$CACOPHONY_LITELLM_MASTER_KEY_FILE")"
fi
say() { printf '\n\033[1m%s\033[0m\n' "$1"; }

say "ACCUMULATOR  a;b;c;&;~\$  — push items, nullary & folds the whole stack, ~\$ distils"
echo "  pushes: 'sales up 20%'  ·  'churn rose 5%'  ·  'NPS fell 3 points'"
echo -n "  headline => "
"$NLIR" -e "'sales up 20 percent this quarter';'customer churn rose 5 percent';'our nps dropped 3 points';&;~\$" --quiet

say "The stack is the inbox; nullary & eats however many items you pushed, ~\$ headlines them."
