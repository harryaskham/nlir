#!/usr/bin/env bash
# nlir-TARGET-golf · aur1 · #15 — "the disambiguation question" (| ∘ ?)
#
# Combo lane: list two options with `|` (or), then question with `?` — and `?`
# reaches for the "is it X or Y?" IDENTIFICATION frame. The turn you type when
# you've seen something and aren't sure which of two things it is.
#
#   TARGET (31 chars):    "Is it a mutex or a semaphore?"
#   NLIR   (26 src chars): ('a mutex'|'a semaphore')?
#   REAL OUTPUT:          "Is it a mutex or a semaphore?"   (exact)
#
#   HOW IT NESTS: 'a mutex' | 'a semaphore' → "a mutex or a semaphore" (the `|`
#   or-join); the postfix `?` then wraps that in the "Is it …?" disambiguation
#   frame. Distinct from #08's should-I ('X or Y'? → "Should I use…?"): there the
#   seed was one verb phrase; here two nouns joined by `|` steer `?` to
#   identification rather than decision.
#
# Run:  ./examples/target-aur1-15-disambig.sh
set -euo pipefail
cd "$(dirname "$0")/.."
NLIR="${NLIR:-./target/release/nlir}"
[ -x "$NLIR" ] || { echo "build first: cargo build --release (or set NLIR=...)"; exit 1; }
if [ -z "${LITELLM_MASTER_KEY:-}" ] && [ -n "${CACOPHONY_LITELLM_MASTER_KEY_FILE:-}" ]; then
  export LITELLM_MASTER_KEY="$(cat "$CACOPHONY_LITELLM_MASTER_KEY_FILE")"
fi
say() { printf '\n\033[1m%s\033[0m\n' "$1"; }

say "TARGET (31 chars):  Is it a mutex or a semaphore?"
say "NLIR (26 src chars):  ('a mutex'|'a semaphore')?   —  ? ∘ |"
echo -n "  => "; "$NLIR" -e "('a mutex'|'a semaphore')?" --quiet

say "| lists the options, ? asks WHICH — the 'is it X or Y' identification turn."
