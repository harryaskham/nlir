#!/usr/bin/env bash
# nlir-TARGET-golf · aur1 · #33 — "the necessity question" (Do I need…?)
#
# The "do I need X?" turn — asking whether something is REQUIRED for your setup,
# not whether to choose it or whether you're allowed. A "do i need X for Y" seed
# steers `?` to the "Do I need X for Y?" necessity frame.
#
#   TARGET (41 chars):    "Do I need a load balancer for two servers?"
#   NLIR   (43 src chars): 'do i need a load balancer for two servers'?
#   REAL OUTPUT:          "Do I need a load balancer for two servers?"   (exact)
#
#   CLOSENESS: exact. The 22nd ? framing. `?` keeps the "do I need … for …"
#   necessity frame. Distinct from #08 "Should I …?" (a preference/decision) and
#   #23 "Can I …?" (permission): "do I need" asks about REQUIREMENT — is this
#   actually warranted for my scale.
#
# Run:  ./examples/target-aur1-33-necessity.sh
set -euo pipefail
cd "$(dirname "$0")/.."
NLIR="${NLIR:-./target/release/nlir}"
[ -x "$NLIR" ] || { echo "build first: cargo build --release (or set NLIR=...)"; exit 1; }
if [ -z "${LITELLM_MASTER_KEY:-}" ] && [ -n "${CACOPHONY_LITELLM_MASTER_KEY_FILE:-}" ]; then
  export LITELLM_MASTER_KEY="$(cat "$CACOPHONY_LITELLM_MASTER_KEY_FILE")"
fi
say() { printf '\n\033[1m%s\033[0m\n' "$1"; }

say "TARGET (41 chars):  Do I need a load balancer for two servers?"
say "NLIR (43 src chars):  'do i need a load balancer for two servers'?"
echo -n "  => "; "$NLIR" -e "'do i need a load balancer for two servers'?" --quiet

say "22nd ? framing: 'do i need X for Y' → REQUIREMENT question (vs #08 preference, #23 permission)."
