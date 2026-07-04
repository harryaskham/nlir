#!/usr/bin/env bash
# nlir-TARGET-golf · aur1 · #53 — "the good-idea question" (Is X a good idea?)
#
# The "is X a good idea?" turn — asking for a VALUE JUDGEMENT on a plan, softer and
# more open than a yes/no decision. An "is X-ing a good idea" seed steers `?` to the
# "Is X a good idea?" evaluation frame.
#
#   TARGET (35 chars):    "Is rewriting it in Rust a good idea?"
#   NLIR   (35 src chars): 'is rewriting it in rust a good idea'?
#   REAL OUTPUT:          "Is rewriting it in Rust a good idea?"   (exact)
#
#   CLOSENESS: exact (35 → 35, a wash). The 42nd ? framing. `?` keeps the "is … a good
#   idea?" evaluation frame and capitalises Rust. Distinct from #08 "Should I …?" (a
#   commit/decision) and #27 "Is X worth it?" (ROI): this invites an OPEN judgement of
#   merit — sanity-check my plan.
#
# Run:  ./examples/target-aur1-53-goodidea.sh
set -euo pipefail
cd "$(dirname "$0")/.."
NLIR="${NLIR:-./target/release/nlir}"
[ -x "$NLIR" ] || { echo "build first: cargo build --release (or set NLIR=...)"; exit 1; }
if [ -z "${LITELLM_MASTER_KEY:-}" ] && [ -n "${CACOPHONY_LITELLM_MASTER_KEY_FILE:-}" ]; then
  export LITELLM_MASTER_KEY="$(cat "$CACOPHONY_LITELLM_MASTER_KEY_FILE")"
fi
say() { printf '\n\033[1m%s\033[0m\n' "$1"; }

say "TARGET (35 chars):  Is rewriting it in Rust a good idea?"
say "NLIR (35 src chars):  'is rewriting it in rust a good idea'?"
echo -n "  => "; "$NLIR" -e "'is rewriting it in rust a good idea'?" --quiet

say "42nd ? framing: 'is X a good idea' → an OPEN value judgement (vs #08 decision, #27 worth-it/ROI)."
