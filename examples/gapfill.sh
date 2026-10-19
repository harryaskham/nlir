#!/usr/bin/env bash
# Gap-filled specs, offline: the deterministic skeleton of the spec lab's gap-filled writer.
# A spec implies more points than its authors' prose makes, and leaves some decisions open. Two short
# lists per field close the gap — named points (implied, singled out) and additions (not implied) —
# and a list-guided trim keeps only what states them. Every output here is checked; with a model
# (--mode llm) the trim prompt goes to the model instead of being echoed.
set -euo pipefail
cd "$(dirname "$0")/.."
NLIR=${NLIR:-nlir}
LISTS="p={author_topics={MET=['states the tests that exercise the change'], UNCERTAIN=[]}, author_additions={MET=['names the test file']}}"
TRIM="keep_listed={\$if%(\$gt%(#(\$get%(\$p.author_topics,\$0,[])) + #(\$get%(\$p.author_additions,\$0,[])), 0), =>('Keep only what states a listed point. POINTS: '++\$join%(\$get%(\$p.author_topics,\$0,[]),'; ')++' | ADDITIONS: '++\$join%(\$get%(\$p.author_additions,\$0,[]),'; ')++' | DRAFT: '++\$1), \$1)}"
run() { "$NLIR" --config config.example.yaml --mode det --quiet -e "$LISTS; $TRIM; $1"; }
check() {
  local got; got=$(run "$1")
  if [ "$got" != "$2" ]; then printf 'FAIL  %s\n  got:      %s\n  expected: %s\n' "$1" "$got" "$2"; exit 1; fi
  printf 'ok    %-58s → %s\n' "$1" "$got"
}
# How many points and additions the authors listed for a field (a field's lists may be empty).
check "#(\$get%(\$p.author_topics,'MET',[])) + #(\$get%(\$p.author_additions,'MET',[]))" "2"
check "#(\$get%(\$p.author_topics,'UNCERTAIN',[]))"                                          "0"
# A field with no listed points passes through untouched: the trim never rewrites it.
check "\$keep_listed%('UNCERTAIN','Abstain when the diff is generated code.')"            "Abstain when the diff is generated code."
check "\$keep_listed%('NOT MET','No change to behaviour.')"                              "No change to behaviour."
# A listed field goes to the model with exactly its lists and the draft (det mode echoes the prompt).
check "\$keep_listed%('MET','A long draft.')" "response: (Keep only what states a listed point. POINTS: states the tests that exercise the change | ADDITIONS: names the test file | DRAFT: A long draft.)"
echo "gapfill: all checks passed"
