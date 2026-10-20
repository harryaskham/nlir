#!/usr/bin/env python3
"""Merge a recorded lens-redundant.nlir run into the explainer's traces: each rule's exceptions marked as genuine carve-outs or
restatements of a boundary a condition already draws. Usage: export-explain-lint.py LINT_JSON TRACES_JSON. Toy rules only."""
import json, sys
from pathlib import Path
lint_path, traces_path = map(Path, sys.argv[1:3])
L = json.loads(lint_path.read_text())['results']
doc = json.loads(traces_path.read_text())
n = 0
for r in doc['rules']:
    if r['id'].startswith('CR V') and L.get(r['id']):
        ids = {p['id'] for p in r['concepts']['model'].get('permissions', [])}
        r['lint'] = {k: v for k, v in L[r['id']].items() if k in ids}; n += len(r['lint'])
traces_path.write_text(json.dumps(doc, ensure_ascii=False, separators=(',', ':')))
print(json.dumps({'exceptions_marked': n}))
