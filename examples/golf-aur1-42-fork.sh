#!/usr/bin/env bash
# nlir-golf · aur1 · #42 — "the fork expander" (a binary choice → a decision analysis)
#
# Finally a real job for `|`. On its own, a|b just realises the two options as
# "A or B". But EXPAND the disjunction — >(a|b) — and nlir unfolds the fork into a
# balanced two-branch analysis: each path's upsides AND downsides, framed as the
# decision you're actually facing. Two option-names in, a whole decision memo out.
#
#   FORK EXPANDER   > ( a | b )
#     (a|b)   → "adopt kubernetes or stay on docker compose"          (just the fork)
#     >(a|b)  → "…whether to adopt Kubernetes — which provides automated scaling,
#                self-healing, load balancing, but adds operational complexity and a
#                steeper learning curve — or remain on Docker Compose, which is
#                simpler and lower-overhead, but lacks multi-node scaling and
#                resilience…"                                          (both branches, weighed)
#
# Note: the grouped operand keeps its ( ) in the output — nlir preserves grouping
# (a known quirk), so the memo reads as one parenthetical. Distinct from #31
# pro/con (a claim vs its NEGATION) — here the two arms are two INDEPENDENT
# alternatives, and `|` (choice) is doing the framing, not `&`. The "lay out my
# two options fairly" button.
#
# Run:  ./examples/golf-aur1-42-fork.sh
set -euo pipefail
cd "$(dirname "$0")/.."
NLIR="${NLIR:-./target/release/nlir}"
[ -x "$NLIR" ] || { echo "build first: cargo build --release (or set NLIR=...)"; exit 1; }
if [ -z "${LITELLM_MASTER_KEY:-}" ] && [ -n "${CACOPHONY_LITELLM_MASTER_KEY_FILE:-}" ]; then
  export LITELLM_MASTER_KEY="$(cat "$CACOPHONY_LITELLM_MASTER_KEY_FILE")"
fi
say() { printf '\n\033[1m%s\033[0m\n' "$1"; }
A='adopt kubernetes'; B='stay on docker compose'

say "FORK EXPANDER  >(a|b)  — expand a binary choice into a balanced two-branch decision analysis"
echo -n "  (a|b)  (just the fork)   => "; "$NLIR" -e "('$A'|'$B')" --quiet
echo    "  >(a|b) (both branches weighed) =>"; "$NLIR" -e ">('$A'|'$B')" --quiet | fold -s -w 88 | sed 's/^/     /'

say "| frames a genuine CHOICE (vs #31 pro/con's claim-vs-negation). Two option-names → a decision memo."
