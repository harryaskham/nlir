#!/usr/bin/env bash
# nlir-golf · aur1 · #39 — "the question is a projection" (P² = P, the capstone)
#
# The third and unifying ?-law. Ask a question of a question and NOTHING changes:
# x? ≈ x?? ≈ x??? — the mark is IDEMPOTENT. Put that with the two absorption laws
# I found earlier — ? strips polarity (#36) and register (#37) — and you have the
# exact mathematical signature of a PROJECTION operator: P² = P, landing on a
# stable subspace and staying there, while flattening the axes it ignores.
#
#   IDEMPOTENT   x? ≈ x?? ≈ x???
#     "we should adopt microservices" → x?/x??/x???  "Should we adopt microservices?"
#     "the migration is safe"         → x?/x??/x???  "Is the migration safe?"
#
#   ? AS A PROJECTION (the three ?-laws together):
#     ?? = ?        idempotent          (this one — the question of a question is the question)
#     ?! = ?        absorbs polarity    (#36)
#     ?@ = ?        absorbs register    (#37, and respects only information)
#
# So `?` doesn't wander — it maps any claim ONTO "the question about it" and parks
# there. Restyle the input, negate it, or re-question the output all you like: once
# projected, you're on the question-subspace to stay. The cleanest object in the
# whole nlir algebra: an operator that is its own square.
#
# Run:  ./examples/golf-aur1-39-projection.sh
set -euo pipefail
cd "$(dirname "$0")/.."
NLIR="${NLIR:-./target/release/nlir}"
[ -x "$NLIR" ] || { echo "build first: cargo build --release (or set NLIR=...)"; exit 1; }
if [ -z "${LITELLM_MASTER_KEY:-}" ] && [ -n "${CACOPHONY_LITELLM_MASTER_KEY_FILE:-}" ]; then
  export LITELLM_MASTER_KEY="$(cat "$CACOPHONY_LITELLM_MASTER_KEY_FILE")"
fi
say() { printf '\n\033[1m%s\033[0m\n' "$1"; }

say "? IS A PROJECTION  x? vs x?? vs x???  — questioning a question is a no-op (P² = P, idempotent)"
for C in 'we should adopt microservices' 'the migration is safe'; do
  echo   "  claim: $C"
  echo -n "   x?   => "; "$NLIR" -e "'$C'?"   --quiet
  echo -n "   x??  => "; "$NLIR" -e "'$C'??"  --quiet
  echo -n "   x??? => "; "$NLIR" -e "'$C'???" --quiet
done

say "?? = ? (idempotent) + ?! = ? (#36) + ?@ = ? (#37) ⇒ ? is a PROJECTION onto the question. Its own square."
