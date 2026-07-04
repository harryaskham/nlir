#!/usr/bin/env bash
# nlir-golf · aur1 · #16 — "the diff" (the third face of ~(a&b))
#
# One expression, THREE meanings — chosen not by the operator but by the
# RELATIONSHIP between its operands. This is the finale of my ~(a&b) trilogy:
#
#   #01 DIALECTIC   ~(x & !x)          opposites   → the tension / contradiction
#   #15 MERGE       ~(a & b)           complements → the synthesis / unified spec
#   #16 DIFF        ~(before & after)  a state and its successor → the CHANGE
#
# Because the summariser is an LLM, ~(a&b) is polymorphic: give it a claim and its
# negation and it finds the friction; give it two requirements and it fuses them;
# give it a before-state and an after-state and it narrates what CHANGED.
#
#   DIFF   ~(before & after)
#     "we were going to build search on Elasticsearch"
#   & "we decided to use Postgres full-text search instead"
#   ~ => "The team switched from a planned Elasticsearch implementation to
#         Postgres full-text search."  — the decision delta, in one line.
#
# Run:  ./examples/golf-aur1-16-diff.sh
set -euo pipefail
cd "$(dirname "$0")/.."
NLIR="${NLIR:-./target/release/nlir}"
[ -x "$NLIR" ] || { echo "build first: cargo build --release (or set NLIR=...)"; exit 1; }
if [ -z "${LITELLM_MASTER_KEY:-}" ] && [ -n "${CACOPHONY_LITELLM_MASTER_KEY_FILE:-}" ]; then
  export LITELLM_MASTER_KEY="$(cat "$CACOPHONY_LITELLM_MASTER_KEY_FILE")"
fi
say() { printf '\n\033[1m%s\033[0m\n' "$1"; }

say "DIFF  ~(before & after)  — the third face of ~(a&b): a state + its successor → the change"
echo "  before: we were going to build the search on Elasticsearch"
echo "  after : we decided to use Postgres full-text search instead"
echo -n "  change => "
"$NLIR" -e "~('we were going to build the search on Elasticsearch'&'we decided to use Postgres full-text search instead')" --quiet

say "Same ~(a&b) as #01 (tension) and #15 (synthesis) — the operands' relationship picks the meaning."
