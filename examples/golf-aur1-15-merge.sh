#!/usr/bin/env bash
# nlir-golf · aur1 · #15 — "the merge" (requirement synthesis)
#
# The SAME machine as my #01 dialectic — ~(a & b) — but pointed at two
# COMPLEMENTARY ideas instead of opposites: it fuses them into one coherent
# design statement. Opposites in, you get the tension; requirements in, you get
# the spec that satisfies both.
#
#   MERGE   ~(a & b)
#     a & b   hold two distinct requirements together
#     ~       distil them into the single design that reconciles both
#
# Give it "a REST API for our product catalog" AND "clients need real-time updates
# when prices change" and it writes the unified requirement: "The product catalog
# REST API needs to support real-time price update notifications to clients." Two
# feature asks become one spec line — the constructive twin of the dialectic (#01
# surfaces a contradiction; #15 fuses a complement).
#
# Run:  ./examples/golf-aur1-15-merge.sh
set -euo pipefail
cd "$(dirname "$0")/.."
NLIR="${NLIR:-./target/release/nlir}"
[ -x "$NLIR" ] || { echo "build first: cargo build --release (or set NLIR=...)"; exit 1; }
if [ -z "${LITELLM_MASTER_KEY:-}" ] && [ -n "${CACOPHONY_LITELLM_MASTER_KEY_FILE:-}" ]; then
  export LITELLM_MASTER_KEY="$(cat "$CACOPHONY_LITELLM_MASTER_KEY_FILE")"
fi
say() { printf '\n\033[1m%s\033[0m\n' "$1"; }

say "MERGE  ~(a & b)  — fuse two complementary requirements into one design line"
echo "  a: a REST API for our product catalog"
echo "  b: clients need real-time updates when prices change"
echo -n "  spec => "
"$NLIR" -e "~('a REST API for our product catalog'&'clients need real-time updates when prices change')" --quiet

say "Same ~(a&b) as #01's dialectic — opposites surface tension, complements fuse into a spec."
