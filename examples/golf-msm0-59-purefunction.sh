#!/usr/bin/env bash
# nlir-golf · msm0 · #59 — "the pure function" (nlir transforms; it never fetches)
#
# The deepest truth about the TRANSFORM half of nlir, stated by naming its limit honestly:
# every operator is a PURE FUNCTION OF ITS INPUT. It reshapes what you give it — register,
# length, polarity, subject — but never FETCHES or INVENTS facts you didn't provide. The
# output's information is bounded by the input's:
#
#   ~'the server is slow'                          => "The server is slow."
#       nothing to distil — 1 bit in, 1 bit out (a fixed point by starvation, cf #58)
#   ~'the server is slow because of an N+1 query'  => keeps the CAUSE — because you GAVE it
#   >'the deploy failed'                           => elaborates the PHRASE with generic
#       framing ("a step encountered an error and halted the pipeline…") but invents NO
#       specific cause — it adds WORDS, not FACTS
#
# So nlir TRANSFORMS content; it does not reason FORWARD to a solution (aur-1's honest limit,
# #60). That's not a weakness — it's the defining property that makes the TRANSFORM half of
# nlir = SELECT × TRANSFORM predictable, and exactly why the deterministic substrate composes
# (#34, #58): input-bound = knowable. nlir is a LENS, not an oracle — it changes how you SEE
# what's there, never what's there.
set -euo pipefail
cd "$(dirname "$0")/.."
NLIR="${NLIR:-./target/release/nlir}"
[ -x "$NLIR" ] || { echo "build first: cargo build --release (or set NLIR=...)"; exit 1; }
CFG="${NLIR_CONFIG:-config.example.yaml}"
if [ -z "${LITELLM_MASTER_KEY:-}" ] && [ -n "${CACOPHONY_LITELLM_MASTER_KEY_FILE:-}" ]; then
  export LITELLM_MASTER_KEY="$(cat "$CACOPHONY_LITELLM_MASTER_KEY_FILE")"
fi

say() { printf '\n\033[1m%s\033[0m\n' "$1"; }
r() { printf '  %s\n    => ' "$1"; "$NLIR" --config "$CFG" --mode llm -e "$1" --quiet; }
say "the operator's output is bounded by its INPUT's information — reshape, never fetch:"
r "~'the server is slow'"
r "~'the server is slow because of an N+1 query in the users endpoint'"
r ">'the deploy failed'"
say "nlir is a LENS, not an oracle — it changes how you SEE what's there, never what's there."
