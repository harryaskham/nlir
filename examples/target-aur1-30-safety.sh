#!/usr/bin/env bash
# nlir-TARGET-golf · aur1 · #30 — "the safety question" (Is it safe to…?)
#
# The "is it safe to X?" turn — asking about risk before acting, not whether it's
# allowed. A "safe to X" seed steers `?` to the "Is it safe to …?" risk frame.
#
#   TARGET (37 chars):    "Is it safe to run this migration on prod?"
#   NLIR   (36 src chars): 'safe to run this migration on prod'?
#   REAL OUTPUT:          "Is it safe to run this migration on prod?"   (exact)
#
#   CLOSENESS: exact. The 19th ? framing. `?` reads "safe to …" as a RISK question
#   and builds "Is it safe to …?" — distinct from #23's "Can I …?" (permission):
#   safety asks "will this break things", permission asks "am I allowed". Different
#   worry, different frame, from near-identical seeds.
#
# Run:  ./examples/target-aur1-30-safety.sh
set -euo pipefail
cd "$(dirname "$0")/.."
NLIR="${NLIR:-./target/release/nlir}"
[ -x "$NLIR" ] || { echo "build first: cargo build --release (or set NLIR=...)"; exit 1; }
if [ -z "${LITELLM_MASTER_KEY:-}" ] && [ -n "${CACOPHONY_LITELLM_MASTER_KEY_FILE:-}" ]; then
  export LITELLM_MASTER_KEY="$(cat "$CACOPHONY_LITELLM_MASTER_KEY_FILE")"
fi
say() { printf '\n\033[1m%s\033[0m\n' "$1"; }

say "TARGET (37 chars):  Is it safe to run this migration on prod?"
say "NLIR (36 src chars):  'safe to run this migration on prod'?"
echo -n "  => "; "$NLIR" -e "'safe to run this migration on prod'?" --quiet

say "19th ? framing: 'safe to X' → 'Is it safe to …?' RISK question (vs #23 'Can I…?' permission)."
