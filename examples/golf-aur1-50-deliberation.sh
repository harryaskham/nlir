#!/usr/bin/env bash
# nlir-golf · aur1 · #50 — "the deliberation" (a full fair briefing on a contested call) · MILESTONE
#
# Fiftieth example — a capstone that weaves six operators into one expression and does
# a whole piece of thinking. Feed it a contested proposal and `[>@x, >@!x, ~(>@x&>@!x)]`
# returns a complete, balanced briefing: the developed case FOR, the developed case
# AGAINST, and an impartial synthesis of the tension between them.
#
#   THE DELIBERATION   [ >@x , >@!x , ~(>@x & >@!x) ]
#     >@x           = expand ∘ formalise           → the STRONGEST case for the proposal
#     >@!x          = expand ∘ formalise ∘ negate   → the STRONGEST case against it
#     ~(>@x & >@!x) = summarise both together       → the neutral weighing of the two
#
#   Proposal "we should adopt a four-day work week":
#     >@x   → "…compressing the schedule while maintaining productivity and pay would
#              benefit employees and the business…"                (the case for)
#     >@!x  → "…we recommend against it at this time; while appealing, it risks
#              productivity, competitiveness, and coverage…"       (the case against)
#     ~(…)  → "The text presents opposing arguments for and against a four-day week,
#              weighing well-being and retention benefits against risks to productivity,
#              competitiveness, and logistics."                    (the impartial synthesis)
#
# The honest capstone point: the synthesis `~` FRAMES the tradeoff — it names what's
# being weighed — but it does NOT pick a winner. `~` synthesises and describes; it does
# not adjudicate. So the deliberation hands you a fair, fully-argued briefing and leaves
# the DECISION where it belongs — with you. Every earlier idea in one line: expand,
# formalise, negate, join, summarise, list. That's the whole toolkit, thinking.
#
# Run:  ./examples/golf-aur1-50-deliberation.sh
set -euo pipefail
cd "$(dirname "$0")/.."
NLIR="${NLIR:-./target/release/nlir}"
[ -x "$NLIR" ] || { echo "build first: cargo build --release (or set NLIR=...)"; exit 1; }
if [ -z "${LITELLM_MASTER_KEY:-}" ] && [ -n "${CACOPHONY_LITELLM_MASTER_KEY_FILE:-}" ]; then
  export LITELLM_MASTER_KEY="$(cat "$CACOPHONY_LITELLM_MASTER_KEY_FILE")"
fi
say() { printf '\n\033[1m%s\033[0m\n' "$1"; }
C='we should adopt a four day work week'

say "THE DELIBERATION  [>@x, >@!x, ~(>@x&>@!x)]  — the case FOR, the case AGAINST, the impartial synthesis"
echo   "  proposal: $C"
echo -n "  >@x  (strongest FOR)     => "; "$NLIR" -e ">@'$C'" --quiet | fold -s -w 84 | sed '2,$s/^/       /'
echo -n "  >@!x (strongest AGAINST) => "; "$NLIR" -e ">@!'$C'" --quiet | fold -s -w 84 | sed '2,$s/^/       /'
echo -n "  ~(>@x&>@!x) (synthesis)  => "; "$NLIR" -e "~(>@'$C' & >@!'$C')" --quiet | fold -s -w 84 | sed '2,$s/^/       /'

say "Six operators, one line: expand·formalise·negate·join·summarise·list. ~ FRAMES the tradeoff; it leaves the CALL to you."
