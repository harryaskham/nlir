#!/usr/bin/env python3
"""Merge a recorded read-back run (edit-loop.py --roundtrip, ideally --anchor'ed on a --fixpoint run) into the explainer's
patch sets (site/explain/traces.json): for each patched profile, the model edits it reads back as and whether the intended
one is among them. Toy rules only.
Usage: export-explain-readback.py RTM_JSON TRACES_JSON"""
import json, sys
from pathlib import Path
rtm_path, traces_path = map(Path, sys.argv[1:3])
R = json.loads(rtm_path.read_text())['results']; doc = json.loads(traces_path.read_text())
sets = (doc.get('patches') or {}).get('sets', {})
n = 0
for rid, x in R.items():
    if not rid.startswith('CR V'): continue
    for kind, e in x['edits'].items():
        S = sets.get(kind)
        if not S or rid not in S['rules']: continue
        S['rules'][rid]['readback'] = {'recovered': e['recovered'], 'other': e['other'], 'why': e.get('why', ''),
                                       'edits': [{'op': i.get('op', ''), 'group': i.get('group', ''), 'text': i.get('text', '')} for i in e['recovered_edits']]}
        n += 1
doc['patches']['readback_note'] = ('Reads back: the patched profile read back into the rule model by the backward pass, from the model settled on the '
                                   'authors\' profile — the model edits the prose implies, and whether the intended one is among them.')
traces_path.write_text(json.dumps(doc, ensure_ascii=False, separators=(',', ':')))
print(json.dumps({'readbacks': n}))
