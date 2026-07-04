#!/usr/bin/env bash
# nlir-golf · aur1 · #108 — "the honest proposal" (a crisp idea + the objection at full strength, [~>x, >!x])
#
# The opposite of a sales pitch. `[~>x, >!x]` states the proposal TIGHT and then gives the
# counter-argument ROOM: `~>x` (my #22 telephone — expand to draw out the rationale, then
# distil) puts the idea and its point in one clean statement; `>!x` (my #99 skeptic — negate
# then expand) argues the full case AGAINST. The asymmetry is deliberate: one line to say what
# you want, a paragraph to honestly air why it might be wrong.
#
#   THE HONEST PROPOSAL   [ ~>x , >!x ]
#     x = "we should let the AI auto-merge any PR that passes CI"
#     ~>x → "Let AI auto-merge any PR that passes CI — removing manual approval to speed up the
#            development workflow."                                          ← the crisp PROPOSAL
#     >!x → "Human review adds judgment and context automated checks can't replace — a reviewer
#            weighs whether a change makes sense for the project's goals, catches design
#            problems tests miss, spreads knowledge…"                        ← the FULL objection
#
# Why asymmetric? A symmetric layout (my #101 steelman-duel, `[>x, >!x]`) gives BOTH sides full
# essays — a balanced debate. This deliberately UNDERweights the proposal (one crisp line) and
# OVERweights the doubt (full argument), so the reader isn't sold — they're handed the idea and
# then made to sit with the strongest reason not to. The honest way to float something you
# suspect is risky: say it plainly, then steelman the pushback against yourself.
#
# Run:  ./examples/golf-aur1-108-honestproposal.sh
set -euo pipefail
cd "$(dirname "$0")/.."
NLIR="${NLIR:-./target/release/nlir}"
[ -x "$NLIR" ] || { echo "build first: cargo build --release (or set NLIR=...)"; exit 1; }
if [ -z "${LITELLM_MASTER_KEY:-}" ] && [ -n "${CACOPHONY_LITELLM_MASTER_KEY_FILE:-}" ]; then
  export LITELLM_MASTER_KEY="$(cat "$CACOPHONY_LITELLM_MASTER_KEY_FILE")"
fi
say() { printf '\n\033[1m%s\033[0m\n' "$1"; }
C='we should let the AI auto-merge any PR that passes CI'

say "THE HONEST PROPOSAL  [~>x, >!x]  — the crisp PROPOSAL (~>x, one line) + the FULL objection (>!x)"
echo   "  x: $C"
echo -n "  ~>x (the crisp PROPOSAL) => "; "$NLIR" -e "~>'$C'" --quiet | fold -s -w 80 | sed '2,$s/^/       /'
echo -n "  >!x (the FULL objection) => "; "$NLIR" -e ">!'$C'" --quiet | fold -s -w 80 | sed '2,$s/^/       /'

say "Deliberately asymmetric: one crisp line for the idea, a full argument for the doubt — you're not sold, you're handed the idea + made to sit with the strongest reason not to. vs #101 steelman-duel [>x,>!x] (symmetric, both full)."
