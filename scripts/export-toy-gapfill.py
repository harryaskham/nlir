#!/usr/bin/env python3
"""Export the gap-filled method's recorded run on the invented code-review spec for the spec lab.

Usage: export-toy-gapfill.py TOY_GAPFILL_DIR GAP_LISTS_JSON DATASET12_JSON OUT_JSON [ROUNDTRIP_SUMMARY_JSON]

TOY_GAPFILL_DIR holds the evaluation runs (spec-{val,test}, gapfill-{val,test}) of toy B·clean from
the spec alone and of B·clean told the extracted gap lists and trimmed, judged by the strict judge;
GAP_LISTS_JSON the lists read from each toy rule's authored profile. Exports, per rule, the lists,
sample 0 of both arms (parts and strict F1) and per-rule mean strict F1 over the samples, plus the
pooled summary. ROUNDTRIP_SUMMARY_JSON, if given, adds the round trip: lists read back from sample 0
and rewritten, and the floor (the same spec and lists re-sampled), each judged against sample 0's
own clauses. If TOY_GAPFILL_DIR also holds selected-{val,test} (one profile per rule, chosen part by part
from the four gap-filled drafts by how well each states the lists), each rule gains that profile and
its strict F1. Invented toy data only: refuses any rule outside `CR V`.
"""
import glob
import json
import statistics
import sys
from pathlib import Path

PARTS = ['APPLICABILITY', 'DECISION BOUNDARY', 'MET', 'NOT MET', 'UNCERTAIN']


def part_text(fields, label):
    if label == 'APPLICABILITY':
        return ' '.join(fields.get('applicability', []))
    for p in fields.get('decision_boundary', []):
        head, _, body = p.partition(':')
        if head.replace('*', '').strip().upper() == label:
            return body.strip()
    return ''


def load(run_dir):
    d = sorted(x for x in glob.glob(str(run_dir / 'eval-*')) if (Path(x) / 'eval.json').exists())[-1]
    out = []
    for f in sorted(Path(d).glob('*/result.json')):
        r = json.loads(f.read_text())['result']
        if not r['id'].startswith('CR V'):
            raise SystemExit(f"refusing non-toy rule {r['id']}")
        if r.get('error'):
            raise SystemExit(f"{r['id']}: failed output")
        out.append(r)
    return out


def main():
    run_root, lists_path, dataset_path, out_path = map(Path, sys.argv[1:5])
    rt = json.loads(Path(sys.argv[5]).read_text()) if len(sys.argv) > 5 else None
    lists = json.loads(lists_path.read_text())
    if any(not r.startswith('CR V') for r in lists):
        raise SystemExit('refusing non-toy lists')
    arms = {k: load(run_root / f'{k}-val') + load(run_root / f'{k}-test') for k in ('spec', 'gapfill')}
    if (run_root / 'selected-val').exists() and (run_root / 'selected-test').exists():
        arms['selected'] = load(run_root / 'selected-val') + load(run_root / 'selected-test')
    f1 = lambda r: statistics.fmean(p['sim'] for p in r['parts'])
    rules = []
    for rid in sorted(lists):
        row = {'id': rid, 'lists': lists[rid]}
        for k, recs in arms.items():
            mine = [r for r in recs if r['id'] == rid]
            s0 = next(r for r in mine if r['sample'] == 0)
            row[k] = {'f1': statistics.fmean(f1(r) for r in mine), 'samples': len(mine), 'sample0_f1': f1(s0),
                      'parts': {l: part_text(s0['fields'], l) for l in PARTS}}
        if rt:
            per = rt['per_rule']
            row['roundtrip'] = {'floor': per['floor'][rid], 'trip': statistics.fmean([per['round trip 0'][rid], per['round trip 1'][rid]]),
                                'spec': per['original spec'][rid]}
        rules.append(row)
    summary = {k: statistics.fmean(r[k]['f1'] for r in rules) for k in arms}
    doc = {'method': __doc__.split('\n\n')[1].replace('\n', ' '), 'models': {'writer': 'gpt-6-luna', 'judge and lists': 'gpt-6.1-sol'},
           'summary': summary | {'rules': len(rules), 'better': sum(r['gapfill']['f1'] > r['spec']['f1'] for r in rules)}, 'rules': rules}
    if 'selected' in arms:
        doc['summary']['selected_better'] = sum(r['selected']['f1'] > r['gapfill']['f1'] for r in rules)
    if rt:
        d = rt['round_trip_minus_floor']
        doc['summary']['roundtrip'] = {k: statistics.fmean(r['roundtrip'][k] for r in rules) for k in ('floor', 'trip', 'spec')} | {
            'diff': d['mean'], 'lower': d['lower'], 'upper': d['upper']}
    out_path.write_text(json.dumps(doc, ensure_ascii=False, indent=1) + '\n')
    print(json.dumps(doc['summary']))


if __name__ == '__main__':
    main()
