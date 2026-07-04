#!/usr/bin/env bash
# nlir-golf · aur1 · #91 — "the executive brief" (the formal one-liner + the decision, [@~x, x?])
#
# The tightest way to open a decision: one polished line of what's proposed, then the exact
# question to answer. `[@~x, x?]` builds both — `@~x` is the ABSTRACT (formalise the gist: the
# proposal boiled to a single formal sentence) and `x?` is the DECISION (the same idea flipped
# into the yes/no on the table). No preamble, no full brief — the line you put at the top of
# the thread and the question you put at the bottom.
#
#   THE EXECUTIVE BRIEF   [ @~x , x? ]
#     idea "we've been bleeding users at signup and I think making email optional would help"
#     @~x → "Making email optional at signup may reduce user drop-off."     ← the ABSTRACT
#     x?  → "Should we make email optional at signup?"                       ← the DECISION
#
# It's the leanest member of my decision family: where the decision-opener (#61, `[@x, x?]`)
# leads with the FULL formal claim and the one-pager (#90) unfolds the whole document, this
# leads with the tightest possible line — `@~x` compresses AND formalises in one move (the
# exec-summary of #32) — then hands over the question. Perfect for a Slack poll or a standup:
# here's the one-sentence version, here's what we're deciding.
#
# Run:  ./examples/golf-aur1-91-execbrief.sh
set -euo pipefail
cd "$(dirname "$0")/.."
NLIR="${NLIR:-./target/release/nlir}"
[ -x "$NLIR" ] || { echo "build first: cargo build --release (or set NLIR=...)"; exit 1; }
if [ -z "${LITELLM_MASTER_KEY:-}" ] && [ -n "${CACOPHONY_LITELLM_MASTER_KEY_FILE:-}" ]; then
  export LITELLM_MASTER_KEY="$(cat "$CACOPHONY_LITELLM_MASTER_KEY_FILE")"
fi
say() { printf '\n\033[1m%s\033[0m\n' "$1"; }
C='weve been bleeding users at signup and i think making email optional would help'

say "THE EXECUTIVE BRIEF  [@~x, x?]  — the ABSTRACT (@~x, formal one-liner) + the DECISION (x?)"
echo   "  idea: $C"
echo -n "  @~x (the ABSTRACT) => "; "$NLIR" -e "@~'$C'" --quiet | fold -s -w 84 | sed '2,$s/^/       /'
echo -n "  x?  (the DECISION) => "; "$NLIR" -e "'$C'?"  --quiet | fold -s -w 84 | sed '2,$s/^/       /'

say "The leanest of my decision family: opener #61 [@x,x?] leads with the full claim, one-pager #90 unfolds the doc; this is the one-line version + the question."
