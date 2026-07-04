#!/usr/bin/env bash
# nlir-golf · aur1 · #97 — "the disarm" (steelman the objection FIRST, then argue: [>@!x, >x])
#
# A rhetorician's reading-order trick. My #31 pro-con runs `[>x, >@!x]` — make the case, THEN
# raise the objection. This flips it: `[>@!x, >x]` leads with the OPPOSITION — fairly, at full
# strength (>@!x is my #65 steelmanned counter-case) — and only THEN makes the case (>x). By
# voicing the strongest objection first, and voicing it honestly, you DISARM it: the reader
# feels heard, the counter-argument is already on the table, and your case lands against a
# fair foil instead of a strawman.
#
#   THE DISARM   [ >@!x , >x ]
#     x = "we should let every engineer deploy to production on their own"
#     >@!x → "Production deploy access should be carefully controlled and limited to a small,
#             trusted set of people or automated gates…"                    ← the OPPOSITION, first
#     >x   → "Every engineer should have the autonomy to deploy their own changes directly to
#             production, because ownership and fast feedback…"             ← THEN the case
#
# Same two arguments as pro-con, opposite order — and the order IS the point. Lead with the
# objection to defuse it (the "yes, and here's why anyway" structure); lead with the case
# (#31) to persuade-then-caveat. Reading-order is a first-class design choice in nlir: I've
# used it for answers (#44 BLUF gist-first vs #53 reveal answer-first); here it's for debate.
#
# Run:  ./examples/golf-aur1-97-disarm.sh
set -euo pipefail
cd "$(dirname "$0")/.."
NLIR="${NLIR:-./target/release/nlir}"
[ -x "$NLIR" ] || { echo "build first: cargo build --release (or set NLIR=...)"; exit 1; }
if [ -z "${LITELLM_MASTER_KEY:-}" ] && [ -n "${CACOPHONY_LITELLM_MASTER_KEY_FILE:-}" ]; then
  export LITELLM_MASTER_KEY="$(cat "$CACOPHONY_LITELLM_MASTER_KEY_FILE")"
fi
say() { printf '\n\033[1m%s\033[0m\n' "$1"; }
C='we should let every engineer deploy to production on their own'

say "THE DISARM  [>@!x, >x]  — the steelmanned OPPOSITION first (>@!x), THEN the case (>x)"
echo   "  x: $C"
echo -n "  >@!x (the OPPOSITION, first) => "; "$NLIR" -e ">@!'$C'" --quiet | fold -s -w 80 | sed '2,$s/^/       /'
echo -n "  >x   (THEN the case)         => "; "$NLIR" -e ">'$C'"   --quiet | fold -s -w 80 | sed '2,$s/^/       /'

say "Same two arguments as #31 pro-con, opposite order — and the order IS the point: lead with the objection to DISARM it, lead with the case (#31) to persuade-then-caveat. Reading-order as a design choice (cf #44 BLUF / #53 reveal for answers)."
