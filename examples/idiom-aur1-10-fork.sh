#!/usr/bin/env bash
# nlir IDIOM · aur1 · 10 — "the fork"   >('<option A>' | '<option B>')
#
# A reusable MOVE for the pi plugin, built on the OR operator (`|`) that no other
# move uses. You're weighing two options and want them laid out clearly — the
# case and the tradeoff for each — so you can actually choose. One line:
#
#     >( '<option A>' | '<option B>' )
#      │       │
#      │       └─ | is a genuine either/or — two DISTINCT paths, not a blend
#      └───────── > expands the choice into a decision memo, keeping the paths separate
#
# The key is that `>` over `|` FORKS: it keeps A and B distinct and develops each
# on its own terms, instead of merging them. (`&` would fuse them into one plan;
# `|` keeps them as rival options.) Swap the last register to taste:
#     >(A | B)   → a full decision memo, case + tradeoff for each
#     ~(>(A | B))  → a one-line "you must choose between A and B"
#     @(A | B)   → the choice, stated formally
#
# HOW TO REUSE IT (type this in chat) whenever you're stuck between two paths:
#     |>('rewrite it in Rust' | 'harden the existing service')
#     |>('hire a contractor now' | 'train someone in-house over Q3')
#
# Run:  ./examples/idiom-aur1-10-fork.sh
set -euo pipefail
cd "$(dirname "$0")/.."
NLIR="${NLIR:-./target/release/nlir}"
[ -x "$NLIR" ] || { echo "build first: cargo build --release (or set NLIR=...)"; exit 1; }
if [ -z "${LITELLM_MASTER_KEY:-}" ] && [ -n "${CACOPHONY_LITELLM_MASTER_KEY_FILE:-}" ]; then
  export LITELLM_MASTER_KEY="$(cat "$CACOPHONY_LITELLM_MASTER_KEY_FILE")"
fi
say() { printf '\n\033[1m%s\033[0m\n' "$1"; }

say "THE FORK   >('<A>' | '<B>')   — two options in, a clear decision memo out (case + tradeoff for each)"
echo "  your two options: 'migrate to Postgres now'  |  'stay on MySQL and shard it'"
echo -n "  => "
"$NLIR" -e ">('migrate the database to Postgres now' | 'stay on MySQL and shard it')" --quiet | fold -s -w 82 | sed '2,$s/^/     /'

say "> over | FORKS: it keeps the two paths DISTINCT and develops each, instead of blending them (that's what & would do). Reusable whenever you're stuck between two paths. ~(>…) for a one-liner."
