#!/usr/bin/env bash
# nlir-golf · msm0 · #43 — "parens preserve grouping" (the wrapping-() quirk, resolved)
#
# aur-1 kept hitting stray "()" in operator output and flagged it as a quirk. I traced
# it — and it's a FEATURE, not a bug: parentheses ENCODE grouping, and nlir faithfully
# preserves them so the grouping survives into the operand text. The parens are
# load-bearing disambiguation:
#
#   !(a&b)  => "not (a and b)"    <- ! negates the WHOLE conjunction (parens group first)
#   !a&b    => "not a and b"      <- ! binds tighter -> negates ONLY a, then joins b
#
# The two DIFFER in meaning. If the parens were dropped, "!(a&b)" would collapse into
# "!a&b" and mean the wrong thing. So the preserved () are correct, not noise.
# (Mechanism: parenthesise_grouped() in eval.rs, per SPEC "parens always win",
# applied to BOTH the det render AND the LLM prompt operand.)
#
# HONEST tradeoff (this lives in the eval/realise lane, not the parser): in LLM mode
# the model can ECHO the literal "()" into its output — cosmetic, occasionally ugly.
# A future refinement could signal grouping to the model with a non-echoing marker
# (e.g. <group>…</group>) instead of literal parens. But the DET semantics above are
# exactly right: the quirk is the language keeping its promise about precedence.
set -euo pipefail
cd "$(dirname "$0")/.."
NLIR="${NLIR:-./target/release/nlir}"
[ -x "$NLIR" ] || { echo "build first: cargo build --release (or set NLIR=...)"; exit 1; }
CFG="${NLIR_CONFIG:-config.example.yaml}"
# deterministic — no key needed

say() { printf '\n\033[1m%s\033[0m\n' "$1"; }
det() { "$NLIR" --config "$CFG" --mode det -e "$1"; }

say 'parens are LOAD-BEARING: !(a&b) negates the whole thing, !a&b negates only a'
printf '  !(a&b) => '; det '!(a&b)'
printf '  !a&b   => '; det '!a&b'
printf '  !(a|b) => '; det '!(a|b)'
say "the preserved () encode grouping (they change meaning) — a feature, not a bug. Precedence, kept honest."
