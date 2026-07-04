#!/usr/bin/env bash
# nlir-TARGET-golf · aur1 · #40 — "the overkill question" (Is X overkill for Y?)
#
# The "is X overkill for Y?" turn — asking whether a tool is disproportionately
# heavy for the scale at hand. An "is X overkill for Y" seed steers `?` to the
# "Is X overkill for Y?" proportionality frame.
#
#   TARGET (41 chars):    "Is Kubernetes overkill for a side project?"
#   NLIR   (42 src chars): 'is kubernetes overkill for a side project'?
#   REAL OUTPUT:          "Is Kubernetes overkill for a side project?"   (exact)
#
#   CLOSENESS: exact. The 29th ? framing. `?` keeps the "overkill for …"
#   proportionality frame and capitalises the proper noun. Distinct from #33 "Do I
#   need X?" (necessity) and #36 "What are the downsides of X?" (drawbacks): this
#   asks about FIT-TO-SCALE — is this too much for my situation.
#
# Run:  ./examples/target-aur1-40-overkill.sh
set -euo pipefail
cd "$(dirname "$0")/.."
NLIR="${NLIR:-./target/release/nlir}"
[ -x "$NLIR" ] || { echo "build first: cargo build --release (or set NLIR=...)"; exit 1; }
if [ -z "${LITELLM_MASTER_KEY:-}" ] && [ -n "${CACOPHONY_LITELLM_MASTER_KEY_FILE:-}" ]; then
  export LITELLM_MASTER_KEY="$(cat "$CACOPHONY_LITELLM_MASTER_KEY_FILE")"
fi
say() { printf '\n\033[1m%s\033[0m\n' "$1"; }

say "TARGET (41 chars):  Is Kubernetes overkill for a side project?"
say "NLIR (42 src chars):  'is kubernetes overkill for a side project'?"
echo -n "  => "; "$NLIR" -e "'is kubernetes overkill for a side project'?" --quiet

say "29th ? framing: 'is X overkill for Y' → a FIT-TO-SCALE question (vs #33 necessity, #36 downsides)."
