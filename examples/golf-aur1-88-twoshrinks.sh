#!/usr/bin/env bash
# nlir-golf · aur1 · #88 — "the two shrinks" (~x keeps the POINT, <x keeps the FACTS)
#
# nlir has two ways to make text shorter, and they shed different things. `~` (summarise)
# keeps the POINT and sheds the detail — it'll fuse a messy incident into one flowing
# sentence. `<` (shorten) keeps the FACTS and sheds the words — it holds onto every specific,
# just tighter. Knowing which one to reach for is the difference between a headline and a
# record.
#
#   THE TWO SHRINKS   ~x   vs   <x
#     x = a deploy post-mortem: one core cause (bad migration) + three secondary factors
#         (rollback typo, misconfigured alert delaying paging 20 min, stale runbook link)
#     ~x → "A botched migration (NOT NULL, no default) broke order inserts, and a faulty
#           rollback, misconfigured alerting, and an outdated runbook turned it into ~90 min
#           of degraded checkout."                    ← the POINT (specifics fused away)
#     <x → "Deploy failed: a migration added a NOT NULL column with no default, breaking
#           inserts on orders. The rollback script had a typo and didn't revert; a
#           misconfigured alert delayed paging by 20 minutes; the runbook still linked the old
#           dashboard. ~90 min of degraded checkout."  ← the FACTS (every specific kept)
#
# See it: `~x` dropped "20 minutes", "typo", "old dashboard" — it kept the SHAPE of the
# incident. `<x` kept all of them — it's longer, but you could file it. Rule of thumb: `~`
# for a headline (lossy on detail), `<` for the record (loses no fact). One nuance — on a
# TIGHT fact-list where every fact is central, they CONVERGE (nothing secondary to shed);
# the gap only opens when the input has a hierarchy of importance, as here.
#
# Run:  ./examples/golf-aur1-88-twoshrinks.sh
set -euo pipefail
cd "$(dirname "$0")/.."
NLIR="${NLIR:-./target/release/nlir}"
[ -x "$NLIR" ] || { echo "build first: cargo build --release (or set NLIR=...)"; exit 1; }
if [ -z "${LITELLM_MASTER_KEY:-}" ] && [ -n "${CACOPHONY_LITELLM_MASTER_KEY_FILE:-}" ]; then
  export LITELLM_MASTER_KEY="$(cat "$CACOPHONY_LITELLM_MASTER_KEY_FILE")"
fi
say() { printf '\n\033[1m%s\033[0m\n' "$1"; }
C='the deploy went sideways. the main issue was a migration that added a NOT NULL column with no default, which broke inserts on the orders table. on top of that the rollback script had a typo so it did not revert cleanly, and the monitoring alert was misconfigured so nobody got paged for 20 minutes, and the on-call runbook still points to the old dashboard url. net effect: about 90 minutes of degraded checkout'

say "THE TWO SHRINKS  ~x vs <x  — ~ keeps the POINT (sheds specifics), < keeps the FACTS (sheds words)"
echo -n "  ~x (the POINT) => "; "$NLIR" -e "~'$C'" --quiet | fold -s -w 82 | sed '2,$s/^/                  /'
echo -n "  <x (the FACTS) => "; "$NLIR" -e "<'$C'" --quiet | fold -s -w 82 | sed '2,$s/^/                  /'

say "~ for a headline (lossy on detail, #43 essence); < for the record (keeps every fact, #35 floor). They converge on a tight fact-list, diverge on a hierarchy."
