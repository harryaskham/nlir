#!/usr/bin/env bash
# nlir TARGET-GOLF (aur-2 #68) — reverse game via : (simplify): COMPUTING jargon
# (a cache) -> plain, and : reaches for a toys-box analogy on its own (14% shorter).
#
# TARGET (~177 chars):
#   "A cache is a small, fast storage spot that keeps copies of stuff you use a lot,
#    so the computer can grab it quickly instead of doing the slow work of finding or
#    making it again."
#
# EXPRESSION (152 chars):
#   :'a cache is a small fast store that keeps copies of frequently accessed data so the system can avoid the slower work of fetching or computing it again'
#
# Real output (claude-sonnet-5):
#   "A cache is like a little box where you keep your favorite toys close by. That way,
#    when you want one, you can grab it fast instead of walking all the way across the
#    room to find it again."
# Closeness: same idea (a fast local store of frequently-used stuff -> skip the slow
# re-fetch), plain + its own toys-box analogy (high), 14% shorter.
set -euo pipefail
cd "$(dirname "$0")/.."
NLIR="${NLIR:-target/release/nlir}"
CTX="$(mktemp)"; trap 'rm -f "$CTX"' EXIT

TARGET="A cache is a small, fast storage spot that keeps copies of stuff you use a lot, so the computer can grab it quickly instead of doing the slow work of finding or making it again."
EXPR=":'a cache is a small fast store that keeps copies of frequently accessed data so the system can avoid the slower work of fetching or computing it again'"

echo "TARGET (${#TARGET} chars): $TARGET"
echo "EXPR   (${#EXPR} chars): $EXPR"
echo "---"
"$NLIR" --context-file "$CTX" --mode llm -e "$EXPR"
