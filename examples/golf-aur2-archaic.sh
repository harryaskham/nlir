#!/usr/bin/env bash
# nlir-golf (aur-2) — "the archaic-quantity calculator": coercion that knows the
# old counting words, then does the maths.
#
#     'a score' + 'a gross' - 'a bakers dozen'
#      └── 20 ─┘   └─ 144 ─┘   └───── 13 ─────┘   (each LLM-coerced to a number)
#      └──────────── 20 + 144 - 13 = 151 ────────┘
#
# The coercion layer knows score=20, gross=144, baker's dozen=13 -- obscure
# quantity words most calculators can't parse -- and the deterministic engine
# then adds/subtracts them exactly. General knowledge in, exact arithmetic out.
#
# Real output (claude-sonnet-5): 151
set -euo pipefail
cd "$(dirname "$0")/.."
NLIR="${NLIR:-target/release/nlir}"
CTX="$(mktemp)"; trap 'rm -f "$CTX"' EXIT

EXPR="'a score'+'a gross'-'a bakers dozen'"

echo "concept:    arithmetic over archaic counting words (score/gross/baker's dozen)"
echo "expression: 'a score'+'a gross'-'a bakers dozen'   (20+144-13)"
echo "---"
"$NLIR" --context-file "$CTX" --mode llm -e "$EXPR"
