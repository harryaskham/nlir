#!/usr/bin/env bash
# The model reads; the evaluator counts. Neither alone does this reliably.
set -euo pipefail
NLIR=${NLIR:-nlir}
show() { printf '\n$ %s\n' "$1"; "$NLIR" --quiet -e "$1"; }
show "{\$0+\$1} ⊘ ['3 apples', '5 oranges', '2 pears']"                     # fuzzy read, exact sum → 10
show "#(\$filter%({\$0 ~> 'a complaint'}, ['love the app', 'it keeps crashing', 'when is dark mode', 'checkout is totally broken']))"
show "urgent={\$0 ~> 'urgent'}; \$if%(#(\$filter%(\$urgent, ['server is down', 'lunch plans', 'payments failing'])) >= 2, 'page on-call', 'queue for morning')"
