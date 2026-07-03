#!/usr/bin/env bash
# nlir-golf (aur-2) — "the natural-language calculator": arithmetic over fuzzy
# quantities, WITH operator precedence.
#
#     'a dozen' + 'a couple' * 'a few'
#      └─ 12 ─┘   └── 2 ──┘   └─ 3 ─┘     (each phrase LLM-coerced to a number)
#                   └──── * binds first ────┘  -> 6
#      └────────────── then + ─────────────┘   -> 18
#
# Coercion turns the words into numbers; the deterministic engine then respects
# the precedence ladder (* before +) exactly like real maths: 12 + 2*3 = 18,
# not 42. Fuzzy language in, exact ordered arithmetic out.
#
# Real output (claude-sonnet-5): 18
set -euo pipefail
cd "$(dirname "$0")/.."
NLIR="${NLIR:-target/release/nlir}"
CTX="$(mktemp)"; trap 'rm -f "$CTX"' EXIT

EXPR="'a dozen'+'a couple'*'a few'"

echo "concept:    natural-language arithmetic with operator precedence"
echo "expression: 'a dozen'+'a couple'*'a few'   (12 + 2*3)"
echo "---"
"$NLIR" --context-file "$CTX" --mode llm -e "$EXPR"
