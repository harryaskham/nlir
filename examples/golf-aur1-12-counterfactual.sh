#!/usr/bin/env bash
# nlir-golf · aur1 · #12 — "the counterfactual"
#
# Negate a fact, then flesh out the world where it DIDN'T happen. `!` flips the
# claim; `>` elaborates the flip into a plausible alternate history — the road not
# taken, argued as if it were real.
#
#   COUNTERFACTUAL   >!x     (expand ∘ negate)
#     !x  turn "we DID x" into "we did NOT x"
#     >   spin that into a full account — the reasons, the fallout, the world-without-x
#
# Feed it "we migrated the database to Postgres last quarter" and it writes the
# timeline where the migration slipped: competing priorities, the platform still
# unchanged, a reschedule looming. A premortem / what-if engine from two sigils —
# useful for risk write-ups and "imagine we hadn't" retrospectives. The mirror of
# #08's steelman (>@x argues FOR; >!x elaborates the ABSENCE).
#
# Run:  ./examples/golf-aur1-12-counterfactual.sh
set -euo pipefail
cd "$(dirname "$0")/.."
NLIR="${NLIR:-./target/release/nlir}"
[ -x "$NLIR" ] || { echo "build first: cargo build --release (or set NLIR=...)"; exit 1; }
if [ -z "${LITELLM_MASTER_KEY:-}" ] && [ -n "${CACOPHONY_LITELLM_MASTER_KEY_FILE:-}" ]; then
  export LITELLM_MASTER_KEY="$(cat "$CACOPHONY_LITELLM_MASTER_KEY_FILE")"
fi
say() { printf '\n\033[1m%s\033[0m\n' "$1"; }

say "COUNTERFACTUAL  >!x  — expand ∘ negate = the road not taken, fleshed out"
echo "  fact: we migrated the database to Postgres last quarter"
echo -n "  >!fact => "
"$NLIR" -e ">!'we migrated the database to Postgres last quarter'" --quiet

say "! flips the fact, > builds the world-without-it — a premortem engine in two sigils."
