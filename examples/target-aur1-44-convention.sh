#!/usr/bin/env bash
# nlir-TARGET-golf · aur1 · #44 — "the convention question" (What's the standard way to…?)
#
# The "what's the standard way to X?" turn — asking for the idiomatic/community
# convention, not just any approach. A "whats the standard way to X" seed steers `?`
# to the "What is the standard way to …?" convention frame.
#
#   TARGET (49 chars):    "What's the standard way to structure a Rust project?"
#   NLIR   (49 src chars): 'whats the standard way to structure a rust project'?
#   REAL OUTPUT:          "What is the standard way to structure a Rust project?"  (≈ exact; whats→what is)
#
#   CLOSENESS: exact meaning; `?` normalises "whats" → "What is" and capitalises the
#   proper noun. The 33rd ? framing: "standard way to X" asks for the ESTABLISHED
#   CONVENTION — distinct from #21 "best way to X?" (optimal/idiomatic approach) and
#   #01 "how do I X?" (any working steps): what does everyone else do.
#
# Run:  ./examples/target-aur1-44-convention.sh
set -euo pipefail
cd "$(dirname "$0")/.."
NLIR="${NLIR:-./target/release/nlir}"
[ -x "$NLIR" ] || { echo "build first: cargo build --release (or set NLIR=...)"; exit 1; }
if [ -z "${LITELLM_MASTER_KEY:-}" ] && [ -n "${CACOPHONY_LITELLM_MASTER_KEY_FILE:-}" ]; then
  export LITELLM_MASTER_KEY="$(cat "$CACOPHONY_LITELLM_MASTER_KEY_FILE")"
fi
say() { printf '\n\033[1m%s\033[0m\n' "$1"; }

say "TARGET (49 chars):  What's the standard way to structure a Rust project?"
say "NLIR (49 src chars):  'whats the standard way to structure a rust project'?"
echo -n "  => "; "$NLIR" -e "'whats the standard way to structure a rust project'?" --quiet

say "33rd ? framing: 'standard way to X' → the ESTABLISHED CONVENTION (vs #21 best-way, #01 how-do-I)."
