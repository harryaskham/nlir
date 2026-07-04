#!/usr/bin/env bash
# nlir-golf · msm0 · #44 — "the two quote kinds" (control interpolation; the \$ escape now works)
#
# nlir has TWO string quotes with different interpolation rules — the clean way to
# choose whether `$name` expands:
#
#   'raw'   — RAW: no escapes, NO interpolation. `$k` stays literal.
#   "cook"  — COOKED: POSIX escapes (\n \t …) AND eval-time `$name` interpolation.
#
#   k=world;'literal: $k'   => "literal: $k"     (raw: $k untouched)
#   k=world;"interp: $k"    => "interp: world"   (cooked: $k -> the value)
#
# So to include a LITERAL "$k"-shaped string, reach for single quotes.
#
# DOGFOOD FIX (bd-65b737, landed): the `\$` escape inside "…" now yields a LITERAL `$`.
# It used to be DEFEATED — `"\$k"` wrongly interpolated to "world" — because the lexer
# de-escaped `\$` -> `$` BEFORE eval-time interpolate() ran, so interpolate() couldn't
# tell an escaped `$` from a real one. The fix preserves `\$` through the lexer and
# honours it in interpolate(). So you now have TWO ways to a literal `$`: raw '…' (never
# interpolates) or the `\$` escape inside cooked "…":
#   k=world;"\$k"  => "$k"   (fixed — escape honoured)
set -euo pipefail
cd "$(dirname "$0")/.."
NLIR="${NLIR:-./target/release/nlir}"
[ -x "$NLIR" ] || { echo "build first: cargo build --release (or set NLIR=...)"; exit 1; }
CFG="${NLIR_CONFIG:-config.example.yaml}"
# deterministic — no key needed

say() { printf '\n\033[1m%s\033[0m\n' "$1"; }
det() { "$NLIR" --config "$CFG" --mode det -e "$1"; }

say "raw '…' keeps \$k literal; cooked \"…\" interpolates it:"
printf "  k=world;'literal: \$k' => "; det "k=world;'literal: \$k'"
printf '  k=world;"interp: $k"  => '; det 'k=world;"interp: $k"'
say 'a literal $-string, two ways: raw single quotes, OR the now-fixed \$ escape in "…" (bd-65b737):'
printf '  k=world;"\$k"          => '; det 'k=world;"\$k"'
say "two quote kinds = explicit control over interpolation. Raw ' for literal, cooked \" for expansion (or \\\$)."
