#!/usr/bin/env bash
# nlir-golf · aur1 · #87 — "negate early" (>!x ≠ !>x — a counterexample to orthogonal-commute)
#
# At #75 I claimed operators on ORTHOGONAL axes commute. `>` moves length, `!` moves polarity —
# independent axes — so `>!x` and `!>x` should be the same. They are NOT, and the failure is
# the most instructive result I've hit: it shows orthogonality is necessary but not sufficient.
#
#   claim "microservices are the right architecture for our team"
#     >!x  (negate the CLAIM, then develop)  → "Microservices are NOT right for our team.
#            Adopting them introduces significant operational overhead — separate deployment
#            pipelines, service discovery, inter-service networking, distributed tracing…"
#                                                      ← a COHERENT case for the opposite ✓
#     !>x  (develop the claim, then negate the ARGUMENT) → "Microservices are the wrong
#            architecture because they KEEP US FROM splitting our system into small,
#            independently deployable services…"
#                                                      ← INCOHERENT: that's what they DO ✗
#
# Look at `!>x`: it took the fully-developed PRO argument and negated it clause by clause, so
# "microservices let you deploy independently" flipped to "microservices prevent independent
# deployment" — which is nonsense. That's the tell: `!` means "the opposite" on a CLAIM, but
# "flip every sentence" on an ARGUMENT — and flipping every sentence of a coherent case
# produces a contradiction, not a counter-case. And `>` is exactly what turns the claim into
# an argument. So the operators DON'T commute, not because their axes overlap (they don't),
# but because `>` changes the OBJECT `!` acts on. The rule that falls out: negate EARLY, on
# the seed (`>!x`), never LATE, on the prose (`!>x`). Orthogonal axes commute only when
# neither operator changes what the other is operating on.
#
# Run:  ./examples/golf-aur1-87-negateearly.sh
set -euo pipefail
cd "$(dirname "$0")/.."
NLIR="${NLIR:-./target/release/nlir}"
[ -x "$NLIR" ] || { echo "build first: cargo build --release (or set NLIR=...)"; exit 1; }
if [ -z "${LITELLM_MASTER_KEY:-}" ] && [ -n "${CACOPHONY_LITELLM_MASTER_KEY_FILE:-}" ]; then
  export LITELLM_MASTER_KEY="$(cat "$CACOPHONY_LITELLM_MASTER_KEY_FILE")"
fi
say() { printf '\n\033[1m%s\033[0m\n' "$1"; }
C='microservices are the right architecture for our team'

say "NEGATE EARLY  >!x ≠ !>x  — negate the CLAIM then develop (coherent) vs develop then negate the ARGUMENT (incoherent)"
echo   "  claim: $C"
echo -n "  >!x (negate→expand, coherent) => "; "$NLIR" -e ">!'$C'" --quiet | fold -s -w 78 | sed '2,$s/^/       /'
echo -n "  !>x (expand→negate, flips ✗)  => "; "$NLIR" -e "!>'$C'" --quiet | fold -s -w 78 | sed '2,$s/^/       /'

say "Counterexample to #75: length⊥polarity yet they DON'T commute — > turns a claim into an argument, and ! differs on each. Rule: negate EARLY."
