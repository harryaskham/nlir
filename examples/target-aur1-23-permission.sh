#!/usr/bin/env bash
# nlir-TARGET-golf · aur1 · #23 — "the permission question" (Can I…?)
#
# The "can I do X?" turn — asking whether an action is allowed/safe. A
# first-person "can i …" seed steers `?` to the "Can I …?" permission frame,
# distinct from #22's second-person "Do you …?".
#
#   TARGET (~25 chars):  a permission question, e.g.
#     "Can I force push to main?"
#   NLIR   (24 src chars): 'can i force push to main'?
#   REAL OUTPUT (pronoun floats I/you run-to-run):
#     "Can I force push to main?"   /   "Can you force push to main?"
#
#   CLOSENESS: high — exact except the pronoun sometimes flips to "you" (the
#   operator occasionally reads the question as addressed to the assistant). The
#   14th ? framing: a "can i …" seed still lands the "Can …?" permission/modal
#   frame, distinct from #22 "Do you …?" and #18 "Did …?". ? reads person, tense,
#   AND modal to pick the frame.
#
# Run:  ./examples/target-aur1-23-permission.sh
set -euo pipefail
cd "$(dirname "$0")/.."
NLIR="${NLIR:-./target/release/nlir}"
[ -x "$NLIR" ] || { echo "build first: cargo build --release (or set NLIR=...)"; exit 1; }
if [ -z "${LITELLM_MASTER_KEY:-}" ] && [ -n "${CACOPHONY_LITELLM_MASTER_KEY_FILE:-}" ]; then
  export LITELLM_MASTER_KEY="$(cat "$CACOPHONY_LITELLM_MASTER_KEY_FILE")"
fi
say() { printf '\n\033[1m%s\033[0m\n' "$1"; }

say "TARGET (25 chars):  Can I force push to main?"
say "NLIR (24 src chars):  'can i force push to main'?"
echo -n "  => "; "$NLIR" -e "'can i force push to main'?" --quiet

say "14th ? framing: 'can i …' → 'Can I …?' permission. ? reads person/tense/modal to choose."
