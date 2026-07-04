#!/usr/bin/env bash
# nlir-TARGET-golf · aur1 · #12 — "the where-question"
#
# Seventh `?` mood (how / what / why / should / how-much / when / WHERE): the
# location question. Seed the thing you're looking for; `?` builds "Where …?".
#
#   TARGET (34 chars):    "Where are Rust crates published?"
#   NLIR   (32 src chars): 'where are rust crates published'?
#   REAL OUTPUT:          "Where are Rust crates published?"   (exact)
#
#   CLOSENESS: exact. The "where are …" seed shape steers `?` to the locative
#   frame. That's SEVEN interrogative moods now inferred from one operator purely
#   by the seed's phrasing — a near-complete question generator: the terse topic
#   goes in, the correct question comes out, and which of who/what/when/where/why/
#   how/should is chosen by how you phrase the seed.
#
# Run:  ./examples/target-aur1-12-where.sh
set -euo pipefail
cd "$(dirname "$0")/.."
NLIR="${NLIR:-./target/release/nlir}"
[ -x "$NLIR" ] || { echo "build first: cargo build --release (or set NLIR=...)"; exit 1; }
if [ -z "${LITELLM_MASTER_KEY:-}" ] && [ -n "${CACOPHONY_LITELLM_MASTER_KEY_FILE:-}" ]; then
  export LITELLM_MASTER_KEY="$(cat "$CACOPHONY_LITELLM_MASTER_KEY_FILE")"
fi
say() { printf '\n\033[1m%s\033[0m\n' "$1"; }

say "TARGET (34 chars):  Where are Rust crates published?"
say "NLIR (32 src chars):  'where are rust crates published'?"
echo -n "  => "; "$NLIR" -e "'where are rust crates published'?" --quiet

say "Seventh ? mood (where). One operator, the near-complete interrogative palette from seed shape."
