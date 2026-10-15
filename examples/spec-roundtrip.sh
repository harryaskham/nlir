#!/usr/bin/env bash
# A rule spec as native data: project each rule's profile to prose and parse it back, exactly.
set -euo pipefail
cd "$(dirname "$0")/../site/spec-lab"
NLIR=${NLIR:-nlir}
lab() { "$NLIR" --mode det --quiet --bind spec=toy-spec.json -f spec.nlir -f profile.nlir -e "$1"; }
echo "rules: $(lab '#$leaves')"
lab "\$render%((\$node%'CR V 2.2').profile)" | head -12
echo "…"
lab "ok={\$json%(\$fields%(\$render%((\$node%\$0).profile))) == \$json%((\$node%\$0).profile)}; #(\$filter%(\$ok, \$leaves)) ++ '/' ++ #\$leaves ++ ' rules round-trip exactly'"
