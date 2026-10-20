#!/usr/bin/env bash
# Gap-filled specs, offline: lib/gapfill.nlir's deterministic parts, every output checked.
# A spec implies more points than its authors' prose makes, and leaves some decisions open. Two lists per
# field close the gap — named points (implied, singled out) and additions (not implied) — and the library
# writes each field from the spec plus its lists, trims each draft to what states a listed item, and keeps
# the draft that covers the lists best. With a model, see gapfill-pipeline.sh.
set -euo pipefail
cd "$(dirname "$0")/.."
NLIR=${NLIR:-nlir}
LISTS="lists={MET={points=['tests that exercise the change'], additions=['names the test file']}, UNCERTAIN={points=[], additions=[]}}"
run() { "$NLIR" --config config.example.yaml --mode det --quiet -f lib/gapfill.nlir -e "$LISTS; $1"; }
check() {
  local got; got=$(run "$1")
  if [ "$got" != "$2" ]; then printf 'FAIL  %s\n  got:      %s\n  expected: %s\n' "$1" "$got" "$2"; exit 1; fi
  printf 'ok    %-66s → %s\n' "$1" "$got"
}
contains() {
  local got; got=$(run "$1")
  case "$got" in *"$2"*) printf 'ok    %-66s ∋ %s\n' "$1" "$2" ;; *) printf 'FAIL  %s\n  got: %s\n  missing: %s\n' "$1" "$got" "$2"; exit 1 ;; esac
}
# A field's listed items, points first.
check "_sep=',';\$gf_items%(\$lists, 'MET')"                                        "tests that exercise the change,names the test file"
# Coverage scoring: stated + half for partly, less 0.05 per other clause; out-of-range indices ignored.
check "\$gf_score%({stated=[0,1], partly=[2], other=1}, 4)"                         "0.575"
check "\$gf_score%({stated=[0,5], partly=[0], other=0}, 2)"                         "0.5"
check "\$gf_score%({other=2}, 0)"                                                   "-2"
# The pick: the first of the largest scores (pass the list wrapped: % spreads a bare list).
check "\$gf_argmax%[[0.2, 0.9, 0.5, 0.9]]"                                          "1"
# A field with no listed items is never rewritten.
check "\$gf_trim%(\$lists, 'UNCERTAIN', 'Abstain on generated code.')"              "Abstain on generated code."
# The writer's prompt carries the field's lists; k drafts are k distinct prompts (det mode echoes them).
contains "\$gf_write%({rule='r'}, \$lists, 'MET', 1)"                                "NAMED POINTS:"
contains "\$gf_write%({rule='r'}, \$lists, 'MET', 1)"                                "- names the test file"
check "#(\$gf_drafts%({rule='r'}, \$lists, 'UNCERTAIN', 3))"                        "3"
# A field with no listed items is written from the spec alone, never told to add nothing to empty lists.
contains "\$gf_write%({rule='r'}, \$lists, 'UNCERTAIN', 1)"                          "state concisely what the specification requires"
check "_sep=',';\$contains%(\$gf_write%({rule='r'}, \$lists, 'UNCERTAIN', 1), 'NAMED POINTS')" "false"
# Optional guidance (what the document and its fields mean) is prepended only when set, after loading.
check "_sep=',';\$contains%(\$gf_write%({rule='r'}, \$lists, 'MET', 1), 'GUIDANCE')"   "false"
contains "gf_guide='MET describes a violation.'; gf_field_guides={MET='One sentence.'}; \$gf_write%({rule='r'}, \$lists, 'MET', 1)" "FIELD GUIDANCE (MET):"
echo "gapfill: all checks passed"
