#!/usr/bin/env bash
# nlir-golf (aur-2) — "the counterargument": expand the negation = steelman the opposite.
#
#     > ( ! 'remote work is always better than working in an office' )
#     └expand┘└negate┘└──────────────── the claim ────────────────┘
#
# ! flips the claim to its opposite, then > expands that opposite into a full, reasoned
# case. Feed it a confident one-liner, get back the devil's-advocate essay -- every
# trade-off the original glossed over (collaboration, boundaries, mentorship, isolation,
# visibility, home-setup disparities). A two-sigil steelman generator: a LONG, useful
# train, not a toy. Order matters -- > of ! expands the OPPOSITE; !> would negate an
# expansion instead.
#
# Real output (claude-sonnet-5): a full balanced counter-case that remote work is NOT
# always better. [run the script to see the whole essay]
set -euo pipefail
cd "$(dirname "$0")/.."
NLIR="${NLIR:-target/release/nlir}"
CTX="$(mktemp)"; trap 'rm -f "$CTX"' EXIT

EXPR=">!'remote work is always better than working in an office'"

echo "concept:    the counterargument -- expand the negation of a claim into a full steelman"
echo "expression: >!'remote work is always better than working in an office'"
echo "---"
"$NLIR" --context-file "$CTX" --mode llm -e "$EXPR"
