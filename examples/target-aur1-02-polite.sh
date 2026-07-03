#!/usr/bin/env bash
# nlir-TARGET-golf · aur1 · #02 — "shorthand → polite ask"
#
# The single most common pi turn: a terse request you want said politely. `@`
# (formalise) is a decompressor from shorthand to a courteous full sentence — the
# terse-in / polished-out pattern we'll live in.
#
#   TARGET (99 chars):
#     "Could you please review my pull request when you have a moment?
#      It updates the authentication flow."
#
#   NLIR (46 src chars):
#     @'pls review my PR when free, updates auth flow'
#
#   REAL OUTPUT:
#     "Please review my pull request at your earliest convenience.
#      It includes updates to the authentication flow."
#
#   CLOSENESS: semantically identical, same two-clause shape, courteous register.
#   Ratio ~2.2x (46 -> ~106 chars out). `@` is the sweet spot for one/two-line
#   targets: it changes register + fills the politeness scaffolding while keeping
#   every concrete detail you seeded (PR, auth flow, "when free").
#
# Run:  ./examples/target-aur1-02-polite.sh
set -euo pipefail
cd "$(dirname "$0")/.."
NLIR="${NLIR:-./target/release/nlir}"
[ -x "$NLIR" ] || { echo "build first: cargo build --release (or set NLIR=...)"; exit 1; }
if [ -z "${LITELLM_MASTER_KEY:-}" ] && [ -n "${CACOPHONY_LITELLM_MASTER_KEY_FILE:-}" ]; then
  export LITELLM_MASTER_KEY="$(cat "$CACOPHONY_LITELLM_MASTER_KEY_FILE")"
fi
say() { printf '\n\033[1m%s\033[0m\n' "$1"; }

say "TARGET (99 chars):"
echo "  Could you please review my pull request when you have a moment? It updates the authentication flow."

say "NLIR (46 src chars):  @'pls review my PR when free, updates auth flow'"
echo -n "  => "
"$NLIR" -e "@'pls review my PR when free, updates auth flow'" --quiet

say "Shorthand in, polite out — ~2.2x, every seeded detail preserved. @ is the one-liner sweet spot."
