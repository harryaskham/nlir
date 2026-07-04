#!/usr/bin/env bash
# nlir-golf · aur1 · #96 — "the debate digest" (build both cases on the STACK, then fold + distil)
#
# The stack as a reasoning scratchpad. Most of my cards compute in one expression; this one
# thinks in STEPS, holding intermediate results in working memory. `>x; >@!x; &; ~$`:
#
#   >x        build the case FOR       → push onto the stack
#   >@!x      build the case AGAINST   → push onto the stack   (>@!x = my #65 opposition brief)
#   &         nullary fold: JOIN the whole stack into one for-and-against document
#   ~$        summarise the top ($)    → one neutral paragraph capturing both sides
#
#   x = "we should rewrite the service in rust"
#   >x   → "We should rewrite… Rust's safety and performance would…"      (pushed: the FOR)
#   >@!x → "We should refrain from a full rewrite at this time… cost, risk…" (pushed: the AGAINST)
#   DIGEST → "Arguments both for and against rewriting in Rust — weighing safety and performance
#             gains against the cost, risk, and disruption of a full rewrite."
#
# It's a genuine STACK program: `;` pushes, nullary `&` folds EVERYTHING on the stack, `$`
# peeks the result. You could inline it as `~(>x & >@!x)`, but writing it on the stack is the
# point — you construct each argument as its OWN step, then collapse working memory into one
# impartial paragraph. HONEST NOTE: `~` over a joined `(for & against)` is polymorphic (my #69)
# — some runs WEIGH the two ("gains against cost/risk"), some just STATE the tension ("presents
# both sides"); either way it's the neutral two-sided digest, never a partisan take. Distinct
# from #66 balanced-brief (which LISTS the two sides as separate items) and #85 counterpoint
# (only the objection): this FOLDS both into one paragraph — the debate in a sentence.
#
# Run:  ./examples/golf-aur1-96-digest.sh
set -euo pipefail
cd "$(dirname "$0")/.."
NLIR="${NLIR:-./target/release/nlir}"
[ -x "$NLIR" ] || { echo "build first: cargo build --release (or set NLIR=...)"; exit 1; }
if [ -z "${LITELLM_MASTER_KEY:-}" ] && [ -n "${CACOPHONY_LITELLM_MASTER_KEY_FILE:-}" ]; then
  export LITELLM_MASTER_KEY="$(cat "$CACOPHONY_LITELLM_MASTER_KEY_FILE")"
fi
say() { printf '\n\033[1m%s\033[0m\n' "$1"; }
C='we should rewrite the service in rust'

say "THE DEBATE DIGEST  >x; >@!x; &; ~\$  — push the case FOR, push the case AGAINST, fold, distil to one paragraph"
echo   "  x: $C"
echo -n "  >x; >@!x; &; ~\$ (the DIGEST) => "; "$NLIR" -e ">'$C'; >@!'$C'; &; ~\$" --quiet | fold -s -w 80 | sed '2,$s/^/       /'

say "A STACK program: ; pushes each argument, nullary & folds the WHOLE stack, ~\$ distils the top. Construct-then-collapse into the neutral two-sided digest (~ over for&against is polymorphic #69: may weigh or state the tension). vs #66 balanced (LISTS both) / #85 counterpoint (only the objection)."
