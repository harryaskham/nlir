#!/usr/bin/env bash
# nlir-TARGET-golf · aur1 · #89 — "the leverage question" (Is this the highest-leverage thing I can do?)
#
# The "is this the highest-leverage thing I can do?" turn — checking whether your effort is
# aimed at the maximum-impact work, an impact-prioritisation ask. A first-person "is this the
# highest leverage thing i can do" seed steers `?` to that leverage frame.
#
#   TARGET (~40 chars):   "Is this the highest-leverage thing I can do?"
#   NLIR   (44 src chars): 'is this the highest leverage thing i can do'?
#   REAL OUTPUT:          "Is this the highest-leverage thing I can do?"   (exact)
#
#   CLOSENESS: exact frame (adds the hyphen in "highest-leverage"). The 78th ? framing.
#   Distinct from #87 focus (where to put attention) and #79 simplest-thing (minimal build):
#   this asks whether this is the MAX-IMPACT use of your effort.
#
# Run:  ./examples/target-aur1-89-leverage.sh
set -euo pipefail
cd "$(dirname "$0")/.."
NLIR="${NLIR:-./target/release/nlir}"
[ -x "$NLIR" ] || { echo "build first: cargo build --release (or set NLIR=...)"; exit 1; }
if [ -z "${LITELLM_MASTER_KEY:-}" ] && [ -n "${CACOPHONY_LITELLM_MASTER_KEY_FILE:-}" ]; then
  export LITELLM_MASTER_KEY="$(cat "$CACOPHONY_LITELLM_MASTER_KEY_FILE")"
fi
say() { printf '\n\033[1m%s\033[0m\n' "$1"; }

say "TARGET (~40 chars):  Is this the highest-leverage thing I can do?"
say "NLIR (44 src chars):  'is this the highest leverage thing i can do'?"
echo -n "  => "; "$NLIR" -e "'is this the highest leverage thing i can do'?" --quiet

say "78th ? framing: 'is this the highest-leverage thing' → the MAX-IMPACT use of effort (vs #87 focus, #79 simplest-thing)."
