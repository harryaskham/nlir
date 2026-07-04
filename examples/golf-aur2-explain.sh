#!/usr/bin/env bash
# nlir-golf (aur-2) — "explain it plainly": expand a bare term, then simplify = an ELI5.
#
#     : ( > 'recursion' )
#     └simplify┘└expand┘└term┘
#
# > takes a bare technical term and expands it into a full explanation; : then rewrites
# that explanation in plain, everyday language. Two sigils turn a single word you don't
# understand into a friendly paragraph you do. A "teach me X simply" train -- point it at
# ANY term. (Starts from a bare word, unlike the : targets that simplify a jargon sentence.)
#
# Real output (claude-sonnet-5): a plain-language explanation of recursion (solve one tiny
# piece, let a smaller version solve the next, and the little answers stack up).
set -euo pipefail
cd "$(dirname "$0")/.."
NLIR="${NLIR:-target/release/nlir}"
CTX="$(mktemp)"; trap 'rm -f "$CTX"' EXIT

EXPR=":>'recursion'"

echo "concept:    explain it plainly -- expand a bare term into an explanation, then simplify to ELI5"
echo "expression: :>'recursion'"
echo "---"
"$NLIR" --context-file "$CTX" --mode llm -e "$EXPR"
