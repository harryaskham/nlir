#!/usr/bin/env bash
# nlir-golf · msm0 · #71 — "the form letter" (the template as a reusable function)
#
# Where #67's receipt was one record and #69's meeting-cost one calculation, this points the same
# deterministic machinery at REUSE: fix the shape once, feed it different data, get a personalised
# letter each time — mail-merge, with arithmetic.
#
#   name="Alex" ; amt=250 ; fee=25 ; total=$amt+$fee ; "Hi $name — your invoice of \$$amt plus a \$$fee late fee comes to \$$total, due on receipt."
#   =>  Hi Alex — your invoice of $250 plus a $25 late fee comes to $275, due on receipt.
#
# Swap the fields and the SAME expression re-renders for the next recipient:
#   name="Priya" ; amt=1200 ; fee=0   =>  Hi Priya — your invoice of $1200 plus a $0 late fee comes to $1200, due on receipt.
#
# The total is COMPUTED ($amt+$fee), `\$` is a literal dollar (#51), and the fields interpolate. This
# is the template as a PARAMETRIC FUNCTION — one shape, many outputs — the reuse dimension the
# single-shot receipt/meeting-cost cards didn't show. nlir as a mail-merge engine: deterministic, no LLM.
set -euo pipefail
cd "$(dirname "$0")/.."
NLIR="${NLIR:-./target/release/nlir}"
[ -x "$NLIR" ] || { echo "build first: cargo build --release (or set NLIR=...)"; exit 1; }
CFG="${NLIR_CONFIG:-config.example.yaml}"
# deterministic — no key needed

TMPL='"Hi $name — your invoice of \$$amt plus a \$$fee late fee comes to \$$total, due on receipt."'
say() { printf '\n\033[1m%s\033[0m\n' "$1"; }
say 'one template, two recipients — swap name/amt/fee, the same expression re-renders (total computed):'
printf '  '; "$NLIR" --config "$CFG" --mode det --quiet -e "name=\"Alex\";amt=250;fee=25;total=\$amt+\$fee;$TMPL"
printf '  '; "$NLIR" --config "$CFG" --mode det --quiet -e "name=\"Priya\";amt=1200;fee=0;total=\$amt+\$fee;$TMPL"
say "the template as a parametric function — one shape, many outputs. nlir as a mail-merge engine, no LLM."
