#!/usr/bin/env bash
# nlir-TARGET-golf · aur1 · #11 — "the when-question"
#
# Sixth `?` mood (after how-do-I / what-is / why / should-I / how-much): the
# TIMING question — "when should I …?" — the choice-of-moment turn. Seed a "when
# to X" phrase; `?` supplies the "When should you …?" frame.
#
#   TARGET (48 chars):    "When should you use an Arc instead of a Box?"
#   NLIR   (36 src chars): 'when to use an arc instead of a box'?
#   REAL OUTPUT:          "When should you use an arc instead of a box?"   (exact*)
#     *modulo Arc/Box capitalisation, which varies run-to-run.
#
#   CLOSENESS: exact wording. The "when to …" seed shape is what steers `?` to the
#   temporal frame — drop the "when to" and the same seed becomes a should-I
#   question. Six moods now from one operator (how / what / why / should / how-much
#   / when), each chosen purely by the seed's phrasing.
#
# Run:  ./examples/target-aur1-11-when.sh
set -euo pipefail
cd "$(dirname "$0")/.."
NLIR="${NLIR:-./target/release/nlir}"
[ -x "$NLIR" ] || { echo "build first: cargo build --release (or set NLIR=...)"; exit 1; }
if [ -z "${LITELLM_MASTER_KEY:-}" ] && [ -n "${CACOPHONY_LITELLM_MASTER_KEY_FILE:-}" ]; then
  export LITELLM_MASTER_KEY="$(cat "$CACOPHONY_LITELLM_MASTER_KEY_FILE")"
fi
say() { printf '\n\033[1m%s\033[0m\n' "$1"; }

say "TARGET (48 chars):  When should you use an Arc instead of a Box?"
say "NLIR (36 src chars):  'when to use an arc instead of a box'?"
echo -n "  => "; "$NLIR" -e "'when to use an arc instead of a box'?" --quiet

say "Sixth ? mood: the 'when to X' shape steers ? to the timing frame. Six moods, one operator."
