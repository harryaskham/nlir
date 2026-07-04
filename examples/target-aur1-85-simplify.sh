#!/usr/bin/env bash
# nlir-TARGET-golf · aur1 · #85 — "the simplification question" (Is there a simpler way to do this?)
#
# The "is there a simpler way to do this?" turn — asking whether the current approach can be
# replaced by something less complex, a refactor/simplify prompt. A "is there a simpler way to
# do this" seed steers `?` to that simplification frame.
#
#   TARGET (33 chars):    "Is there a simpler way to do this?"
#   NLIR   (36 src chars): 'is there a simpler way to do this'?
#   REAL OUTPUT:          "Is there a simpler way to do this?"   (exact)
#
#   CLOSENESS: exact. The 74th ? framing. `?` keeps the "simpler way?" simplification frame.
#   Distinct from #79 simplest-thing (the minimal build from scratch) and #21 best-way (the
#   ideal method): this asks whether the EXISTING approach can be made less complex.
#
# Run:  ./examples/target-aur1-85-simplify.sh
set -euo pipefail
cd "$(dirname "$0")/.."
NLIR="${NLIR:-./target/release/nlir}"
[ -x "$NLIR" ] || { echo "build first: cargo build --release (or set NLIR=...)"; exit 1; }
if [ -z "${LITELLM_MASTER_KEY:-}" ] && [ -n "${CACOPHONY_LITELLM_MASTER_KEY_FILE:-}" ]; then
  export LITELLM_MASTER_KEY="$(cat "$CACOPHONY_LITELLM_MASTER_KEY_FILE")"
fi
say() { printf '\n\033[1m%s\033[0m\n' "$1"; }

say "TARGET (33 chars):  Is there a simpler way to do this?"
say "NLIR (36 src chars):  'is there a simpler way to do this'?"
echo -n "  => "; "$NLIR" -e "'is there a simpler way to do this'?" --quiet

say "74th ? framing: 'is there a simpler way' → simplify the EXISTING approach (vs #79 simplest-thing, #21 best-way)."
