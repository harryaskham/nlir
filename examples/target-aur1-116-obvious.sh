#!/usr/bin/env bash
# nlir-TARGET-golf · aur1 · #116 — "the check-the-obvious question" (Have we tried the obvious thing?)
#
# The "have we tried the obvious thing?" turn — the sanity check against over-engineering: before
# any clever fix, has anyone actually tried the simple, obvious first move? It rescues teams from
# skipping the trivial solution. A "have we tried the obvious thing" seed steers `?` to that
# check-the-basics frame.
#
#   TARGET (30 chars):    "Have we tried the obvious thing?"
#   NLIR   (32 src chars): 'have we tried the obvious thing'?
#   REAL OUTPUT:          "Have we tried the obvious thing?"   (exact)
#
#   CLOSENESS: exact. The 105th ? framing. `?` keeps the "have we tried the obvious?" frame.
#   Distinct from #79 minimalism (simplest build) and #113 Occam (simplest explanation): this
#   asks whether the trivial FIRST move has actually been attempted yet.
#
# Run:  ./examples/target-aur1-116-obvious.sh
set -euo pipefail
cd "$(dirname "$0")/.."
NLIR="${NLIR:-./target/release/nlir}"
[ -x "$NLIR" ] || { echo "build first: cargo build --release (or set NLIR=...)"; exit 1; }
if [ -z "${LITELLM_MASTER_KEY:-}" ] && [ -n "${CACOPHONY_LITELLM_MASTER_KEY_FILE:-}" ]; then
  export LITELLM_MASTER_KEY="$(cat "$CACOPHONY_LITELLM_MASTER_KEY_FILE")"
fi
say() { printf '\n\033[1m%s\033[0m\n' "$1"; }

say "TARGET (30 chars):  Have we tried the obvious thing?"
say "NLIR (32 src chars):  'have we tried the obvious thing'?"
echo -n "  => "; "$NLIR" -e "'have we tried the obvious thing'?" --quiet

say "105th ? framing: 'have we tried the obvious thing' → the check-the-basics / anti-over-engineering sanity check (vs #79 minimalism, #113 Occam)."
