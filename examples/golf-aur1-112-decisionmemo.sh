#!/usr/bin/env bash
# nlir-golf · aur1 · #112 — "the tight decision memo" (recommendation / risk / decision, [@~x, >@!x, x?])
#
# The one-screen decision doc — what a busy lead actually needs to make a call. `[@~x, >@!x, x?]`
# gives three things and nothing else: `@~x` the RECOMMENDATION (the proposal as one formal
# line), `>@!x` the RISK (the strongest developed case AGAINST — my #65), and `x?` the DECISION
# (the exact question on the table). Recommend, flag the danger, ask.
#
#   THE TIGHT DECISION MEMO   [ @~x , >@!x , x? ]
#     x = "we should drop support for internet explorer"
#     @~x  → "We recommend discontinuing support for Internet Explorer."       ← RECOMMENDATION
#     >@!x → "We should NOT discontinue support at this time — a meaningful slice of enterprise
#             users remain on IE, and dropping it risks locking them out…"      ← THE RISK
#     x?   → "Should we drop support for Internet Explorer?"                     ← THE DECISION
#
# It's the lean cousin of my #70 decision-packet (`[@x, >x, >@!x, x?]`): that one includes the
# full `>x` CASE FOR; this one DROPS it, because a decision-maker who trusts the recommendation
# doesn't need the sales pitch — they need the recommendation, the one thing that could make it
# wrong, and the question to answer. Three lines, one screen, actionable. (Contrast the #90
# one-pager, which PUBLISHES the whole document; this is the memo you paste into a thread.)
#
# Run:  ./examples/golf-aur1-112-decisionmemo.sh
set -euo pipefail
cd "$(dirname "$0")/.."
NLIR="${NLIR:-./target/release/nlir}"
[ -x "$NLIR" ] || { echo "build first: cargo build --release (or set NLIR=...)"; exit 1; }
if [ -z "${LITELLM_MASTER_KEY:-}" ] && [ -n "${CACOPHONY_LITELLM_MASTER_KEY_FILE:-}" ]; then
  export LITELLM_MASTER_KEY="$(cat "$CACOPHONY_LITELLM_MASTER_KEY_FILE")"
fi
say() { printf '\n\033[1m%s\033[0m\n' "$1"; }
C='we should drop support for internet explorer'

say "THE TIGHT DECISION MEMO  [@~x, >@!x, x?]  — RECOMMENDATION (@~x) / THE RISK (>@!x) / THE DECISION (x?)"
echo   "  x: $C"
echo -n "  @~x  (RECOMMENDATION) => "; "$NLIR" -e "@~'$C'" --quiet | fold -s -w 80 | sed '2,$s/^/       /'
echo -n "  >@!x (THE RISK)       => "; "$NLIR" -e ">@!'$C'" --quiet | fold -s -w 80 | sed '2,$s/^/       /'
echo -n "  x?   (THE DECISION)   => "; "$NLIR" -e "'$C'?"  --quiet | fold -s -w 80 | sed '2,$s/^/       /'

say "The lean cousin of #70 decision-packet [@x,>x,>@!x,x?]: DROPS the full >x case (a truster doesn't need the pitch) — just recommend, flag the one risk, ask. Three lines, one screen. (vs #90 one-pager = the full document.)"
