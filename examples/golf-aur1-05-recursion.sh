#!/usr/bin/env bash
# nlir-golf · aur1 · #05 — "recursion is intensity"
#
# Fresh angle: nlir operators are just functions, so you can STACK the same one.
# Repetition = dial. Summarise once and you get a tidy paragraph; summarise the
# summary and it tightens; summarise again and you reach the irreducible core.
# Depth of recursion == aggressiveness of distillation — a compression knob spelled
# in tildes.
#
#   ~x    one pass   — a clean summary (still a full sentence or two)
#   ~~x   two passes  — the summary of that summary, tighter
#   ~~~x  three passes — the essence; what survives being distilled three times
#
# No new operator, no config — you turn the knob by repeating the sigil. `<<<x`
# does the same with hard shortening; `>>x` runs it in reverse (elaborate twice).
#
# Run:  ./examples/golf-aur1-05-recursion.sh
set -euo pipefail
cd "$(dirname "$0")/.."
NLIR="${NLIR:-./target/release/nlir}"
[ -x "$NLIR" ] || { echo "build first: cargo build --release (or set NLIR=...)"; exit 1; }
if [ -z "${LITELLM_MASTER_KEY:-}" ] && [ -n "${CACOPHONY_LITELLM_MASTER_KEY_FILE:-}" ]; then
  export LITELLM_MASTER_KEY="$(cat "$CACOPHONY_LITELLM_MASTER_KEY_FILE")"
fi
say() { printf '\n\033[1m%s\033[0m\n' "$1"; }
P='Our engineering org has grown from 8 to 45 people in eighteen months, and the single shared deployment pipeline that once served us well now causes constant contention, with teams queuing for hours and stepping on each other releases, which is why we are evaluating a move to independently deployable services.'

say "RECURSION IS INTENSITY  ~ / ~~ / ~~~  — each extra tilde distils harder"
echo "  (source: a 300-char paragraph about outgrowing a shared deploy pipeline)"
echo -n "  ~x   => "; "$NLIR" -e "~'$P'" --quiet
echo -n "  ~~x  => "; "$NLIR" -e "~~'$P'" --quiet
echo -n "  ~~~x => "; "$NLIR" -e "~~~'$P'" --quiet

say "Same operator, repeated = a compression dial. Depth of recursion is intensity."
