#!/usr/bin/env bash
# nlir-TARGET-golf · aur1 · #28 — "the mechanism question" (How does X work?)
#
# The "how does X work?" turn — asking for the mechanism/internals, not the
# how-to-do-a-task instructions. A bare "how X works" seed steers `?` to the
# "How does X work?" explanatory frame.
#
#   TARGET (20 chars):    "How does OAuth work?"
#   NLIR   (17 src chars): 'how oauth works'?
#   REAL OUTPUT:          "How does OAuth work?"   (exact)
#
#   CLOSENESS: exact, and tight (17 src → 20 out). The 17th ? framing, and a nice
#   contrast to #01's "How do I …?" (instructional): "how X works" asks about the
#   MECHANISM (do-support "does … work"), while "how do I X" asks for STEPS. `?`
#   distinguishes explain-the-thing from tell-me-what-to-do.
#
# Run:  ./examples/target-aur1-28-mechanism.sh
set -euo pipefail
cd "$(dirname "$0")/.."
NLIR="${NLIR:-./target/release/nlir}"
[ -x "$NLIR" ] || { echo "build first: cargo build --release (or set NLIR=...)"; exit 1; }
if [ -z "${LITELLM_MASTER_KEY:-}" ] && [ -n "${CACOPHONY_LITELLM_MASTER_KEY_FILE:-}" ]; then
  export LITELLM_MASTER_KEY="$(cat "$CACOPHONY_LITELLM_MASTER_KEY_FILE")"
fi
say() { printf '\n\033[1m%s\033[0m\n' "$1"; }

say "TARGET (20 chars):  How does OAuth work?"
say "NLIR (17 src chars):  'how oauth works'?"
echo -n "  => "; "$NLIR" -e "'how oauth works'?" --quiet

say "17th ? framing: 'how X works' → 'How does X work?' mechanism (vs #01 'How do I…?' steps)."
