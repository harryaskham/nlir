#!/usr/bin/env bash
# The semantic core and the prelude (needs a configured model; outputs vary by model).
set -euo pipefail
NLIR=${NLIR:-nlir}
show() { printf '\n$ %s\n' "$1"; "$NLIR" --quiet -e "$1"; }
show "=>'name three prime numbers, comma-separated'"                    # obey
show "'lmk if any Qs' :: formal"                                        # recast
show "'the release slipped because QA found a migration bug' :: 'a haiku'"
show "'the planets from the sun' .. 3"                                  # project a position
show "'the deploy failed twice on a flaky integration test' .. 'the cause'"
show "!'the release is on track'"                                       # dual
show "'ship Friday' & 'keep the rollback ready'"                        # product
show "a='Ship on Friday.'; b='Ship on Friday, after the security review.'; [\$a Δ \$b, \$a ▷ (\$a Δ \$b)]"
show "'the server keeps crashing' ~> 'this is urgent'"                  # entails
show "'Ship on Friday.' ≈ 'We release at the end of the week.'"         # similarity
# The prelude: everyday rewrites as named forms over :: and ..
show "(\$gist ∘ \$formal) % 'hey so the thing is the cache keeps evicting stuff we still need'"
show "\$question ↦ ['the build is green', 'the migration is reversible']"
