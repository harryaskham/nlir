#!/usr/bin/env bash
# nlir-golf · msm0 · #51 — "the price template" (the \$-escape fix, cashed in)
#
# The bug I fixed last tick (bd-65b737) immediately pays off. Now that `\$` yields a
# LITERAL `$`, you can put a literal dollar-sign right next to an INTERPOLATED value —
# a currency template — which was impossible an hour ago (the `\$` used to interpolate):
#
#   item=coffee ; price=5 ; "The $item costs \$$price"   ->   "The coffee costs $5"
#   │             │          │      │        │  └ $price  interpolated  -> "5"
#   │             │          │      │        └ \$         LITERAL '$' (the fixed escape)
#   │             │          │      └ $item   interpolated -> "coffee"
#   │             │          └ "…" cooked string: escapes + interpolation together
#   └── two assignments feeding one template
#
# So nlir can now render prices AND shell-safe snippets that carry a literal `$`:
#   n=PATH ; "echo \$$n"   ->   "echo $PATH"   (literal '$' + injected var NAME)
#
# Deterministic, no LLM. A fix, then the concept it unlocks — mapped a boundary in #44,
# fixed it, and now it's a feature.
set -euo pipefail
cd "$(dirname "$0")/.."
NLIR="${NLIR:-./target/release/nlir}"
[ -x "$NLIR" ] || { echo "build first: cargo build --release (or set NLIR=...)"; exit 1; }
CFG="${NLIR_CONFIG:-config.example.yaml}"
# deterministic — no key needed

say() { printf '\n\033[1m%s\033[0m\n' "$1"; }
det() { "$NLIR" --config "$CFG" --mode det -e "$1"; }

say 'a literal $ (\$) next to an interpolated $var — a currency template:'
printf '  '; det 'item=coffee;price=5;"The $item costs \$$price"'
say 'the same trick makes shell-safe snippets (literal $ + injected var name):'
printf '  '; det 'n=PATH;"echo \$$n"'
say "\\\$ = literal dollar, \$var = interpolated. The bd-65b737 fix, immediately useful."
