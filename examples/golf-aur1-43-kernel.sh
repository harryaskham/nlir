#!/usr/bin/env bash
# nlir-golf · aur1 · #43 — "the essence kernel" (~ converges, by shedding detail)
#
# Back in #05 I showed repeated ~ keeps distilling. But does it distil FOREVER, or
# converge? It converges — to an irreducible KERNEL. The LENGTH asymptotes (~16
# words down to ~10 and then it stops shrinking), and the output settles on the
# single core fact. Which secondary detail survives ("drop-off") varies run to run;
# the constant is the floor: "three screens → better completion."
#
#   ESSENCE KERNEL   ~x → ~~x → ~~~x → … → the core (length asymptotes ~16w → ~10w)
#     ~x     (~16w) "Reducing the onboarding flow to three screens cut user drop-off
#                    and greatly improved completion rates."
#     ~~x    (~13w) "Cutting the onboarding flow to three screens reduced drop-off and
#                    boosted completion rates."
#     ~~~x   (~11w) "Simplifying onboarding to three screens boosted completion by cutting drop-off."
#     ~~~~~x (~10w) "Reducing onboarding to three screens boosted completion."  ← kernel (plateaus)
#
# Crucial contrast with #35's compression floor: `<` asymptotes while keeping ALL
# the facts (it only tightens wording); `~` asymptotes by SHEDDING facts down to
# the one that matters. Two different floors — < = the tightest FULL statement,
# ~ = the single ESSENTIAL point. Completes the repetition-dynamics family:
#     !  involution (period 2, #25) · @ register ceiling (#23)
#     <  info floor, keeps all facts (#35) · ~ essence kernel, keeps the core (this one)
#
# Run:  ./examples/golf-aur1-43-kernel.sh
set -euo pipefail
cd "$(dirname "$0")/.."
NLIR="${NLIR:-./target/release/nlir}"
[ -x "$NLIR" ] || { echo "build first: cargo build --release (or set NLIR=...)"; exit 1; }
if [ -z "${LITELLM_MASTER_KEY:-}" ] && [ -n "${CACOPHONY_LITELLM_MASTER_KEY_FILE:-}" ]; then
  export LITELLM_MASTER_KEY="$(cat "$CACOPHONY_LITELLM_MASTER_KEY_FILE")"
fi
say() { printf '\n\033[1m%s\033[0m\n' "$1"; }
wc_w() { printf '%s' "$1" | wc -w | tr -d ' '; }
S='the onboarding flow has too many steps, users drop off before finishing, and simplifying it to three screens improved completion dramatically'

say "ESSENCE KERNEL  ~x → ~~x → ~~~x → ~~~~x → ~~~~~x  — ~ converges by shedding detail to the core"
for k in '~' '~~' '~~~' '~~~~' '~~~~~'; do
  O="$("$NLIR" -e "${k}'$S'" --quiet)"; echo "  ${k}x ($(wc_w "$O")w): $O" | fold -s -w 88 | sed '2,$s/^/       /'
done

say "~ sheds facts to the ESSENTIAL one (kernel); < keeps ALL facts, tightens wording (info floor #35). Two floors."
