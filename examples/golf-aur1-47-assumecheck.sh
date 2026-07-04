#!/usr/bin/env bash
# nlir-golf · aur1 · #47 — "the assumption checker" (the premise-stack's third exit)
#
# The premise-stack has three exits, and this is the last one. #17 folded and
# SUMMARISED (bullets → the point). #46 folded and EXPANDED (bullets → prose). This
# folds and QUESTIONS: `a;b;c;&;$?` takes the facts you're leaning on, and `?`
# distributes over the conjunction to turn EACH one back into a verification
# question — the "before you act on these, are they actually true?" checklist.
#
#   ASSUMPTION CHECKER   a ; b ; c ; & ; $?
#     stacked assumptions: "contract up for renewal" · "their price rose 30%" ·
#                          "a cheaper competitor just launched"
#     &   → "The contract is up for renewal, their price went up 30%, and a cheaper
#            competitor just launched."                            (asserted as fact)
#     &;$? → "Is the contract up for renewal, did their price go up 30%, and did a
#            cheaper competitor just launch?"                       (each fact → a check)
#
# So one premise-stack, three altitudes: compress it to the point (~$, #17), inflate
# it to prose (>$, #46), or interrogate it for verification ($?, this one). Handy
# before a big call — you jotted the reasons; now flip them into the questions that
# confirm the reasons are real. (? distributes into per-clause checks — the join is
# ordered, so the checklist keeps your order.)
#
# Run:  ./examples/golf-aur1-47-assumecheck.sh
set -euo pipefail
cd "$(dirname "$0")/.."
NLIR="${NLIR:-./target/release/nlir}"
[ -x "$NLIR" ] || { echo "build first: cargo build --release (or set NLIR=...)"; exit 1; }
if [ -z "${LITELLM_MASTER_KEY:-}" ] && [ -n "${CACOPHONY_LITELLM_MASTER_KEY_FILE:-}" ]; then
  export LITELLM_MASTER_KEY="$(cat "$CACOPHONY_LITELLM_MASTER_KEY_FILE")"
fi
say() { printf '\n\033[1m%s\033[0m\n' "$1"; }
P="'the vendor contract is up for renewal';'their price went up 30 percent';'a cheaper competitor just launched'"

say "ASSUMPTION CHECKER  a;b;c;&;\$?  — fold your assumptions, then ? turns each into a verification check"
echo -n "  &    (asserted as fact) => "; "$NLIR" -e "${P};&" --quiet | fold -s -w 86 | sed '2,$s/^/       /'
echo -n "  &;\$? (checklist)        => "; "$NLIR" -e "${P};&;\$?" --quiet | fold -s -w 86 | sed '2,$s/^/       /'

say "Premise-stack, three exits: ~\$ the point (#17), >\$ the prose (#46), \$? the checks (this). Verify before you rely."
