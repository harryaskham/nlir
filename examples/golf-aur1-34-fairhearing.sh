#!/usr/bin/env bash
# nlir-golf · aur1 · #34 — "the fair hearing" (steelman the OTHER side, then hold)
#
# The intellectual-honesty move, as an expression. `[>@!x, @x]` gives the OPPOSING
# view the strongest, most articulate hearing you can — expand AND formalise the
# NEGATION of your claim — and only THEN states your own position, crisply. The
# asymmetry is the whole point: the counter-argument gets the big steelman; your
# claim just stands.
#
#   FAIR HEARING   [ >@!x , @x ]
#     >@!x = expand ∘ formalise ∘ negate  → the strongest case for the OTHER side
#     @x   = formalise                    → your claim, stated plainly and held
#
#   Claim "we should rewrite the legacy service in Rust":
#     >@!x → "We should not rewrite the legacy service in Rust. A full rewrite
#             demands significant engineering investment and carries real risk:
#             reimplementing years of business logic and edge-case handling from
#             scratch is likely to reintroduce defects the old code already
#             solved…"                                   (the steelmanned counter)
#     @x   → "We should rewrite the legacy service in Rust."   (the claim, held)
#
# Distinct from #31 pro/con (SYMMETRIC — both sides expanded equally): here the
# generosity is deliberately ONE-SIDED, aimed at the view you DON'T hold. Argue
# the other side better than they can, then reaffirm yours — the honest debater's
# opening. (Compare #08 steelman/strawman, which inflates one side and deflates
# the other; this steelmans the OPPONENT and leaves your claim unadorned.)
#
# Run:  ./examples/golf-aur1-34-fairhearing.sh
set -euo pipefail
cd "$(dirname "$0")/.."
NLIR="${NLIR:-./target/release/nlir}"
[ -x "$NLIR" ] || { echo "build first: cargo build --release (or set NLIR=...)"; exit 1; }
if [ -z "${LITELLM_MASTER_KEY:-}" ] && [ -n "${CACOPHONY_LITELLM_MASTER_KEY_FILE:-}" ]; then
  export LITELLM_MASTER_KEY="$(cat "$CACOPHONY_LITELLM_MASTER_KEY_FILE")"
fi
say() { printf '\n\033[1m%s\033[0m\n' "$1"; }
C='we should rewrite the legacy service in rust'

say "FAIR HEARING  [>@!x, @x]  — steelman the OPPOSING view, then hold your claim (asymmetric)"
echo   "  claim: $C"
echo -n "  >@!x (steelmanned counter) => "; "$NLIR" -e ">@!'$C'" --quiet | fold -s -w 86 | sed '2,$s/^/       /'
echo -n "  @x   (the claim, held)     => "; "$NLIR" -e "@'$C'" --quiet

say "One-sided generosity aimed at the view you DON'T hold — then reaffirm yours. (vs #31's symmetric pro/con.)"
