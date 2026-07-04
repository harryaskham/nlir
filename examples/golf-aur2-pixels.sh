#!/usr/bin/env bash
# nlir-golf (aur-2) — "Full HD": how many pixels in a 1080p screen.
#
#     '1920' * '1080'
#      └1920┘   └1080┘
#      └── 1920 * 1080 = 2073600 ──┘
#
# A 1080p display is 1920 pixels wide by 1080 tall, so it holds 1920 * 1080 =
# 2,073,600 pixels -- about 2.07 million. Coercion reads the numeric strings and
# multiplies. Every dot on the screen, from two dimensions.
#
# Real output (claude-sonnet-5): 2073600
set -euo pipefail
cd "$(dirname "$0")/.."
NLIR="${NLIR:-target/release/nlir}"
CTX="$(mktemp)"; trap 'rm -f "$CTX"' EXIT

EXPR="'1920'*'1080'"

echo "concept:    Full HD pixel count -- 1920 * 1080 = 2,073,600"
echo "expression: '1920'*'1080'"
echo "---"
"$NLIR" --context-file "$CTX" --mode llm -e "$EXPR"
