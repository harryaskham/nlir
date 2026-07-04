#!/usr/bin/env bash
# nlir-golf (aur-2) — "the duration calculator": coercion reads TIME spans, not
# just counts, then does the maths in days.
#
#     'a fortnight' + 'a week' - 'a day'
#      └── 14 ──┘      └─ 7 ─┘    └─ 1 ─┘   (each LLM-coerced to a day-count)
#      └──────────── 14 + 7 - 1 = 20 ──────┘
#
# The coercion layer knows a fortnight is 14 days and a week is 7, so it totals
# fuzzy durations into an exact number of days. "How long altogether?" in words.
#
# Real output (claude-sonnet-5): 20
set -euo pipefail
cd "$(dirname "$0")/.."
NLIR="${NLIR:-target/release/nlir}"
CTX="$(mktemp)"; trap 'rm -f "$CTX"' EXIT

EXPR="'a fortnight'+'a week'-'a day'"

echo "concept:    total fuzzy time durations into days (a fortnight -> 14)"
echo "expression: 'a fortnight'+'a week'-'a day'   (14+7-1)"
echo "---"
"$NLIR" --context-file "$CTX" --mode llm -e "$EXPR"
