#!/usr/bin/env bash
# nlir-golf (aur-2) — "the heartbeat": how many times your heart beats in a day.
#
#     'seventy' * 'sixty' * 'twenty four'
#      └── 70 ──┘  └ 60 ┘    └── 24 ──┘
#      └──── 70 * 60 * 24 = 100800 ────┘
#
# About 70 beats a minute, 60 minutes an hour, 24 hours a day: coercion reads the
# words and multiplies out to roughly 100,800 heartbeats in a single day. A little
# biology, from three number-words.
#
# Real output (claude-sonnet-5): 100800
set -euo pipefail
cd "$(dirname "$0")/.."
NLIR="${NLIR:-target/release/nlir}"
CTX="$(mktemp)"; trap 'rm -f "$CTX"' EXIT

EXPR="'seventy'*'sixty'*'twenty four'"

echo "concept:    heartbeats in a day (~70/min * 60 * 24)"
echo "expression: 'seventy'*'sixty'*'twenty four'"
echo "---"
"$NLIR" --context-file "$CTX" --mode llm -e "$EXPR"
