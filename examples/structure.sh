#!/usr/bin/env bash
# The structural core, offline: every line is checked.
set -euo pipefail
cd "$(dirname "$0")/.."
NLIR=${NLIR:-nlir}
run() { "$NLIR" --config config.example.yaml --mode det --quiet -e "$1"; }
check() {
  local got; got=$(run "$1")
  if [ "$got" != "$2" ]; then printf 'FAIL  %s\n  got:      %s\n  expected: %s\n' "$1" "$got" "$2"; exit 1; fi
  printf 'ok    %-58s → %s\n' "$1" "$got"
}
check "_sep=',';{\$0*\$0} ↦ [1,2,3]"                         "1,4,9"           # Functor map
check "{\$0+\$1} ⊘ (1..100)"                                  "5050"            # Foldable fold
check "_sep=',';[1,2] ++ [3]"                                 "1,2,3"           # Monoid: lists
check "_sep=',';{a=1,b=2} ++ {b=3,c=4}"                       "a=1,b=3,c=4"     # Monoid: dicts, right-biased
check "++[a,b,c]"                                             "abc"             # mconcat
check "'ab' _ 3"                                              "ababab"          # Monoid power
check "({\$0+1} _ 3) % 5"                                     "8"               # a form composed with itself
check "inc={\$0+1}; dbl={\$0*2}; (\$dbl ∘ \$inc) % 5"            "12"              # composition
check "#[a,b,c] + #{k=v} + #'abcd'"                           "8"               # length, polymorphic
check "[Mercury,Venus,Earth,Mars].2"                          "Earth"           # lens get
check "orders=[{who=ada,total=12.5},{who=bo,total=40},{who=cy,total=7}];\$join%({\$0.who} ↦ (\$filter%({\$0.total>=10},\$orders)),', ')" "ada, bo"
check "\$if%(3 < 5, yes, no)"                                  "yes"
echo "structure: all checks passed"
