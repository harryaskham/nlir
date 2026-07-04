#!/usr/bin/env bash
# nlir-golf (aur-2) — "the plain tweet": simplify, then distil = short AND plain.
#
#     ~ ( : 'general relativity says gravity is not a force but the curvature of spacetime...' )
#     └distil┘└simplify┘└──────────────── a dense idea ────────────────┘
#
# : strips the jargon and makes it plain; ~ then squeezes the plain version down to a
# single tweet-length line. The friendly one-liner: plain AND short. Its formal twin is
# the polished takeaway ~@> (which ends on @, so formal-and-short) -- swap the middle op
# and the register flips from professional to approachable.
#
# Real output (claude-sonnet-5): "Gravity is the curving of space caused by heavy objects,
# which makes nearby things follow bent paths instead of a direct 'pull.'"
set -euo pipefail
cd "$(dirname "$0")/.."
NLIR="${NLIR:-target/release/nlir}"
CTX="$(mktemp)"; trap 'rm -f "$CTX"' EXIT

EXPR="~:'general relativity says gravity is not a force but the curvature of spacetime caused by mass and energy, and objects move along the straightest possible paths through that curved geometry'"

echo "concept:    the plain tweet -- simplify a dense idea, then distil to one plain short line"
echo "expression: ~:'general relativity says gravity is not a force but the curvature of spacetime...'"
echo "---"
"$NLIR" --context-file "$CTX" --mode llm -e "$EXPR"
