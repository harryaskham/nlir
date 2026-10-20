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
# A changed condition adds the gating instruction for MET and NOT MET; an exception does not.
check condition '#$gate > 0' 'true'
check exception '#$gate'     '0'
# The tidy drops an echoed label and a trailing bracket the patch added without an opener — and nothing else.
check same '$tidy%("MET", "MET: Approves unread files.)", "Approves unread files.")' 'Approves unread files.'
check same '$tidy%("MET", "Approves (after a skim) unread files.", "Approves unread files.")' 'Approves (after a skim) unread files.'
check same '$tidy%("NOT MET", "Declines (until read).", "Declines (until read).")' 'Declines (until read).'
echo "patch: all checks passed"
