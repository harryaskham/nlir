#!/usr/bin/env bash
# nlir-TARGET-golf · aur1 · #77 — "the bug-or-feature question" (Is this a bug or expected behavior?)
#
# The "is this a bug or expected behavior?" turn — asking whether something surprising is a
# defect or intended, a classification question every developer asks. A "is this a bug or
# expected behavior" seed steers `?` to that exact frame.
#
#   TARGET (33 chars):    "Is this a bug or expected behavior?"
#   NLIR   (36 src chars): 'is this a bug or expected behavior'?
#   REAL OUTPUT:          "Is this a bug or expected behavior?"   (exact)
#
#   CLOSENESS: exact. The 66th ? framing. `?` keeps the "bug or expected?" classification
#   frame. Distinct from #25 whats-wrong (assumes a fault) and #45 is-it-normal (about a
#   situation): this asks whether an OBSERVED behavior is a defect or by design.
#
# Run:  ./examples/target-aur1-77-bugorfeature.sh
set -euo pipefail
cd "$(dirname "$0")/.."
NLIR="${NLIR:-./target/release/nlir}"
[ -x "$NLIR" ] || { echo "build first: cargo build --release (or set NLIR=...)"; exit 1; }
if [ -z "${LITELLM_MASTER_KEY:-}" ] && [ -n "${CACOPHONY_LITELLM_MASTER_KEY_FILE:-}" ]; then
  export LITELLM_MASTER_KEY="$(cat "$CACOPHONY_LITELLM_MASTER_KEY_FILE")"
fi
say() { printf '\n\033[1m%s\033[0m\n' "$1"; }

say "TARGET (33 chars):  Is this a bug or expected behavior?"
say "NLIR (36 src chars):  'is this a bug or expected behavior'?"
echo -n "  => "; "$NLIR" -e "'is this a bug or expected behavior'?" --quiet

say "66th ? framing: 'is this a bug or expected behavior' → defect-or-by-design (vs #25 whats-wrong, #45 is-it-normal)."
