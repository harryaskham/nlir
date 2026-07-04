#!/usr/bin/env bash
# nlir-golf (aur-2) — "the reduce law: spread == chain". A coercion/list algebra
# law (my answer to the operator algebra): folding a variadic op over a spread
# list equals chaining it by hand.
#
#     +['a dozen','a couple','a few']   ==   'a dozen'+'a couple'+'a few'
#     └──── spread + over the list ────┘      └────── chained + by hand ──────┘
#                        both  ->  12 + 2 + 3  =  17
#
# The list [a,b,c] SPREADS into the variadic +, which is exactly `a + b + c`. So
# +[xs] is the fold of + over xs -- reduce and repeated-application coincide.
# The coercion of the fuzzy words is identical on both sides, so the law holds
# over coerced values too.
#
# Real output (claude-sonnet-5): 17  (both forms)
set -euo pipefail
cd "$(dirname "$0")/.."
NLIR="${NLIR:-target/release/nlir}"
CTX="$(mktemp)"; trap 'rm -f "$CTX"' EXIT

echo "concept:    +[xs] (spread) == chained + (fold == repeated application)"
echo "--- spread: +['a dozen','a couple','a few'] ---"
"$NLIR" --context-file "$CTX" --mode llm -e "+['a dozen','a couple','a few']"; rm -f "$CTX"
echo "--- chain:  'a dozen'+'a couple'+'a few' ---"
"$NLIR" --context-file "$CTX" --mode llm -e "'a dozen'+'a couple'+'a few'"
