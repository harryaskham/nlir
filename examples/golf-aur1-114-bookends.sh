#!/usr/bin/env bash
# nlir-golf · aur1 · #114 — "the bookends" (the stack reads from BOTH ends: ~($0 & $) = first vs latest)
#
# The nlir stack is a scratchpad you can read from either end — and it's indexed exactly like the
# message history is. Push a series of positions as a discussion evolves, and:
#   $0, $1, $2 …   count from the BOTTOM  (chronological: $0 = the FIRST thing pushed)
#   $, $-1, $-2 …  count from the TOP     (recency:       $ = $-1 = the LATEST; $-2 = the one before)
# So `~($0 & $)` distils the BOOKENDS of the whole discussion: where it STARTED and where it is NOW.
#
#   THE BOOKENDS   push three evolving positions, then ~($0 & $)
#     'we should just build it in-house' ; 'actually maybe we buy a vendor tool' ;
#     'lets just use an open-source library instead'
#       $0        → "we should just build it in-house"                 ← the FIRST position
#       $         → "lets just use an open-source library instead"     ← the LATEST position
#       ~($0 & $) → "The team is debating between building in-house or using an open-source
#                    library."                                          ← the SPAN, both poles
#
# The stack is BI-INDEXED, just like `^` messages (^_0 first-user … ^_-1 last-user): negative
# from the top for recency, non-negative from the bottom for chronology. That lets you reach the
# thing you FIRST parked ($0 — "what was my original point?") and the thing you MOST RECENTLY
# parked ($ — "where did I land?") in one expression. (Honest note: `~` relates the two poles;
# it doesn't show DIRECTION — a "how it drifted from A to B" reading wants a directional operator
# like the CONTRAST/DIFF `Δ` I proposed, since `~(a & b)` is order-blind.)
#
# Run:  ./examples/golf-aur1-114-bookends.sh
set -euo pipefail
cd "$(dirname "$0")/.."
NLIR="${NLIR:-./target/release/nlir}"
[ -x "$NLIR" ] || { echo "build first: cargo build --release (or set NLIR=...)"; exit 1; }
if [ -z "${LITELLM_MASTER_KEY:-}" ] && [ -n "${CACOPHONY_LITELLM_MASTER_KEY_FILE:-}" ]; then
  export LITELLM_MASTER_KEY="$(cat "$CACOPHONY_LITELLM_MASTER_KEY_FILE")"
fi
say() { printf '\n\033[1m%s\033[0m\n' "$1"; }
E="'we should just build it in-house';'actually maybe we buy a vendor tool';'lets just use an open-source library instead'"

say "THE BOOKENDS  ~(\$0 & \$)  — the stack is BI-INDEXED: \$0 = FIRST pushed (bottom), \$ = LATEST (top)"
echo   "  pushed: in-house  →  buy a vendor tool  →  open-source library"
echo -n "  \$0 (the FIRST position) => "; "$NLIR" -e "$E;\$0"        --quiet | fold -s -w 80 | sed '2,$s/^/       /'
echo -n "  \$  (the LATEST position)=> "; "$NLIR" -e "$E;\$"         --quiet | fold -s -w 80 | sed '2,$s/^/       /'
echo -n "  ~(\$0 & \$) (the SPAN)    => "; "$NLIR" -e "$E;~(\$0 & \$)" --quiet | fold -s -w 80 | sed '2,$s/^/       /'

say "The stack reads BOTH ways (like ^ messages): \$0/\$1… from the bottom (chronology), \$/\$-1/\$-2… from the top (recency). ~(\$0 & \$) = the bookends of a discussion. (Direction 'A→B' wants the CONTRAST/DIFF Δ op — ~(a&b) is order-blind.)"
