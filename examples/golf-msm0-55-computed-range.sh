#!/usr/bin/env bash
# nlir-golf · msm0 · #55 — "the computed range" (range bounds are arithmetic, not just literals)
#
# The addressing half of nlir has a hidden depth: a range BOUND isn't just an index
# literal — it's a full EXPRESSION. So you can COMPUTE which slice to read:
#
#   (1+1)^*(2+2)  -> messages at indices 2..4        (arithmetic endpoints)
#   (0-2)^*-1     -> the LAST TWO messages           (computed negative start = a recent window)
#
# The address is programmable: "the recent N", "a window offset from here" all fall out of
# putting arithmetic where an index goes. This is the general form behind #53's edges and
# #54's body — those are just special cases of computable bounds. (Confirmed via aur-0's
# grammar reconcile: reversed-N normalises, out-of-bounds clamps, negative-N resolves from
# the end, and computed endpoints all hold.)
#
# BOUNDARY (dogfood, refined in #56): a BARE identifier in index position (k^*…) does NOT
# resolve — it's a string literal, not the value. BUT `$k` IS a context read that coerces
# to the index ($start^*$end reads BOTH bounds from context) — see #56 THE STORED WINDOW.
# Only the "...$k..." STRING-interpolation form is non-resolving in index position, not `$k`.
# Use the arithmetic directly, or a stored value: (0-2)^*-1, or $s^*$e.
#
# Deterministic, no LLM — the markers make the slicing legible.
set -euo pipefail
cd "$(dirname "$0")/.."
NLIR="${NLIR:-./target/release/nlir}"
[ -x "$NLIR" ] || { echo "build first: cargo build --release (or set NLIR=...)"; exit 1; }
CFG="${NLIR_CONFIG:-config.example.yaml}"
# deterministic — no key needed

CTX="$(mktemp "${TMPDIR:-/tmp}/nlir-golf-msm0-XXXXXX.json")"
trap 'rm -f "$CTX"' EXIT
cat > "$CTX" <<'JSON'
{"_messages":[
 {"role":"user","content":"M0-alpha"},
 {"role":"assistant","content":"M1-bravo"},
 {"role":"user","content":"M2-charlie"},
 {"role":"assistant","content":"M3-delta"},
 {"role":"user","content":"M4-echo"}
]}
JSON

say() { printf '\n\033[1m%s\033[0m\n' "$1"; }
r() { "$NLIR" --context-file "$CTX" --config "$CFG" --mode det --quiet -e "$1" | tr '\n' ' '; echo; }
say "5 markers M0..M4 in context — the range BOUNDS are computed expressions:"
printf '  (1+1)^*(2+2)  => '; r '(1+1)^*(2+2)'
printf '  (0-2)^*-1     => '; r '(0-2)^*-1'
say "arithmetic where an index goes = a programmable address. The recent-N window: (0-2)^*-1."
