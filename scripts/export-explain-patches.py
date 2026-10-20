#!/usr/bin/env python3
"""Merge a recorded patch-forward run into the explainer's traces (site/explain/traces.json → "patches").

Usage: export-explain-patches.py PATCH_JSON TRACES_JSON

PATCH_JSON is a recorded run (rules → exception, authored and patched fields, judge verdicts before and after). The
page shows each field as a word diff against the authored text, untouched fields marked. Toy rules only; no model calls.
"""
import json
import sys
from pathlib import Path


def tidy(label, patched, authored):
    """The patch clean-up (site/spec-lab/patch-route.nlir $tidy): drop an echoed field label and a trailing closing
    bracket the patch added without an opener."""
    import re
    pat = r'(?i)^\W*' + re.escape(label) + r'\b\s*[:.\-–—]?\s*'
    out = patched if re.match(pat, authored) else re.sub(pat, '', patched, count=1).strip()
    unmatched = lambda t: t.count(')') - t.count('(')
    if unmatched(out) > unmatched(authored) and re.search(r'\)\s*$', out):
        out = re.sub(r'\)\s*$', '', out).rstrip()
    return out


def main():
    patch_path, traces_path = map(Path, sys.argv[1:3])
    P = json.loads(patch_path.read_text())
    S = P['summary']
    rules = {rid: {'title': x.get('title', ''), 'edit': 'An author added the exception: ' + x['exception'], 'before': x['before'], 'after': x['after'],
                   'fields': {l: {'before': x['authored'][l], 'after': tidy(l, x['patched'][l], x['authored'][l])} for l in x['authored']}}
             for rid, x in P['results'].items() if rid.startswith('CR V')}
    mixed = sum(1 for x in P['results'].values() if x['after'].get('overlap') and x['before'].get('overlap'))
    note = (f"An author's exception is added to the rule model as a node; then one call per field makes the smallest edit to the AUTHORED field that is consistent with "
            f"the edited model, leaving every other word. Across the {S['rules']} rules NOT MET covers the exception {S['not_met_covers']['after']} times "
            f"(authored: {S['not_met_covers']['before']}) and MET excludes it {S['met_excludes']['after']} times (authored: {S['met_excludes']['before']}); "
            f"{S['unchanged']} of {S['fields']} fields are untouched and the patched fields keep most of the authors' words. The overlaps the judge still finds are mixed "
            f"responses — an exception case together with a separate violation — and {mixed} of the {S['overlap']['after']} were there before the edit.")
    doc = json.loads(traces_path.read_text())
    doc['patches'] = {'note': note, 'sets': {'exception': {'label': f"An added exception ({len(rules)} rules)",
                      'checks': [{'key': 'not_met_covers', 'label': 'NOT MET covers it'}, {'key': 'met_excludes', 'label': 'MET excludes it'}, {'key': 'overlap', 'label': 'no overlap', 'bad': True}],
                      'rules': rules}}}
    traces_path.write_text(json.dumps(doc, ensure_ascii=False, separators=(',', ':')))
    print(json.dumps({'patched_rules': len(rules), 'bytes': traces_path.stat().st_size}))


if __name__ == '__main__':
    main()
