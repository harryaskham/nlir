#!/usr/bin/env python3
"""Check recorded public toy experiments: metric labels, splits, numeric values and SVGs."""
import json
import math
from pathlib import Path
import xml.etree.ElementTree as ET

ROOT=Path(__file__).resolve().parents[1]/'site/spec-lab'


def check(name, mode, profiles=None):
    trace=json.loads((ROOT/name).read_text())
    actual=trace.get('judge_mode','similarity')
    if actual!=mode:raise ValueError(f'{name}: unexpected judge mode {actual}')
    if mode=='strict':
        if trace.get('metric')!='reference-clause F1':raise ValueError('strict trace has wrong metric')
        if trace.get('writer_profiles')!=profiles:raise ValueError('wrong writer-profile condition')
        if trace.get('ceiling'):raise ValueError('do not label an unrelated paraphrase baseline a strict ceiling')
        pair=trace.get('comparison',{})
        if not pair.get('complete'):raise ValueError('missing complete A/B comparison')
        rows=pair['per_rule'];delta=pair['B_minus_A']
        if len(rows)!=4 or delta['rules']!=4:raise ValueError('wrong comparison cohort')
        if abs(sum(r['B']-r['A'] for r in rows)/len(rows)-delta['mean'])>1e-12:raise ValueError('comparison mean mismatch')
        if not delta['lower']<=delta['mean']<=delta['upper']:raise ValueError('bad comparison interval')
        if trace['models'].get('generation_version')!='gpt-6-luna':raise ValueError('do not relabel archived model versions')
    ids=trace['train_ids']+trace['test_ids']
    if not all(i.startswith('CR ') for i in ids):raise ValueError('public lab must contain invented CR rule IDs only')
    if set(trace['train_ids']) & set(trace['test_ids']):raise ValueError('overlapping splits')
    if not trace['rounds']:raise ValueError('no replay rounds')
    for r in trace['rounds']:
        if not r['program']:raise ValueError('missing program')
        if not math.isfinite(r['score']):raise ValueError('invalid selection score')
        for k in ('train','val','quality'):
            if r.get(k) is not None and not 0<=r[k]<=1:raise ValueError(f'invalid {k}')
        if r.get('graph'):
            tree=ET.fromstring(r['graph'])
            if any(n.tag.rsplit('}',1)[-1]=='script' for n in tree.iter()):raise ValueError('active script in graph')
    for group in trace['held_out'].values():
        if not 0<=group['mean']<=1:raise ValueError('invalid held-out score')
    print(f"{name}: {mode}, {len(trace['rounds'])-1} proposals, held-out {trace['held_out']['best']['mean']:.3f}")


if __name__=='__main__':
    check('trace.json','similarity')
    check('trace-strict-a.json','strict',0)
    check('trace-strict-b.json','strict',2)
