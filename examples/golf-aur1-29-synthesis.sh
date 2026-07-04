#!/usr/bin/env bash
# nlir-golf · aur1 · #29 — "the synthesis law" (~ does NOT distribute over &)
#
# Last tick @ distributed over & (@a&@b ≈ @(a&b)). Summary does the OPPOSITE, and
# that's the point: ~(a&b) ≠ ~a&~b. Grouping under ~ lets the summariser see both
# operands AT ONCE and find the RELATIONSHIP between them; distributing ~ over
# each operand loses that — you just get two summaries stapled together.
#
#   NON-DISTRIBUTIVITY (synthesis)   ~(a & b)   ≠   ~a & ~b
#     a = "cache cut p99 latency 800ms→120ms"   b = "cache added 2GB/node overhead"
#     ~(a&b) → "…cut p99 latency 800ms→120ms AT THE COST OF 2GB overhead per node."
#              SYNTHESIS — finds the tradeoff link ("at the cost of")
#     ~a&~b  → "…reduced latency… AND added 2GB overhead per node."
#              ENUMERATION — two summaries joined with "and", no link drawn
#
# So whether an operator distributes over & tells you its CHARACTER: @ is POINTWISE
# (distributes, #27), ~ is SYNTHESISING (does not, this one). This is precisely why
# my merge (#15) and diff (#16) use ~(a&b) — the cross-operand synthesis IS the
# feature. Reach for the grouped ~ when you want the relationship, not a list.
#
# Run:  ./examples/golf-aur1-29-synthesis.sh
set -euo pipefail
cd "$(dirname "$0")/.."
NLIR="${NLIR:-./target/release/nlir}"
[ -x "$NLIR" ] || { echo "build first: cargo build --release (or set NLIR=...)"; exit 1; }
if [ -z "${LITELLM_MASTER_KEY:-}" ] && [ -n "${CACOPHONY_LITELLM_MASTER_KEY_FILE:-}" ]; then
  export LITELLM_MASTER_KEY="$(cat "$CACOPHONY_LITELLM_MASTER_KEY_FILE")"
fi
say() { printf '\n\033[1m%s\033[0m\n' "$1"; }
A='the cache reduced p99 latency from 800ms to 120ms'; B='the cache added 2GB memory overhead per node'

say "SYNTHESIS LAW  ~(a&b) vs ~a&~b  — summary does NOT distribute over & (grouping = synthesis)"
echo -n "  ~(a&b) (synthesis, finds the link) => "; "$NLIR" -e "~('$A'&'$B')" --quiet
echo -n "  ~a&~b  (enumeration, just joins)   => "; "$NLIR" -e "~'$A'&~'$B'" --quiet

say "@ distributes (pointwise, #27); ~ does NOT (synthesises across operands). That's why merge/diff use ~(a&b)."
