#!/usr/bin/env bash
# nlir-TARGET-golf · aur1 · #62 — "the sustaining question" (How do I stay X?)
#
# The "how do I stay X?" turn — asking how to MAINTAIN a state over time (motivation,
# focus, sharp), not how to reach it. A "how do i stay X" seed steers `?` to the "How do
# I stay X?" endurance frame.
#
#   TARGET (~41 chars):   "How do I stay motivated on a long project?"
#   NLIR   (41 src chars): 'how do i stay motivated on a long project'?
#   REAL OUTPUT (do/you float): "How do you stay motivated on a long project?"
#
#   CLOSENESS: exact frame; "do I"/"do you" floats. The 51st ? framing: "how do i stay X"
#   asks to SUSTAIN a state — distinct from #01 "how do I X?" (reach/do it once) and #49
#   project-health (is it maintained): keeping yourself in a state over the long haul.
#
# Run:  ./examples/target-aur1-62-sustaining.sh
set -euo pipefail
cd "$(dirname "$0")/.."
NLIR="${NLIR:-./target/release/nlir}"
[ -x "$NLIR" ] || { echo "build first: cargo build --release (or set NLIR=...)"; exit 1; }
if [ -z "${LITELLM_MASTER_KEY:-}" ] && [ -n "${CACOPHONY_LITELLM_MASTER_KEY_FILE:-}" ]; then
  export LITELLM_MASTER_KEY="$(cat "$CACOPHONY_LITELLM_MASTER_KEY_FILE")"
fi
say() { printf '\n\033[1m%s\033[0m\n' "$1"; }

say "TARGET (~41 chars):  How do I stay motivated on a long project?"
say "NLIR (41 src chars):  'how do i stay motivated on a long project'?"
echo -n "  => "; "$NLIR" -e "'how do i stay motivated on a long project'?" --quiet

say "51st ? framing: 'how do i stay X' → SUSTAIN a state over time (vs #01 reach-it-once, #49 project-health)."
