#!/usr/bin/env bash
# nlir-golf · aur1 · #83 — "the pre-mortem" (state the plan, then autopsy its failure)
#
# The best risk-surfacing move a team can make: before you ship, imagine it already shipped
# and FAILED, and write the autopsy. `[~x, >@!x]` does exactly that — `~x` states the plan in
# a line, and `>@!x` (my opposition brief) develops the full case AGAINST it, which reads as
# the list of ways it goes wrong. Not "should we?" — "assume we did and it broke: why?"
#
#   THE PRE-MORTEM   [ ~x , >@!x ]
#     plan "we should ship the new checkout flow to 100% of users on friday"
#     ~x   → "Plan to roll out the new checkout flow to all users on Friday."     ← the PLAN
#     >@!x → "It is recommended that the new checkout flow NOT be deployed to 100% of users on
#             Friday. Pushing a major change to the entire user base right before the weekend
#             carries elevated risk, since engineering, QA, and support are less available on
#             weekends to monitor and respond…"                                   ← the AUTOPSY
#
# The autopsy named the real hazards — the Friday timing, the weekend coverage gap, the
# blast radius of 100% — none of which the cheerful plan mentions. It's built from #65's
# opposition brief, but pointed at your OWN plan and framed as failure: distinct from #65
# (the counter to any claim) and #66 balanced (full case FOR *and* against) — this leads with
# the plan, then hands you only the downside, on purpose, so you can de-risk before you commit.
#
# Run:  ./examples/golf-aur1-83-premortem.sh
set -euo pipefail
cd "$(dirname "$0")/.."
NLIR="${NLIR:-./target/release/nlir}"
[ -x "$NLIR" ] || { echo "build first: cargo build --release (or set NLIR=...)"; exit 1; }
if [ -z "${LITELLM_MASTER_KEY:-}" ] && [ -n "${CACOPHONY_LITELLM_MASTER_KEY_FILE:-}" ]; then
  export LITELLM_MASTER_KEY="$(cat "$CACOPHONY_LITELLM_MASTER_KEY_FILE")"
fi
say() { printf '\n\033[1m%s\033[0m\n' "$1"; }
C='we should ship the new checkout flow to 100% of users on friday'

say "THE PRE-MORTEM  [~x, >@!x]  — the PLAN (~x) + the FAILURE AUTOPSY (>@!x): 'assume it broke — why?'"
echo   "  plan: $C"
echo -n "  ~x   (the PLAN)    => "; "$NLIR" -e "~'$C'"   --quiet | fold -s -w 82 | sed '2,$s/^/       /'
echo -n "  >@!x (the AUTOPSY) => "; "$NLIR" -e ">@!'$C'" --quiet | fold -s -w 82 | sed '2,$s/^/       /'

say "~x states the plan; >@!x (the opposition brief, #65) autopsies its failure. Leads with the plan, hands you only the downside — de-risk before you commit."
