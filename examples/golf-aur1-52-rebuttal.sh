#!/usr/bin/env bash
# nlir-golf · aur1 · #52 — "the rebuttal" (name the objection, then defend at length)
#
# The advocate's move. `[!x, >x]` states the OBJECTION to your claim tersely — `!x`
# gives the one-line "we shouldn't do this" — and then mounts the full DEFENCE — `>x`
# expands your claim into its complete, reasoned case. Objection acknowledged in a
# breath; answer given in depth. It's how you defend a decision in a doc: surface the
# pushback, then bury it in argument.
#
#   THE REBUTTAL   [ !x , >x ]
#     claim "we should write the payment logic test-first"
#     !x  → "we should not write the payment logic test-first"        ← the objection (terse)
#     >x  → "…this matters especially for payment logic because it deals with real money
#            and real risk — bugs here directly cost users or the business and are hard to
#            reverse once deployed — so establishing strong tests up front…"  ← the defence (full)
#
# The mirror-image of my #34 fair-hearing. Fair-hearing gives the OTHER side the big,
# generous steelman and states your own claim crisply — that's intellectual FAIRNESS.
# The rebuttal flips the emphasis: the objection gets one line, YOUR claim gets the full
# development — that's ADVOCACY. Same two moves (`!` and `>`), opposite generosity. Pick
# fair-hearing to reason honestly; pick the rebuttal to make the case.
#
# Run:  ./examples/golf-aur1-52-rebuttal.sh
set -euo pipefail
cd "$(dirname "$0")/.."
NLIR="${NLIR:-./target/release/nlir}"
[ -x "$NLIR" ] || { echo "build first: cargo build --release (or set NLIR=...)"; exit 1; }
if [ -z "${LITELLM_MASTER_KEY:-}" ] && [ -n "${CACOPHONY_LITELLM_MASTER_KEY_FILE:-}" ]; then
  export LITELLM_MASTER_KEY="$(cat "$CACOPHONY_LITELLM_MASTER_KEY_FILE")"
fi
say() { printf '\n\033[1m%s\033[0m\n' "$1"; }
C='we should write the payment logic test-first'

say "THE REBUTTAL  [!x, >x]  — objection in one line (!x), defence in full (>x): the advocate's move"
echo   "  claim: $C"
echo -n "  !x (the objection) => "; "$NLIR" -e "!'$C'" --quiet | fold -s -w 86 | sed '2,$s/^/       /'
echo    "  >x (the defence)   =>"; "$NLIR" -e ">'$C'" --quiet | fold -s -w 86 | sed 's/^/     /'

say "Mirror of #34 fair-hearing: it steelmans the OTHER side (fairness); the rebuttal buries the objection (advocacy)."
