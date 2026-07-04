#!/usr/bin/env bash
# nlir-golf · aur1 · #65 — "the opposition brief" (the best case AGAINST your own position)
#
# The single most useful thing before you commit to a position: the strongest argument
# against it, spelled out in full. `>@!x` builds exactly that — `!` flips your claim to its
# opposite, `@` dresses that opposite as a serious position, and `>` develops it into a
# complete brief. Not a snarky one-line rebuttal — the actual case the other side would
# make, at its strongest, so you can meet it before someone else does.
#
#   OPPOSITION BRIEF   > @ ! x
#     claim "we should adopt a four-day work week"
#     !x   → "we should not adopt a four-day work week"                 (the flip)
#     >@!x → "The organization should not adopt a four-day work week. While the concept may
#             seem appealing—an extra day off, improved morale, better work-life balance—the
#             practical drawbacks make it unwise: condensing the same volume of work into
#             fewer days…"                                              (the full case against)
#
# Read the order right-to-left as a build: negate the position, formalise it into a stance,
# expand it into an argument. I've used `>@!x` as a COMPONENT before — one arm of #34's
# fair-hearing and #50's deliberation — but on its own it's the steelman of the other side:
# the opposition's best brief, handed to you so nothing blindsides you. (Distinct from #06's
# `@!x`, the one-line diplomatic pushback: this one is developed, not a jab.)
#
# Run:  ./examples/golf-aur1-65-opposition.sh
set -euo pipefail
cd "$(dirname "$0")/.."
NLIR="${NLIR:-./target/release/nlir}"
[ -x "$NLIR" ] || { echo "build first: cargo build --release (or set NLIR=...)"; exit 1; }
if [ -z "${LITELLM_MASTER_KEY:-}" ] && [ -n "${CACOPHONY_LITELLM_MASTER_KEY_FILE:-}" ]; then
  export LITELLM_MASTER_KEY="$(cat "$CACOPHONY_LITELLM_MASTER_KEY_FILE")"
fi
say() { printf '\n\033[1m%s\033[0m\n' "$1"; }
C='we should adopt a four-day work week'

say "OPPOSITION BRIEF  >@!x  — the strongest, fully-developed formal case AGAINST your position"
echo   "  claim: $C"
echo -n "  !x   (the flip)        => "; "$NLIR" -e "!'$C'"   --quiet | fold -s -w 82 | sed '2,$s/^/       /'
echo -n "  >@!x (the case against) => "; "$NLIR" -e ">@!'$C'" --quiet | fold -s -w 82 | sed '2,$s/^/       /'

say "! flips, @ makes it a serious stance, > develops it. The other side's best brief — used solo (was a #34/#50 component)."
