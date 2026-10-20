#!/usr/bin/env bash
# Patch forward, routed by the rule model's dependencies (site/spec-lab/patch-route.nlir, patch.nlir), offline.
# An edit to the rule model reaches only the profile fields whose derivation reads what it changed: a new fact only
# UNCERTAIN, a new exception or a changed condition only MET and NOT MET, a testing setting only APPLICABILITY. The
# routing is deterministic and checked here; with a model the routed fields get the smallest consistent edit and
# every other field is returned exactly as written.
set -euo pipefail
cd "$(dirname "$0")/.."
NLIR=${NLIR:-nlir}
route() { "$NLIR" --config config.example.yaml --mode det --quiet --bind model=examples/patch/model.json --bind "after=examples/patch/$1.json" -f site/spec-lab/patch-route.nlir -e "$2"; }
check() {
  local got; got=$(route "$1" "$2" | tr '\n' ' ' | sed 's/ *$//')
  if [ "$got" != "$3" ]; then printf 'FAIL  %s %s\n  got:      %s\n  expected: %s\n' "$1" "$2" "$got" "$3"; exit 1; fi
  printf 'ok    %-10s %-24s → %s\n' "$1" "$2" "$got"
}
check fact      '$route'   'UNCERTAIN'
check exception '$route'   'MET NOT MET'
check condition '$route'   'MET NOT MET'
check setting   '$route'   'APPLICABILITY'
check same      '#$route'  '0'
# A changed condition or exception adds a scope instruction for MET and NOT MET (each its own); a new fact adds none.
check condition "\$sub%(\$gate, '(?s)^.*(condition).*\$', '\$1')" 'condition'
check exception "\$sub%(\$gate, '(?s)^.*(exception).*\$', '\$1')" 'exception'
check fact      '#$gate'     '0'
# In NOT MET an added exception is stated as an alternative: only when an exception changed.
check exception "\$sub%(\$nmexc, '(?s)^.*(one more alternative).*\$', '\$1')" 'one more alternative'
check condition '#$nmexc'    '0'
# The tidy drops an echoed label and a trailing bracket the patch added without an opener — and nothing else.
check same '$tidy%("MET", "MET: Approves unread files.)", "Approves unread files.")' 'Approves unread files.'
check same '$tidy%("MET", "Approves (after a skim) unread files.", "Approves unread files.")' 'Approves (after a skim) unread files.'
check same '$tidy%("NOT MET", "Declines (until read).", "Declines (until read).")' 'Declines (until read).'
# Typed backward (lens-typed.nlir): an edit to a field changes only the model groups that field reads.
typed() { "$NLIR" --config config.example.yaml --mode det --quiet --bind model=examples/patch/model.json --bind after=examples/patch/model.json --bind edits=examples/patch/back-fact.json --bind "part=examples/patch/part-$1.json" -f site/spec-lab/patch-route.nlir -f site/spec-lab/lens-typed.nlir -e "$2"; }
check_typed() {
  local got; got=$(typed "$1" "$2" | tr '\n' ' ' | sed 's/ *$//')
  if [ "$got" != "$3" ]; then printf 'FAIL  typed %s %s\n  got:      %s\n  expected: %s\n' "$1" "$2" "$got" "$3"; exit 1; fi
  printf 'ok    typed %-9s %-26s → %s\n' "$1" "$2" "$got"
}
check_typed UNCERTAIN '$map%({$0.group}, $kept)'    'facts'
check_typed UNCERTAIN '$map%({$0.group}, $dropped)' 'conditions'
check_typed MET       '$map%({$0.group}, $kept)'    'conditions'
echo "patch: all checks passed"
