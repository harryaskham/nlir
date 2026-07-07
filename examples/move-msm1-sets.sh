#!/usr/bin/env bash
# nlir showcase · msm1 · SET NOTATION — exact, composable set logic in a few sigils
#
# Harry asked for set notation (bd-49d65a): membership + union/intersection/difference,
# "working as expected on lists, dicts, strings." They are deterministic engine value
# builtins, so they are EXACT and composable — terse set algebra you can drop mid-pipe.
#
#   $elem%(x, coll)     membership — list element · dict key · string substring (EXACT)
#   $union%(a, b, …)    order-preserving dedup union (single list = unique/nub)
#   $inter%(a, b)       intersection — what's in both
#   $diff%(a, b)        difference — in the first, not the second
#
# Why not just a prompt? This is EXACT set algebra a model can't be trusted to do by eye,
# in 3–5 sigils, composing straight into $if / $sort / $map. (For a *semantic* "is it
# about X" judgment you want the fuzzy `~>?` implication operator, not $elem — $elem is
# deliberately exact. The nlir move is composing the two: $elem gates on the exact result
# of a fuzzy classifier. See move-msm0-pipe.sh for the det+fuzzy pipe family.)
#
# Every line here is deterministic and runs offline — no API key needed.
set -euo pipefail
cd "$(dirname "$0")/.."
NLIR="${NLIR:-./target/release/nlir}"
[ -x "$NLIR" ] || { echo "build first: cargo build --release (or set NLIR=...)"; exit 1; }
CFG="${NLIR_CONFIG:-config.example.yaml}"

say() { printf '\n\033[1m%s\033[0m\n' "$1"; }
why() { printf '   \033[2m(%s)\033[0m\n' "$1"; }
# runlit EXPR — evaluate a literal deterministic expression (no stdin).
runlit() { printf '  => '; "$NLIR" --config "$CFG" --mode det --quiet -e "$1" 2>&1 | paste -sd' ' -; }
# runpipe INPUT EXPR — pipe INPUT through nlir (deterministic).
runpipe() { printf '  => '; printf '%s' "$1" | "$NLIR" --config "$CFG" --mode det --quiet -e "$2" 2>&1 | paste -sd' ' -; }

say "MISSING-ITEMS GATE — what did the release checklist miss?"
why "exact set difference: required minus done. A prompt guesses; \$diff is exact."
runlit '$diff%([auth,logging,tests,docs],[auth,tests])'      # -> logging docs

say "DEDUP / NUB — distinct labels from a noisy list"
why "a single list through \$union collapses duplicates, order preserved — nub in 3 sigils"
runlit '$union%[bug,ui,bug,perf,ui,bug]'                     # -> bug ui perf

say "COMMON GROUND — reviewers on both PRs"
why "exact intersection — who is in list A AND list B"
runlit '$inter%([alice,bob,carol],[bob,carol,dave])'        # -> bob carol

say "MEMBERSHIP GATE — branch on whether a line is in the alert set"
why "\$elem composes straight into \$if: exact membership -> decision, mid-pipe"
runpipe 'disk ERROR at block 42' "\$if%(\$elem%('ERROR',\$_stdin),'investigate','ok')"   # -> investigate

say "DICT KEYS + MERGE — set ops treat a dict as its key set"
why "\$union of two dicts = the union of their keys; membership tests a key"
runlit '$union%({auth=1,logging=2},{logging=9,tracing=3})'  # -> auth logging tracing

say "exact set structure in a few sigils — composes into if / sort / map."
