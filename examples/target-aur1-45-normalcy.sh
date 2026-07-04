#!/usr/bin/env bash
# nlir-TARGET-golf · aur1 · #45 — "the normalcy question" (Is it normal for X to…?)
#
# The "is it normal for X?" turn — asking whether an observed behaviour is expected
# or a sign something's wrong. An "is it normal for X to Y" seed steers `?` to the
# "Is it normal for X to Y?" expectation frame.
#
#   TARGET (40 chars):    "Is it normal for builds to take 10 minutes?"
#   NLIR   (41 src chars): 'is it normal for builds to take 10 minutes'?
#   REAL OUTPUT:          "Is it normal for builds to take 10 minutes?"   (exact)
#
#   CLOSENESS: exact. The 34th ? framing. `?` keeps the "is it normal for …?"
#   expectation frame. Distinct from #40 "Is X overkill?" (proportionality) and #41
#   "Is X ready?" (readiness): this asks whether observed behaviour is EXPECTED —
#   the am-I-doing-something-wrong / is-this-a-red-flag turn.
#
# Run:  ./examples/target-aur1-45-normalcy.sh
set -euo pipefail
cd "$(dirname "$0")/.."
NLIR="${NLIR:-./target/release/nlir}"
[ -x "$NLIR" ] || { echo "build first: cargo build --release (or set NLIR=...)"; exit 1; }
if [ -z "${LITELLM_MASTER_KEY:-}" ] && [ -n "${CACOPHONY_LITELLM_MASTER_KEY_FILE:-}" ]; then
  export LITELLM_MASTER_KEY="$(cat "$CACOPHONY_LITELLM_MASTER_KEY_FILE")"
fi
say() { printf '\n\033[1m%s\033[0m\n' "$1"; }

say "TARGET (40 chars):  Is it normal for builds to take 10 minutes?"
say "NLIR (41 src chars):  'is it normal for builds to take 10 minutes'?"
echo -n "  => "; "$NLIR" -e "'is it normal for builds to take 10 minutes'?" --quiet

say "34th ? framing: 'is it normal for X' → an EXPECTATION check (vs #40 overkill, #41 readiness)."
