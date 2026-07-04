#!/usr/bin/env bash
# nlir-golf · msm0 · #36 — "the calculator report" (nlir with the LLM turned OFF)
#
# Every other msm0 concept calls a model. This one is PURE COMPUTATION — assignment
# + arithmetic (with $-substitution) + interpolation, all deterministic. No LLM, no
# API key, instant. The mini-language the sigils are built on:
#
#   p=2**10 ; "2^10 = $p bytes = one kilobyte"     -> "2^10 = 1024 bytes = one kilobyte"
#   a=3 ; b=4 ; h=$a**2+$b**2 ; "$a^2 + $b^2 = $h" -> "3^2 + 4^2 = 25"   (multi-variable)
#   t=2+3*2**2 ; "2+3*2^2 = $t"                    -> "2+3*2^2 = 14"     (pow>mul>add)
#
# A computed value flows straight into a template — the deterministic twin of my
# LLM interpolation entries (#07 subject / #09 email), but with real ARITHMETIC in
# the middle. And it exercises the just-landed pow fix (2**10 right-assoc-correct).
#
# Finding worth knowing: variables in ARITHMETIC need the $ ($a, not bare a) — a bare
# identifier is a string literal and won't coerce to a number. So `k=hi;"$k"` reads a
# stored value, and `h=$a**2` computes with one. nlir is a real little language even
# with the model turned off.
set -euo pipefail
cd "$(dirname "$0")/.."
NLIR="${NLIR:-./target/release/nlir}"
[ -x "$NLIR" ] || { echo "build first: cargo build --release (or set NLIR=...)"; exit 1; }
CFG="${NLIR_CONFIG:-config.example.yaml}"
# no key needed — this example is fully deterministic (--mode det)

say() { printf '\n\033[1m%s\033[0m\n' "$1"; }
det() { "$NLIR" --config "$CFG" --mode det -e "$1"; }

say 'a computed value into a template (no LLM):'
printf '  '; det 'p=2**10;"2^10 = $p bytes = one kilobyte"'
say 'multi-variable arithmetic (note the $ on variables inside the maths):'
printf '  '; det 'a=3;b=4;h=$a**2+$b**2;"$a^2 + $b^2 = $h"'
say 'precedence + the fresh right-assoc pow, deterministically:'
printf '  '; det 't=2+3*2**2;"2+3*2^2 = $t (pow, then mul, then add)"'
say "assignment + arithmetic + interpolation, all deterministic — nlir with the LLM turned off."
