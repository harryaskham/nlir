#!/usr/bin/env bash
# nlir-TARGET-golf · aur1 · #55 — "the measurement question" (How do I measure X?)
#
# The "how do I measure X?" turn — asking for METRICS/how to quantify something, not
# how to build or improve it. A "how do i measure X" seed steers `?` to the "How do I
# measure X?" quantification frame.
#
#   TARGET (30 chars):    "How do I measure code quality?"
#   NLIR   (31 src chars): 'how do i measure code quality'?
#   REAL OUTPUT (do/you float): "How do you measure code quality?"
#
#   CLOSENESS: exact frame; "do I"/"do you" floats. The 44th ? framing: "how do i
#   measure X" asks how to QUANTIFY/assess something — distinct from #01 "how do I X?"
#   (do a task) and #39 "how can I tell if X?" (a yes/no property): give me the metric.
#
# Run:  ./examples/target-aur1-55-measurement.sh
set -euo pipefail
cd "$(dirname "$0")/.."
NLIR="${NLIR:-./target/release/nlir}"
[ -x "$NLIR" ] || { echo "build first: cargo build --release (or set NLIR=...)"; exit 1; }
if [ -z "${LITELLM_MASTER_KEY:-}" ] && [ -n "${CACOPHONY_LITELLM_MASTER_KEY_FILE:-}" ]; then
  export LITELLM_MASTER_KEY="$(cat "$CACOPHONY_LITELLM_MASTER_KEY_FILE")"
fi
say() { printf '\n\033[1m%s\033[0m\n' "$1"; }

say "TARGET (30 chars):  How do I measure code quality?"
say "NLIR (31 src chars):  'how do i measure code quality'?"
echo -n "  => "; "$NLIR" -e "'how do i measure code quality'?" --quiet

say "44th ? framing: 'how do i measure X' → QUANTIFY/metrics (vs #01 do-a-task, #39 yes/no property)."
