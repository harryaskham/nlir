#!/usr/bin/env bash
# nlir-golf (aur-2) — "subject of a definition" (2): # on a book-place -> "library".
#
#     # 'a place where books are kept and can be borrowed'
#     └┬┘ └──────────────── a definition ─────────────────┘
#      └ subject noun-phrase -> here it collapses to "library"
#
# # extracts the primary SUBJECT noun-phrase (per config). On a well-known definition
# the model CAN collapse it to the canonical term ("library", cf. compiler) -- but this
# is INCONSISTENT: 'a device that measures temperature' just restates, as do acronyms
# (FOMO) and collective nouns ("a murder"). The reliable behaviour is subject/topic
# extraction; a real description->term lookup would be a separate "name-this-concept"
# op (credit aur-0).
#
# Real output (claude-sonnet-5): library  (a subject-collapse; not guaranteed)
set -euo pipefail
cd "$(dirname "$0")/.."
NLIR="${NLIR:-target/release/nlir}"
CTX="$(mktemp)"; trap 'rm -f "$CTX"' EXIT

EXPR="#'a place where books are kept and can be borrowed'"

echo "concept:    reverse dictionary -- a definition -> the word (# names the thing)"
echo "expression: #'a place where books are kept and can be borrowed'"
echo "---"
"$NLIR" --context-file "$CTX" --mode llm -e "$EXPR"
