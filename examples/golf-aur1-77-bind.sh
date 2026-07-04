#!/usr/bin/env bash
# nlir-golf · aur1 · #77 — "bind before you build" (>[a,b] expands only the LAST; >(a&b) weaves BOTH)
#
# A sharp, practical lesson about how `>` meets more than one point — and it explains why my
# #71 weave used a JOIN, not a list. If you hand `>` a LIST of two points, it elaborates only
# the LAST one and silently drops the rest. If you JOIN them with `&` first, `>` sees a single
# bound operand and weaves them together:
#
#     >[a, b]   → expands only b          (a is dropped)
#     >(a & b)  → weaves a AND b           (one integrated argument)
#
#   a "we need better test coverage"   b "we need faster CI"
#     >[a,b]  → "We need faster CI: our continuous integration pipeline takes too long…"
#               (all about CI — the test-coverage point vanished)
#     >(a&b)  → "we need better test coverage, since the current suite leaves too many paths
#               unverified…; and we also need faster CI…"        (both, knitted together)
#
# The `&` BINDS a and b into one operand, so a unary op like `>` acts on the whole pair; a
# list `[a, b]` leaves them as separate operands and `>` latches onto the last. So the rule
# for building on multiple points: BIND them first (`&`), don't list them. (The join's output
# carries a cosmetic leading `(` — the paren-echo, #71 — a fix is prototyped.)
#
# Run:  ./examples/golf-aur1-77-bind.sh
set -euo pipefail
cd "$(dirname "$0")/.."
NLIR="${NLIR:-./target/release/nlir}"
[ -x "$NLIR" ] || { echo "build first: cargo build --release (or set NLIR=...)"; exit 1; }
if [ -z "${LITELLM_MASTER_KEY:-}" ] && [ -n "${CACOPHONY_LITELLM_MASTER_KEY_FILE:-}" ]; then
  export LITELLM_MASTER_KEY="$(cat "$CACOPHONY_LITELLM_MASTER_KEY_FILE")"
fi
say() { printf '\n\033[1m%s\033[0m\n' "$1"; }
A='we need better test coverage'; B='we need faster CI'

say "BIND BEFORE YOU BUILD  — >[a,b] expands only the LAST point; >(a&b) BINDS both and weaves them"
echo   "  a: $A"
echo   "  b: $B"
echo -n "  >[a,b] (list — only b) => "; "$NLIR" -e ">['$A','$B']"    --quiet | fold -s -w 80 | sed '2,$s/^/             /'
echo -n "  >(a&b) (join — both)   => "; "$NLIR" -e ">('$A' & '$B')" --quiet | fold -s -w 80 | sed '2,$s/^/             /'

say "& binds two points into one operand so > can weave them; a list leaves them separate and > takes only the last. To build on many points, JOIN them."
