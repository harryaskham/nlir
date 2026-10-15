#!/usr/bin/env bash
# Backward passes (lenses), offline: edit the prose a program produced and recover
# the spec edit (or program edit) that would produce it. Every result is checked.
set -euo pipefail
cd "$(dirname "$0")/../site/spec-lab"
NLIR=${NLIR:-nlir}
work=$(mktemp -d "${TMPDIR:-/tmp}/nlir-lens.XXXXXX")
trap 'rm -rf "$work"' EXIT
prog='$render%(($node%"CR V 1.1").profile)'
run() { "$NLIR" --mode det --quiet --bind spec=toy-spec.json -f spec.nlir -f profile.nlir -e "$prog"; }
put() { "$NLIR" put --edited "$1" --bind spec=toy-spec.json -f spec.nlir -f profile.nlir "$prog"; }
field() { python3 -c "import json,sys; r=json.load(sys.stdin); e=r['edits']; assert r['put_get'] is True, r; assert len(e)==1, e; print(e[0]['kind'], e[0]['target'], e[0]['changes'][0]['path'] or e[0].get('ast_path'))"; }

run > "$work/out.md"
# 1. A content edit to the MET criterion → the exact spec field.
python3 - "$work/out.md" "$work/content.md" <<'PY'
import sys
lines = open(sys.argv[1]).read().split("\n")
i = lines.index("> MET:") + 1
lines[i] = lines[i].rstrip(".") + ", or on the strength of the author's assurance alone."
open(sys.argv[2], "w").write("\n".join(lines))
PY
got=$(put "$work/content.md" | field)
[ "$got" = "data spec nodes/CR V 1.1/profile/decision_boundary/1" ] || { echo "FAIL content edit: $got"; exit 1; }
echo "ok    prose edit to MET          → $got"
# 2. A template edit to a heading → the program literal that wrote it.
sed 's/#### `decision_boundary`/#### `decision boundary`/' "$work/out.md" > "$work/template.md"
got=$(put "$work/template.md" | field)
case "$got" in "program statement "*) ;; *) echo "FAIL template edit: $got"; exit 1;; esac
echo "ok    heading edit               → $got"
# 3. No edit → no edits (GetPut).
got=$(put "$work/out.md" | python3 -c "import json,sys; r=json.load(sys.stdin); print(len(r['edits']), r['get_put'], r['put_get'])")
[ "$got" = "0 True True" ] || { echo "FAIL get-put: $got"; exit 1; }
echo "ok    unedited output            → no edits (GetPut, PutGet hold)"
echo "lens: all checks passed"
