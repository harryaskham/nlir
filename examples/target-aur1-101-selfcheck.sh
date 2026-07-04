#!/usr/bin/env bash
# nlir-TARGET-golf · aur1 · #101 — "the self-check question" (Am I overthinking this?) · 90th ? shape
#
# The "am I overthinking this?" turn — the proportionality check: is the deliberation out of
# scale with the stakes? It catches analysis-paralysis before it eats the afternoon. A
# first-person "am i overthinking this" seed steers `?` to that self-check frame.
#
#   TARGET (22 chars):    "Am I overthinking this?"
#   NLIR   (24 src chars): 'am i overthinking this'?
#   REAL OUTPUT (pronoun floats): "Are you overthinking this?"
#
#   CLOSENESS: exact frame; "am I"/"are you" floats. The 90th ? framing. `?` keeps the "am I
#   overthinking?" self-check. Distinct from #83 falsification and #86 assumptions: this checks
#   whether the EFFORT is proportional to the decision — a caution against paralysis.
#
# Run:  ./examples/target-aur1-101-selfcheck.sh
set -euo pipefail
cd "$(dirname "$0")/.."
NLIR="${NLIR:-./target/release/nlir}"
[ -x "$NLIR" ] || { echo "build first: cargo build --release (or set NLIR=...)"; exit 1; }
if [ -z "${LITELLM_MASTER_KEY:-}" ] && [ -n "${CACOPHONY_LITELLM_MASTER_KEY_FILE:-}" ]; then
  export LITELLM_MASTER_KEY="$(cat "$CACOPHONY_LITELLM_MASTER_KEY_FILE")"
fi
say() { printf '\n\033[1m%s\033[0m\n' "$1"; }

say "TARGET (22 chars):  Am I overthinking this?"
say "NLIR (24 src chars):  'am i overthinking this'?"
echo -n "  => "; "$NLIR" -e "'am i overthinking this'?" --quiet

say "90th ? framing: 'am i overthinking this' → the proportionality / analysis-paralysis self-check (vs #83 falsification, #86 assumptions)."
