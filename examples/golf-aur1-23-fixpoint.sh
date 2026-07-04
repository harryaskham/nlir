#!/usr/bin/env bash
# nlir-golf · aur1 · #23 — "the register ceiling" (a semantic fixpoint)
#
# You might expect stacking `@` (formalise) to escalate into ever-more-pompous
# corporate-speak. It doesn't. `@` hits a FORMALITY CEILING after one pass: a
# casual note becomes a polished formal one, and every further `@` only REWORDS
# it at the same register — same meaning, same politeness, different sentence.
# The MEANING converges to a fixpoint even though the exact string keeps drifting.
#
#   REGISTER CEILING   @x  ≈  @@x  ≈  @@@x   (in meaning + register, not verbatim)
#     @x    casual → formal          "I would like to schedule time to meet for coffee…"
#     @@x   same register, reworded   "I would like to invite you to a coffee meeting…"
#     @@@x  same register, reworded   "I would like to arrange a time to meet, perhaps over coffee…"
#
# This is the counterpart to #05 (recursion-is-intensity): `~~~` keeps distilling
# toward the ESSENCE, adding compression each pass; `@@@` adds NOTHING after the
# first — it's already at the ceiling and just paraphrases. Knowing an op saturates
# tells you a second application is wasted effort (unlike ~, where depth = gain).
#
# Run:  ./examples/golf-aur1-23-fixpoint.sh
set -euo pipefail
cd "$(dirname "$0")/.."
NLIR="${NLIR:-./target/release/nlir}"
[ -x "$NLIR" ] || { echo "build first: cargo build --release (or set NLIR=...)"; exit 1; }
if [ -z "${LITELLM_MASTER_KEY:-}" ] && [ -n "${CACOPHONY_LITELLM_MASTER_KEY_FILE:-}" ]; then
  export LITELLM_MASTER_KEY="$(cat "$CACOPHONY_LITELLM_MASTER_KEY_FILE")"
fi
say() { printf '\n\033[1m%s\033[0m\n' "$1"; }
S='lets grab coffee and chat about the roadmap'

say "REGISTER CEILING  @ / @@ / @@@  — formalise SATURATES (meaning stable, only wording drifts)"
echo "  seed: $S"
echo -n "  @x   => "; "$NLIR" -e "@'$S'" --quiet
echo -n "  @@x  => "; "$NLIR" -e "@@'$S'" --quiet
echo -n "  @@@x => "; "$NLIR" -e "@@@'$S'" --quiet

say "@@x ≈ @@@x in meaning+register: @ saturates after one pass, then just paraphrases. Unlike ~, depth adds nothing."
