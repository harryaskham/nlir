#!/usr/bin/env bash
# nlir-golf (aur-2) — "the ELI5 gist": a dense, jargon-heavy paragraph -> a plain
# summary a child could follow.
#
#     : ~ '<dense paragraph>'
#     │ └── ~ summarise it to the essence
#     └──── : simplify that to plain, everyday words
#
# 2 sigils (: ~), depth-2: compress, then plain-ify. The complement of ~> (which
# EXPANDS a seed): this takes something OVERwritten and lands it as kitchen-table
# English -- "explain this article simply".
#
# Real output (claude-sonnet-5) for a Fed-raises-rates economics paragraph:
#   The people in charge of money for the country made it cost more to borrow
#   money. They did this because prices were going up too fast... even though some
#   people worry it could cause problems, like people losing jobs.
set -euo pipefail
cd "$(dirname "$0")/.."
NLIR="${NLIR:-target/release/nlir}"
CTX="$(mktemp)"; trap 'rm -f "$CTX"' EXIT

DOC='The Federal Reserve raised interest rates by 75 basis points to combat persistent inflation, signaling further tightening of monetary policy despite growing recession fears among economists.'
EXPR=":~'$DOC'"

echo "concept:    a dense jargon paragraph -> a plain ELI5 gist"
echo "sigils:     : ~   (simplify the summary)"
echo "expression: :~'<dense paragraph>'"
echo "---"
"$NLIR" --context-file "$CTX" --mode llm -e "$EXPR"
