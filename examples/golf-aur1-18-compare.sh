#!/usr/bin/env bash
# nlir-golf · aur1 · #18 — "the comparison" (the stack workbench)
#
# Put two independent candidates on the stack and weigh them against each other.
# Where #16's diff was ONE thing changing (before → after), this is TWO separate
# options judged side by side — a static comparison, not a timeline.
#
#   COMPARE   'A' ; 'B' ; ~($-2 & $)
#     'A' ; 'B'   push two candidates onto the stack (your workbench)
#     $-2 & $     reach back to the first, join it with the second (top)
#     ~           distil the pair into a balanced "A is …, while B is …" contrast
#
# Push "REST is simple and stateless but needs many endpoints" and "GraphQL has
# one endpoint and flexible queries but adds complexity", and it returns "REST is
# simple but requires many endpoints, while GraphQL uses a single flexible
# endpoint at the cost of added complexity." The two options never share a
# literal — they sit on the stack and get contrasted by index.
#
# Run:  ./examples/golf-aur1-18-compare.sh
set -euo pipefail
cd "$(dirname "$0")/.."
NLIR="${NLIR:-./target/release/nlir}"
[ -x "$NLIR" ] || { echo "build first: cargo build --release (or set NLIR=...)"; exit 1; }
if [ -z "${LITELLM_MASTER_KEY:-}" ] && [ -n "${CACOPHONY_LITELLM_MASTER_KEY_FILE:-}" ]; then
  export LITELLM_MASTER_KEY="$(cat "$CACOPHONY_LITELLM_MASTER_KEY_FILE")"
fi
say() { printf '\n\033[1m%s\033[0m\n' "$1"; }

say "COMPARE  'A';'B';~(\$-2 & \$)  — two candidates on the stack, contrasted by index"
echo "  A: REST is simple and stateless but needs many endpoints"
echo "  B: GraphQL has one endpoint and flexible queries but adds complexity"
echo -n "  contrast => "
"$NLIR" -e "'REST is simple and stateless but needs many endpoints';'GraphQL has one endpoint and flexible queries but adds complexity';~(\$-2&\$)" --quiet

say "The stack is the workbench: push two options, \$-2 & \$ weighs them — a side-by-side, not a diff."
