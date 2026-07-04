#!/usr/bin/env bash
# nlir-golf · aur1 · #99 — "the skeptic" (expand the negation: the full case your belief is FALSE, >!x)
#
# Point nlir at your own confident belief and make it argue the OTHER way — hard. `>!x` negates
# first (`!` flips the claim), then expands (`>`) that negation into a full argument. The result
# is the disconfirming case: not "here's a caveat", but "here's the serious case that this is
# simply FALSE." Steelman the null hypothesis before you bet on the claim.
#
#   THE SKEPTIC   > !x
#     x = "adding more engineers to the project will make us ship faster"
#     >!x → "Adding more engineers will NOT make us ship faster. Software isn't manual labour
#            where doubling the workforce halves the time — it's interdependent; new people
#            need ramp-up, add communication overhead…"   (Brooks's law, argued in full)
#
# The order matters (my #87 negate-early): `!` acts on the CLAIM to flip it, THEN `>` builds the
# argument for the flipped version — so you get a coherent case, not a claim with every clause
# perversely inverted. And it's distinct from my #65 opposition brief `>@!x`: the `@` there
# adds a measured, formal register ("may in fact slow delivery…") — the diplomat's counter-
# proposal; bare `>!x` is the raw skeptic, blunt and direct ("this just won't work, because…").
# Same target, two temperaments: the memo vs the heckler.
#
# Run:  ./examples/golf-aur1-99-skeptic.sh
set -euo pipefail
cd "$(dirname "$0")/.."
NLIR="${NLIR:-./target/release/nlir}"
[ -x "$NLIR" ] || { echo "build first: cargo build --release (or set NLIR=...)"; exit 1; }
if [ -z "${LITELLM_MASTER_KEY:-}" ] && [ -n "${CACOPHONY_LITELLM_MASTER_KEY_FILE:-}" ]; then
  export LITELLM_MASTER_KEY="$(cat "$CACOPHONY_LITELLM_MASTER_KEY_FILE")"
fi
say() { printf '\n\033[1m%s\033[0m\n' "$1"; }
C='adding more engineers to the project will make us ship faster'

say "THE SKEPTIC  >!x  — negate the belief, then expand: the full case it is FALSE"
echo   "  belief: $C"
echo -n "  >!x (the skeptic's case) => "; "$NLIR" -e ">!'$C'" --quiet | fold -s -w 80 | sed '2,$s/^/       /'

say "! flips the CLAIM first (#87 negate-early), then > argues the flipped version in full. vs #65 opposition >@!x (the @ adds a formal, measured register — the diplomat); bare >!x is the raw skeptic."
