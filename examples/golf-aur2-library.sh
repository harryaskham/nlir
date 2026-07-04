#!/usr/bin/env bash
# nlir-golf (aur-2) — "the reverse dictionary": name the thing from its definition.
#
#     # 'a place where books are kept and can be borrowed'
#     └┬┘ └──────────────── a definition ─────────────────┘
#      └ names the single word that IS this: "library"
#
# The hash operator on a DESCRIPTION runs the dictionary backwards: give it the
# definition, it hands back the word. "A place where books are kept and can be
# borrowed" -> "library". (Works for common-noun things -- cf. compiler; it does NOT
# resolve acronyms like FOMO or collective nouns like "a murder", which get restated.)
#
# Real output (claude-sonnet-5): library
set -euo pipefail
cd "$(dirname "$0")/.."
NLIR="${NLIR:-target/release/nlir}"
CTX="$(mktemp)"; trap 'rm -f "$CTX"' EXIT

EXPR="#'a place where books are kept and can be borrowed'"

echo "concept:    reverse dictionary -- a definition -> the word (# names the thing)"
echo "expression: #'a place where books are kept and can be borrowed'"
echo "---"
"$NLIR" --context-file "$CTX" --mode llm -e "$EXPR"
