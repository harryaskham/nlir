#!/usr/bin/env bash
# nlir-golf · aur1 · #81 — "the compressors converge" (<~x ≈ ~<x ≈ ~x — a SECOND way to commute)
#
# At #75 I showed `@` and `>` commute because they move ORTHOGONAL axes (register ⊥ length) —
# independent, so order can't matter. This is a different reason to commute. `<` (shorten)
# and `~` (summarise) are NOT independent: both compress. Yet they STILL commute — because
# they push toward the SAME target, the informational essence, so any order converges there:
#
#     <~x  ≈  ~<x  ≈  ~x        (shorten and summarise collapse to the same core)
#
#   fact "the migration failed halfway because a foreign-key constraint we forgot about
#         rejected the backfill, leaving the table half-updated, which took an hour to
#         manually reconcile"
#     ~x  → "The migration failed midway when a forgotten FK constraint blocked the backfill,
#            leaving the table half-updated and needing an hour of manual reconciliation."
#     <~x → "An overlooked FK constraint blocked the backfill, so the migration failed midway
#            and needed an hour of manual reconciliation."
#     ~<x → "A forgotten FK constraint caused the backfill to fail partway, leaving the table
#            half-updated and needing an hour of manual reconciliation to fix."
#
# Same facts, same core, every order. So there are TWO ways operators commute: ORTHOGONAL
# (independent axes — #75 `@`,`>`) and CONVERGENT (collinear, both driving to one fixed point
# — this, `<`,`~`). And exactly one way they DON'T: OPPOSED on a shared axis (#26 `@`,`:` —
# formal vs simple pull register apart, so order decides who wins). Commutativity isn't one
# rule; it's a map of how two operators' directions relate.
#
# Run:  ./examples/golf-aur1-81-converge.sh
set -euo pipefail
cd "$(dirname "$0")/.."
NLIR="${NLIR:-./target/release/nlir}"
[ -x "$NLIR" ] || { echo "build first: cargo build --release (or set NLIR=...)"; exit 1; }
if [ -z "${LITELLM_MASTER_KEY:-}" ] && [ -n "${CACOPHONY_LITELLM_MASTER_KEY_FILE:-}" ]; then
  export LITELLM_MASTER_KEY="$(cat "$CACOPHONY_LITELLM_MASTER_KEY_FILE")"
fi
say() { printf '\n\033[1m%s\033[0m\n' "$1"; }
C='the migration failed halfway because a foreign-key constraint we forgot about rejected the backfill, leaving the table in a half-updated state that took an hour to manually reconcile'

say "THE COMPRESSORS CONVERGE  <~x ≈ ~<x ≈ ~x  — shorten & summarise commute (both drive to the essence)"
echo -n "  ~x  (gist)               => "; "$NLIR" -e "~'$C'"  --quiet | fold -s -w 80 | sed '2,$s/^/                            /'
echo -n "  <~x (shorten∘summarize)  => "; "$NLIR" -e "<~'$C'" --quiet | fold -s -w 80 | sed '2,$s/^/                            /'
echo -n "  ~<x (summarize∘shorten)  => "; "$NLIR" -e "~<'$C'" --quiet | fold -s -w 80 | sed '2,$s/^/                            /'

say "TWO ways to commute: ORTHOGONAL (independent axes, #75 @>) and CONVERGENT (collinear to one core, this). One way not to: OPPOSED same-axis (#26 @:)."
