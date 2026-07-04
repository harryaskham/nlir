#!/usr/bin/env bash
# nlir-TARGET-golf · aur1 · #49 — "the project-health question" (Is X still maintained?)
#
# The "is X still maintained?" turn — asking whether a tool/library is still actively
# supported before you depend on it. An "is X still maintained" seed steers `?` to the
# "Is X still maintained?" project-health frame.
#
#   TARGET (30 chars):    "Is AngularJS still maintained?"
#   NLIR   (30 src chars): 'is angularjs still maintained'?
#   REAL OUTPUT:          "Is AngularJS still maintained?"   (exact)
#
#   CLOSENESS: exact (30 → 30, a wash). The 38th ? framing. `?` keeps the "still
#   maintained?" liveness frame and fixes the CamelCase. Distinct from #41 "Is X ready?"
#   (your thing's readiness) and #40 "Is X overkill?" (fit): this asks about the
#   ONGOING health of an external dependency — the can-I-still-rely-on-it turn.
#
# Run:  ./examples/target-aur1-49-projecthealth.sh
set -euo pipefail
cd "$(dirname "$0")/.."
NLIR="${NLIR:-./target/release/nlir}"
[ -x "$NLIR" ] || { echo "build first: cargo build --release (or set NLIR=...)"; exit 1; }
if [ -z "${LITELLM_MASTER_KEY:-}" ] && [ -n "${CACOPHONY_LITELLM_MASTER_KEY_FILE:-}" ]; then
  export LITELLM_MASTER_KEY="$(cat "$CACOPHONY_LITELLM_MASTER_KEY_FILE")"
fi
say() { printf '\n\033[1m%s\033[0m\n' "$1"; }

say "TARGET (30 chars):  Is AngularJS still maintained?"
say "NLIR (30 src chars):  'is angularjs still maintained'?"
echo -n "  => "; "$NLIR" -e "'is angularjs still maintained'?" --quiet

say "38th ? framing: 'is X still maintained' → dependency HEALTH (vs #41 readiness, #40 overkill)."
