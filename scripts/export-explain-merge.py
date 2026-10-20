#!/usr/bin/env python3
"""Merge a recorded concurrent-edit run (edit-loop.py --merge) into the explainer's patch sets (site/explain/traces.json) as
"Two authors at once": the authored profile patched once with both model edits, both edits' checks, and how a text merge of the
two separately patched profiles fared. Toy rules only.
Usage: export-explain-merge.py MERGE_JSON TRACES_JSON"""
import json, sys
from pathlib import Path
merge_path, traces_path = map(Path, sys.argv[1:3])
R = json.loads(merge_path.read_text())['results']; doc = json.loads(traces_path.read_text())
def holds(j, k, w):
    v = (j.get(k) or {}).get(w) or {}
    return all(v.get(q) for q in {'exception': ('not_met_covers', 'met_excludes'), 'requirement': ('met_requires', 'not_met_covers')}[k])
rules = {}
for rid, x in R.items():
    if not rid.startswith('CR V'): continue
    nconf = sum(1 for v in x['text_merge'].values() if v['conflicts'])
    rules[rid] = {'title': next((r['title'] for r in doc['rules'] if r['id'] == rid), ''), 'edit': x['note'],
                  'before': {'exc': False, 'req': False}, 'after': {'exc': holds(x['judged'], 'exception', 'after'), 'req': holds(x['judged'], 'requirement', 'after')},
                  'route': x['routing'].get('route', []), 'changed': x['routing'].get('changed', []),
                  'textmerge': (f"A text merge of the two separately patched profiles conflicts in {nconf} field{'s' if nconf != 1 else ''}; through the model both edits land in one patch." if nconf
                                else "A text merge of the two separately patched profiles happens to apply here; through the model both edits land in one patch."),
                  'fields': {l: {'before': x['authored'][l], 'after': x['merged'][l]} for l in x['authored']}}
doc.setdefault('patches', {}).setdefault('sets', {})['merge'] = {'label': f'Two authors at once: an exception and a requirement ({len(rules)} rules)',
    'checks': [{'key': 'exc', 'label': 'exception covered and excluded'}, {'key': 'req', 'label': 'requirement gates MET and is covered'}],
    'note': 'Two authors edit the same profile independently. Their prose does not merge — both rewrite MET and NOT MET — but their model edits do: both are applied to the model, routed, and the authored profile is patched once.',
    'rules': rules}
traces_path.write_text(json.dumps(doc, ensure_ascii=False, separators=(',', ':')))
print(json.dumps({'merge_rules': len(rules)}))
