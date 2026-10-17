#!/usr/bin/env python3
"""Export the counterexample test on the invented code-review spec for the spec lab.

Usage: export-toy-witness.py WITNESS_DIR DATASET12_JSON OUT_JSON

WITNESS_DIR holds one result.json per rule from the counterexample test: for every clause of
the authored profile, one model either quoted spec text that determines it or wrote a
counter-choice (a different requirement equally consistent with the spec that changes some
verdict); a second model checked each. derivation.json beside the dataset supplies the earlier
origin labels, joined only here. Invented toy data only: refuses any rule outside `CR V`.
"""
import json
import sys
from pathlib import Path

KEEP = ('label', 'text', 'final', 'citations', 'counter_choice', 'differs_on', 'open_question', 'rationale')


def main():
    witness_dir, dataset_path, out_path = map(Path, sys.argv[1:4])
    dataset = {d['id']: d for d in json.loads(dataset_path.read_text())}
    derivation = json.loads(dataset_path.with_name('derivation.json').read_text())
    rules, table = [], {}
    for f in sorted(witness_dir.glob('*/result.json')):
        r = json.loads(f.read_text())
        if not r['id'].startswith('CR V') or r['id'] not in dataset:
            raise SystemExit(f"refusing non-toy rule {r['id']}")
        origins = derivation[r['id']]
        rows = []
        for row, origin in zip(r['rows'], origins):
            if row['text'] != origin['clause']:
                raise SystemExit(f"{r['id']}: clause order differs")
            check = row.get('check') or {}
            rows.append({k: row.get(k) for k in KEEP} | {'origin': origin['class'], 'check': check.get('rationale', '')})
            table.setdefault(origin['class'], {}).setdefault(row['final'], 0)
            table[origin['class']][row['final']] += 1
        rules.append({'id': r['id'], 'title': dataset[r['id']]['packet']['title'], 'clauses': rows})
    if len(rules) != len(dataset):
        raise SystemExit(f'incomplete: {len(rules)} of {len(dataset)} rules')
    doc = {'method': __doc__.split('\n\n')[1].replace('\n', ' '), 'models': {'derive_or_counter': 'gpt-6.1-sol', 'check': 'claude-opus-5.5'},
           'rules': rules, 'by_origin': table}
    out_path.write_text(json.dumps(doc, ensure_ascii=False, indent=1) + '\n')
    total = sum(len(r['clauses']) for r in rules)
    opened = sum(c['final'] == 'witnessed open' for r in rules for c in r['clauses'])
    print(f'wrote {out_path}: {len(rules)} rules, {total} clauses, {opened} confirmed open')


if __name__ == '__main__':
    main()
