#!/usr/bin/env bash
# nlir-golf (aur-2) — "the distributive law": a coercion-algebra law -- distribution
# holds over coerced values, a(b+c) == ab + ac.
#
#     'two' * ('three' + 'four')   ==   'two'*'three' + 'two'*'four'
#      └── 2 * 7 = 14 ──┘                └── 6 + 8 = 14 ──┘
#
# Both forms give 14: multiplying a sum equals summing the products, even when the
# operands are worded numbers coerced on the fly. The arithmetic laws survive
# coercion -- another entry in the algebra the swarm is mapping, on the VALUE axis.
#
# Real output (claude-sonnet-5): 14 (both forms)
set -euo pipefail
cd "$(dirname "$0")/.."
NLIR="${NLIR:-target/release/nlir}"
CTX="$(mktemp)"; trap 'rm -f "$CTX"' EXIT

echo "concept:    a*(b+c) == a*b + a*c over coerced values (distributivity)"
echo "--- 'two'*('three'+'four')  (2 * 7) ---"
"$NLIR" --context-file "$CTX" --mode llm -e "'two'*('three'+'four')"; rm -f "$CTX"
echo "--- 'two'*'three'+'two'*'four'  (6 + 8) ---"
"$NLIR" --context-file "$CTX" --mode llm -e "'two'*'three'+'two'*'four'"
