#!/usr/bin/env bash
# nlir-TARGET-golf · aur1 · #107 — "the fit question" (Am I the right person for this?)
#
# The "am I the right person for this?" turn — the delegation/self-awareness check: is this
# mine to do, or should it go to someone better placed? It guards against both hero-hoarding
# and misassignment. A first-person "am i the right person for this" seed steers `?` to that
# fit frame.
#
#   TARGET (30 chars):    "Am I the right person for this?"
#   NLIR   (32 src chars): 'am i the right person for this'?
#   REAL OUTPUT:          "Am I the right person for this?"   (exact)
#
#   CLOSENESS: exact. The 96th ? framing. `?` keeps the "am I the right person?" fit/delegation
#   frame. Distinct from #54 ownership (whose JOB it is) and #102 prior-art: this asks whether
#   YOU specifically are the best-placed to do it — delegate or own.
#
# Run:  ./examples/target-aur1-107-fit.sh
set -euo pipefail
cd "$(dirname "$0")/.."
NLIR="${NLIR:-./target/release/nlir}"
[ -x "$NLIR" ] || { echo "build first: cargo build --release (or set NLIR=...)"; exit 1; }
if [ -z "${LITELLM_MASTER_KEY:-}" ] && [ -n "${CACOPHONY_LITELLM_MASTER_KEY_FILE:-}" ]; then
  export LITELLM_MASTER_KEY="$(cat "$CACOPHONY_LITELLM_MASTER_KEY_FILE")"
fi
say() { printf '\n\033[1m%s\033[0m\n' "$1"; }

say "TARGET (30 chars):  Am I the right person for this?"
say "NLIR (32 src chars):  'am i the right person for this'?"
echo -n "  => "; "$NLIR" -e "'am i the right person for this'?" --quiet

say "96th ? framing: 'am i the right person for this' → the fit / delegation check (vs #54 ownership, #102 prior-art)."
