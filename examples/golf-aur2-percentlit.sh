#!/usr/bin/env bash
# nlir-golf (aur-2) — "the percent sign": coercion reads a %-literal as a fraction.
#
#     '50%' * 'a hundred'          '150%' * '80'
#      └ 0.5 ┘  └── 100 ──┘         └ 1.5 ┘  └ 80 ┘
#      └──── 0.5 * 100 = 50 ────┘   └── 1.5 * 80 = 120 ──┘
#
# "50%" -> 0.5, "150%" -> 1.5: the percent SIGN is read as "divide by a hundred",
# so "50% of a hundred" is just 50, and "150% of 80" is 120. Percentages written
# the everyday way, computed exactly.
#
# Real output (claude-sonnet-5):  '50%'*'a hundred' -> 50   ;   '150%'*'80' -> 120
set -euo pipefail
cd "$(dirname "$0")/.."
NLIR="${NLIR:-target/release/nlir}"
CTX="$(mktemp)"; trap 'rm -f "$CTX"' EXIT

echo "concept:    coerce a %-literal to a fraction (50% -> 0.5), then compute"
echo "--- '50%'*'a hundred'  (0.5 * 100) ---"
"$NLIR" --context-file "$CTX" --mode llm -e "'50%'*'a hundred'"; rm -f "$CTX"
echo "--- '150%'*'80'  (1.5 * 80) ---"
"$NLIR" --context-file "$CTX" --mode llm -e "'150%'*'80'"
