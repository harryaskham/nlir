#!/usr/bin/env bash
# nlir-golf · msm0 · #44 — "the two quote kinds" (control interpolation, + a dogfood bug)
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
# DOGFOOD BUG (filed bd-65b737): the `\$` escape inside "…" is currently DEFEATED —
#   k=world;"\$k"  => "world"   (WRONG: want literal "$k")
# Root cause: the lexer de-escapes `\$` -> `$` (read_escape) BEFORE eval-time
# interpolate() runs, so interpolate() can't tell an escaped `$` from a real one and
# expands it. Fix spans lexer + interpolate (my interpolation feature, bd-2a1cb6);
# analysis + proposed patch are on the bead. WORKAROUND until then: use '…' (raw) for
# a literal `$` — which is exactly what the first example does, correctly.
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
say 'for a LITERAL $-string, use single quotes (the \$ escape in "…" is buggy — bd-65b737):'
printf '  k=world;"\$k" (BUG)   => '; det 'k=world;"\$k"'
say "two quote kinds = explicit control over interpolation. Raw ' for literal, cooked \" for expansion."
