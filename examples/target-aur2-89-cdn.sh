#!/usr/bin/env bash
# nlir TARGET-GOLF (aur-2 #89) — reverse game via ~> (summary of expand): a dense
# TECHNICAL one-liner from a 17-char seed (my TIGHTEST ~> seed yet).
#
# TARGET (~199 chars):
#   "A CDN is a network of servers spread around the world that store copies of a
#    website's content, so users get it from a server near them -- making pages load
#    faster and taking load off the origin server."
#
# EXPRESSION (17 chars):
#   ~>'what is a CDN'
#
# Real output (claude-sonnet-5):
#   "A CDN speeds up and stabilizes web content delivery by caching it on geographically
#    distributed servers closer to users."
# Closeness: same core (distributed servers cache content closer to users -> faster
# delivery), high; ~> gave an unusually TIGHT one-liner here (dropped "load off origin").
# 91% shorter -- 17 chars into a full definition, the tightest ~> seed in the set.
set -euo pipefail
cd "$(dirname "$0")/.."
NLIR="${NLIR:-target/release/nlir}"
CTX="$(mktemp)"; trap 'rm -f "$CTX"' EXIT

TARGET="A CDN is a network of servers spread around the world that store copies of a website's content, so users get it from a server near them -- making pages load faster and taking load off the origin server."
EXPR="~>'what is a CDN'"

echo "TARGET (${#TARGET} chars): $TARGET"
echo "EXPR   (${#EXPR} chars): $EXPR"
echo "---"
"$NLIR" --context-file "$CTX" --mode llm -e "$EXPR"
