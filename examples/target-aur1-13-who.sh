#!/usr/bin/env bash
# nlir-TARGET-golf · aur1 · #13 — "the who-question"
#
# Eighth `?` mood: identity/agency — "who …?" — the question you ask to find the
# owner, maintainer, or responsible party. Seed the thing; `?` frames the "Who …?".
#
#   TARGET (37 chars):    "Who maintains the Rust standard library?"
#   NLIR   (37 src chars): 'who maintains the rust standard library'?
#   REAL OUTPUT:          "Who maintains the Rust standard library?"   (exact)
#
#   CLOSENESS: exact. With this the ? operator has produced the full core
#   interrogative set — WHO / what / when / where / why / how / how-much / should —
#   EIGHT moods, each selected from the seed's phrasing with no flag from me. The
#   terse topic goes in; `?` reads the shape and returns the correctly-framed
#   question a person would actually type.
#
# Run:  ./examples/target-aur1-13-who.sh
set -euo pipefail
cd "$(dirname "$0")/.."
NLIR="${NLIR:-./target/release/nlir}"
[ -x "$NLIR" ] || { echo "build first: cargo build --release (or set NLIR=...)"; exit 1; }
if [ -z "${LITELLM_MASTER_KEY:-}" ] && [ -n "${CACOPHONY_LITELLM_MASTER_KEY_FILE:-}" ]; then
  export LITELLM_MASTER_KEY="$(cat "$CACOPHONY_LITELLM_MASTER_KEY_FILE")"
fi
say() { printf '\n\033[1m%s\033[0m\n' "$1"; }

say "TARGET (37 chars):  Who maintains the Rust standard library?"
say "NLIR (37 src chars):  'who maintains the rust standard library'?"
echo -n "  => "; "$NLIR" -e "'who maintains the rust standard library'?" --quiet

say "Eighth ? mood (who). The full palette: who/what/when/where/why/how/how-much/should."
