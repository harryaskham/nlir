#!/usr/bin/env bash
# nlir-TARGET-golf · aur1 · #113 — "the Occam question" (What's the simplest explanation?)
#
# The "what's the simplest explanation?" turn — Occam's razor: among competing accounts of what's
# going on, which needs the fewest assumptions? It resists the temptation to over-theorise a
# problem. A "whats the simplest explanation" seed steers `?` to that parsimony frame.
#
#   TARGET (30 chars):    "What's the simplest explanation?"
#   NLIR   (33 src chars): 'whats the simplest explanation'?
#   REAL OUTPUT (contraction floats): "What is the simplest explanation?"
#
#   CLOSENESS: exact frame; "what's"/"what is" floats. The 102nd ? framing. Distinct from #43
#   diagnosis (what's causing it) and #79 minimalism: this asks for the LEAST-assumption account
#   of what's happening — Occam's razor.
#
# Run:  ./examples/target-aur1-113-occam.sh
set -euo pipefail
cd "$(dirname "$0")/.."
NLIR="${NLIR:-./target/release/nlir}"
[ -x "$NLIR" ] || { echo "build first: cargo build --release (or set NLIR=...)"; exit 1; }
if [ -z "${LITELLM_MASTER_KEY:-}" ] && [ -n "${CACOPHONY_LITELLM_MASTER_KEY_FILE:-}" ]; then
  export LITELLM_MASTER_KEY="$(cat "$CACOPHONY_LITELLM_MASTER_KEY_FILE")"
fi
say() { printf '\n\033[1m%s\033[0m\n' "$1"; }

say "TARGET (30 chars):  What's the simplest explanation?"
say "NLIR (33 src chars):  'whats the simplest explanation'?"
echo -n "  => "; "$NLIR" -e "'whats the simplest explanation'?" --quiet

say "102nd ? framing: 'whats the simplest explanation' → Occam's razor / least-assumption account (vs #43 diagnosis, #79 minimalism)."
