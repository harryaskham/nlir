#!/usr/bin/env python3
"""Merge a recorded open-questions run into the explainer's traces (site/explain/traces.json -> "questions"): cases the authored
profile leaves open — two judges, each asked for a single verdict under the profile as written, disagree. Toy rules only.
Usage: export-explain-questions.py OQ_JSON TRACES_JSON"""
import json, sys
from pathlib import Path
oq_path, traces_path = map(Path, sys.argv[1:3])
O = json.loads(oq_path.read_text()); doc = json.loads(traces_path.read_text())
rows = [r for r in O['rows'] if r['rule'].startswith('CR V')]
items = [{'rule': r['rule'], 'kind': r['kind'], 'case': r['case'], 'a': r['sol'], 'b': r['opus']} for r in rows if r['open']]
n_ov = sum(r['kind'] == 'overlap' for r in rows); n_gap = sum(r['kind'] == 'gap' for r in rows)
o_ov = sum(r['open'] and r['kind'] == 'overlap' for r in rows); o_gap = sum(r['open'] and r['kind'] == 'gap' for r in rows)
doc['questions'] = {'judges': ['Sol', 'Opus'], 'titles': {r['id']: r['title'] for r in doc['rules']}, 'items': items,
    'note': (f"A consistency check offered {n_ov} cases that seem to meet both MET and NOT MET and {n_gap} that seem to meet neither. Asked instead for one verdict "
             f"under the profile as written, two judges agree on {n_ov - o_ov} and {n_gap - o_gap} of them: the profile decides those. The {o_ov + o_gap} below are the ones "
             "they disagree on — questions only the authors can settle.")}
traces_path.write_text(json.dumps(doc, ensure_ascii=False, separators=(',', ':')))
print(json.dumps({'open_questions': len(items)}))
