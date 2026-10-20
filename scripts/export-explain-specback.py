#!/usr/bin/env python3
"""Merge a recorded prose -> specification run (edit-loop.py --specback) into the explainer's patch sets
(site/explain/traces.json): for each author exception and requirement, the specification passage that would state the
model edit, and whether lens-packet.nlir reads the author's edit back from it. Toy rules only.
Usage: export-explain-specback.py SPECBACK_JSON TRACES_JSON"""
import json, sys
from pathlib import Path
sb_path, traces_path = map(Path, sys.argv[1:3])
R = json.loads(sb_path.read_text())['results']; doc = json.loads(traces_path.read_text())
sets = (doc.get('patches') or {}).get('sets', {}); n = 0
for rid, x in R.items():
    if not rid.startswith('CR V'): continue
    for kind, r in x.items():
        S = sets.get(kind)
        if 'skipped' in r or not S or rid not in S['rules']: continue
        S['rules'][rid]['specback'] = {'passages': [{'where': q.get('where'), 'text': q.get('text')} for q in r['passages']], 'recovered': r['recovered'], 'why': r.get('why', '')}
        n += 1
traces_path.write_text(json.dumps(doc, ensure_ascii=False, separators=(',', ':')))
print(json.dumps({'specback': n}))
