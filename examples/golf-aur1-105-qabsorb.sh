#!/usr/bin/env bash
# nlir-golf · aur1 · #105 — "the question absorbs everything but expansion" (?-projection law, completed)
#
# The `?` operator is a PROJECTION onto information: ask a question of something and you keep
# WHAT it's about and throw away everything that only changed its wording. Across the corpus
# I've watched `?` swallow operator after operator — negate (#36), formalise (#37), summarise
# (#72) — every one vanishes inside a question. This card completes the set with SHORTEN, and
# states the one law behind them all.
#
#   ?-ABSORPTION LAW    !x? ≈ @x? ≈ ~x? ≈ <x?  ≈  x?      but     >x?  ≠  x?
#     x = "we should migrate our database to postgres"
#     x?   → "Should we migrate our database to Postgres?"           ← baseline
#     <x?  → "Should we migrate our database to Postgres?"           ← shorten ABSORBED
#     @x?  → "Should we migrate our database to PostgreSQL?"         ← formalise ABSORBED
#     >x?  → "Should we migrate to PostgreSQL, moving off our current system to gain its
#             benefits — planning the transition, the tooling, the risks…?"  ← expand SURVIVES
#
# The unifying reason: `?` retains the INFORMATION and discards anything that didn't change it.
# Negate flips polarity, formalise shifts register, summarise/shorten cut LENGTH — none of them
# add or remove FACTS, so the question they'd pose is the same question. Only `>` (expand)
# INVENTS new information (my #70/#76), and new information means a genuinely richer question —
# so expansion is the sole operator that survives the projection. `?` = "keep the info, drop
# the styling"; `>x?` is the only way to actually deepen what's being asked (that's my #59
# elaborator and #95 question-ladder).
#
# Run:  ./examples/golf-aur1-105-qabsorb.sh
set -euo pipefail
cd "$(dirname "$0")/.."
NLIR="${NLIR:-./target/release/nlir}"
[ -x "$NLIR" ] || { echo "build first: cargo build --release (or set NLIR=...)"; exit 1; }
if [ -z "${LITELLM_MASTER_KEY:-}" ] && [ -n "${CACOPHONY_LITELLM_MASTER_KEY_FILE:-}" ]; then
  export LITELLM_MASTER_KEY="$(cat "$CACOPHONY_LITELLM_MASTER_KEY_FILE")"
fi
say() { printf '\n\033[1m%s\033[0m\n' "$1"; }
C='we should migrate our database to postgres'

say "THE ?-ABSORPTION LAW  — ? projects onto INFO: !x?≈@x?≈~x?≈<x?≈x?, but >x?≠x? (only expansion survives)"
echo   "  x: $C"
echo -n "  x?  (baseline)          => "; "$NLIR" -e "'$C'?"  --quiet | fold -s -w 80 | sed '2,$s/^/       /'
echo -n "  <x? (shorten ABSORBED)  => "; "$NLIR" -e "<'$C'?" --quiet | fold -s -w 80 | sed '2,$s/^/       /'
echo -n "  @x? (formal ABSORBED)   => "; "$NLIR" -e "@'$C'?" --quiet | fold -s -w 80 | sed '2,$s/^/       /'
echo -n "  >x? (expand SURVIVES)   => "; "$NLIR" -e ">'$C'?" --quiet | fold -s -w 80 | sed '2,$s/^/       /'

say "One law behind #36(!)/#37(@)/#72(~)/#105(<): ? keeps the INFO, drops register/polarity/length. Only > adds new info → only >x? deepens the question."
