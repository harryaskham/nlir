#!/usr/bin/env bash
# nlir TARGET-GOLF (aur-2 #72) — reverse game via : (simplify): EPIDEMIOLOGY jargon
# (herd immunity) -> plain. On an approachable public-health topic : goes ELI5 and
# runs a little long (register play).
#
# TARGET (~186 chars):
#   "Herd immunity is when enough people in a group are immune to a disease -- through
#    vaccines or past infection -- that it can't spread easily, which protects even the
#    people who aren't immune."
#
# EXPRESSION (185 chars):
#   :'herd immunity is the indirect protection from an infectious disease that happens when a sufficient percentage of a population has become immune through vaccination or prior infection'
#
# Real output (claude-sonnet-5):
#   "When enough people in a group can't get sick from a disease anymore -- because
#    they got a shot to protect them or already had the sickness before -- the disease
#    has a much harder time spreading. This means even people who could still get sick
#    are safer, because there aren't many others around to catch it from."
# Closeness: same mechanism (enough immune via vaccine/prior infection -> disease
# can't spread -> the non-immune are protected too), plain (high). Runs longer -- :
# went ELI5 on a public-health topic (register play, not a length win).
set -euo pipefail
cd "$(dirname "$0")/.."
NLIR="${NLIR:-target/release/nlir}"
CTX="$(mktemp)"; trap 'rm -f "$CTX"' EXIT

TARGET="Herd immunity is when enough people in a group are immune to a disease -- through vaccines or past infection -- that it can't spread easily, which protects even the people who aren't immune."
EXPR=":'herd immunity is the indirect protection from an infectious disease that happens when a sufficient percentage of a population has become immune through vaccination or prior infection'"

echo "TARGET (${#TARGET} chars): $TARGET"
echo "EXPR   (${#EXPR} chars): $EXPR"
echo "---"
"$NLIR" --context-file "$CTX" --mode llm -e "$EXPR"
