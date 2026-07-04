#!/usr/bin/env bash
# nlir-golf · aur1 · #57 — "the review-proof proposal" (state it, pre-empt it, defend it)
#
# How you write a proposal that survives a code review. `[@x, !x, >x]` builds a
# three-part card from one idea: `@x` states the PROPOSAL formally, `!x` surfaces the
# OBJECTION a reviewer will raise, and `>x` mounts the RESPONSE — the full case for the
# idea. Anticipate the pushback and answer it in the same breath you make the pitch.
#
#   REVIEW-PROOF PROPOSAL   [ @x , !x , >x ]
#     idea "adopt a monorepo for all our services"
#     @x  → "We recommend adopting a monorepo architecture to consolidate all our
#            services."                                            ← the PROPOSAL
#     !x  → "don't adopt a monorepo for all our services"          ← the OBJECTION (terse)
#     >x  → "We should consolidate all services into a single monorepo rather than
#            maintaining separate repos; housing every service in one codebase gives
#            atomic cross-service changes, shared tooling, unified CI…"  ← the RESPONSE
#
# It extends my #52 rebuttal (`[!x, >x]` = objection then defence) by leading with the
# formal PROPOSAL — so the card is self-contained: a reader sees WHAT you're proposing,
# the strongest objection to it, and your answer, without needing the surrounding thread.
# Paste it straight into the design doc; the review's first round is already in it.
#
# Run:  ./examples/golf-aur1-57-reviewproof.sh
set -euo pipefail
cd "$(dirname "$0")/.."
NLIR="${NLIR:-./target/release/nlir}"
[ -x "$NLIR" ] || { echo "build first: cargo build --release (or set NLIR=...)"; exit 1; }
if [ -z "${LITELLM_MASTER_KEY:-}" ] && [ -n "${CACOPHONY_LITELLM_MASTER_KEY_FILE:-}" ]; then
  export LITELLM_MASTER_KEY="$(cat "$CACOPHONY_LITELLM_MASTER_KEY_FILE")"
fi
say() { printf '\n\033[1m%s\033[0m\n' "$1"; }
C='adopt a monorepo for all our services'

say "REVIEW-PROOF PROPOSAL  [@x, !x, >x]  — the PROPOSAL, the OBJECTION reviewers raise, the RESPONSE"
echo   "  idea: $C"
echo -n "  @x (PROPOSAL)  => "; "$NLIR" -e "@'$C'" --quiet | fold -s -w 84 | sed '2,$s/^/       /'
echo -n "  !x (OBJECTION) => "; "$NLIR" -e "!'$C'" --quiet | fold -s -w 84 | sed '2,$s/^/       /'
echo    "  >x (RESPONSE)  =>"; "$NLIR" -e ">'$C'" --quiet | fold -s -w 84 | sed 's/^/     /'

say "Extends #52 rebuttal by leading with the formal proposal — a self-contained card, the review's first round baked in."
