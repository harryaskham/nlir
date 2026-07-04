#!/usr/bin/env bash
# nlir-TARGET-golf · aur1 · #64 — "the buy-in question" (How do I get buy-in for X?)
#
# The "how do I get buy-in for X?" turn — asking how to win organisational support for a
# proposal, a stakeholder/political ask rather than a technical one. A "how do i get buy-in
# for X" seed steers `?` to the "How do I get buy-in for X?" support frame.
#
#   TARGET (33 chars):    "How do I get buy-in for a rewrite?"
#   NLIR   (34 src chars): 'how do i get buy-in for a rewrite'?
#   REAL OUTPUT:          "How do I get buy-in for a rewrite?"   (exact)
#
#   CLOSENESS: exact. The 53rd ? framing. `?` keeps the "get buy-in for …?" support frame.
#   Distinct from #48 persuasion (convince one person) and #08 should-I (advisability):
#   this asks how to build ORGANISATIONAL support for a proposal you've already decided on.
#
# Run:  ./examples/target-aur1-64-buyin.sh
set -euo pipefail
cd "$(dirname "$0")/.."
NLIR="${NLIR:-./target/release/nlir}"
[ -x "$NLIR" ] || { echo "build first: cargo build --release (or set NLIR=...)"; exit 1; }
if [ -z "${LITELLM_MASTER_KEY:-}" ] && [ -n "${CACOPHONY_LITELLM_MASTER_KEY_FILE:-}" ]; then
  export LITELLM_MASTER_KEY="$(cat "$CACOPHONY_LITELLM_MASTER_KEY_FILE")"
fi
say() { printf '\n\033[1m%s\033[0m\n' "$1"; }

say "TARGET (33 chars):  How do I get buy-in for a rewrite?"
say "NLIR (34 src chars):  'how do i get buy-in for a rewrite'?"
echo -n "  => "; "$NLIR" -e "'how do i get buy-in for a rewrite'?" --quiet

say "53rd ? framing: 'how do i get buy-in for X' → ORGANISATIONAL support (vs #48 persuade-one-person, #08 should-I)."
