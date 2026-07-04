#!/usr/bin/env bash
# nlir-golf · aur1 · #66 — "the balanced brief" (both sides, developed in full, no thumb on the scale)
#
# The natural sequel to #65. There I built the opposition brief `>@!x` — the full case
# AGAINST a position. Here I stand it next to the full case FOR and let them face off:
#
#   BALANCED BRIEF   [ >x , >@!x ]
#     claim "we should rewrite the billing service from scratch"
#     >x   → "We should rewrite the billing service from scratch. Over time the current
#             implementation has accumulated substantial technical debt—patched fixes,
#             workarounds, legacy decisions that no longer fit…"          ← the case FOR
#     >@!x → "We should not rewrite the billing service from scratch. Doing so would
#             discard years of accumulated business logic, edge-case handling, and
#             hard-won bug fixes embedded in the existing codebase…"      ← the case AGAINST
#
# `>x` develops the claim into its best argument; `>@!x` develops its negation into the
# best argument the other way. Symmetric, both at full strength, and — crucially — NO
# synthesis: unlike #50 deliberation (which adds a `~(…&…)` verdict) this one refuses to
# pick, handing the reader two complete briefs to weigh. It's also the developed sibling of
# #31 pro/con (`[>x, >!x]`, two one-liners): here each side is a whole argument, not a bullet.
#
# Run:  ./examples/golf-aur1-66-balanced.sh
set -euo pipefail
cd "$(dirname "$0")/.."
NLIR="${NLIR:-./target/release/nlir}"
[ -x "$NLIR" ] || { echo "build first: cargo build --release (or set NLIR=...)"; exit 1; }
if [ -z "${LITELLM_MASTER_KEY:-}" ] && [ -n "${CACOPHONY_LITELLM_MASTER_KEY_FILE:-}" ]; then
  export LITELLM_MASTER_KEY="$(cat "$CACOPHONY_LITELLM_MASTER_KEY_FILE")"
fi
say() { printf '\n\033[1m%s\033[0m\n' "$1"; }
C='we should rewrite the billing service from scratch'

say "BALANCED BRIEF  [>x, >@!x]  — the full case FOR (>x) + the full case AGAINST (>@!x), symmetric, no verdict"
echo   "  claim: $C"
echo -n "  >x   (case FOR)     => "; "$NLIR" -e ">'$C'"   --quiet | fold -s -w 82 | sed '2,$s/^/       /'
echo -n "  >@!x (case AGAINST) => "; "$NLIR" -e ">@!'$C'" --quiet | fold -s -w 82 | sed '2,$s/^/       /'

say ">x develops the claim, >@!x develops its negation. No synthesis (unlike #50) — two full briefs to weigh. The developed #31 pro/con."
