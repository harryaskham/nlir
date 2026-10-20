#!/usr/bin/env python3
"""Merge a recorded editing-loop run into the explainer's traces (site/explain/traces.json → "patches").

Usage: export-explain-patches.py EDIT_LOOP_JSON [SPEC_EDIT_LOOP_JSON] TRACES_JSON

EDIT_LOOP_JSON is scripts/edit-loop.py's output: per rule, the authored profile and, for each kind of author edit, the
model edits, the routing (changed groups, routed fields), the patched fields and the judge's readings before and after.
The page shows each field as a word diff against the authored text, with the routing drawn as the program's graph.
Toy rules only; no model calls.
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
    *runs, traces_path = map(Path, sys.argv[1:])
    P = json.loads(runs[0].read_text())
    SP = json.loads(runs[1].read_text()) if len(runs) > 1 else None
    doc = json.loads(traces_path.read_text())
    R = {rid: x for rid, x in P['results'].items() if rid.startswith('CR V')}
    S = P['summary']
    CHECKS = {'exception': [{'key': 'not_met_covers', 'label': 'NOT MET covers it'}, {'key': 'met_excludes', 'label': 'MET excludes it'}, {'key': 'overlap', 'label': 'no overlap', 'bad': True}],
              'requirement': [{'key': 'met_requires', 'label': 'MET requires it'}, {'key': 'not_met_covers', 'label': 'NOT MET covers its failure'}, {'key': 'overlap', 'label': 'no overlap', 'bad': True}],
              'fact': [{'key': 'uncertain_names', 'label': 'UNCERTAIN names it'}]}
    LABEL = {'exception': 'An added exception', 'requirement': 'An added requirement', 'fact': 'An added deciding fact'}
    sets = {}
    for kind in ('exception', 'requirement', 'fact'):
        sets[kind] = {'label': f"{LABEL[kind]} ({len(R)} rules)", 'checks': CHECKS[kind], 'rules': {
            rid: {'title': x.get('title', ''), 'edit': f"The author edited {e['part']}: “…{e['author_edit'][-180:]}”", 'before': e['before'], 'after': e['after'],
                  'changed': e['routing']['changed'], 'route': e['routing']['route'], 'part': e['part'], 'warnings': e.get('warnings', []),
                  'fields': {l: {'before': x['authored'][l], 'after': tidy(l, e['patched'][l], x['authored'][l])} for l in x['authored']}}
            for rid, x in R.items() for e in [x['edits'][kind]]}}
    ex, rq, fc = S['exception'], S['requirement'], S['fact']
    note = (f"The editing loop, run by scripts/edit-loop.py through nlir programs: the author edits their own sentence; lens-concepts.nlir turns it into "
            f"rule-model edits; patch-route.nlir decides which fields read what changed, and patch.nlir patches only those. Across the {ex['rules']} rules, "
            f"an added exception reaches NOT MET {ex['not_met_covers']['after']} times and is excluded from MET {ex['met_excludes']['after']} times (authored: "
            f"{ex['not_met_covers']['before']} and {ex['met_excludes']['before']}); an added requirement gates MET {rq['met_requires']['after']} times; an added "
            f"deciding fact reaches UNCERTAIN {fc['uncertain_names']['after']} times and leaves MET and NOT MET as written {fc['verdict_untouched']} times"
            + (f"; the backward pass is typed (an edit changes only the model groups its field reads), and {sum(S[k].get('warnings', 0) for k in S)} node edit(s) it would have made elsewhere are shown as warnings instead" if P.get('typed') else
               " — the others are edits the backward pass also read as a new condition") + f". The fields an edit does not reach keep "
            f"{round(100 * (ex['other_similarity'] + rq['other_similarity'] + fc['other_similarity']) / 3)}% of the authors' words. Judge {P['models']['judge']}"
            + (f"; a second judge ({P['models']['judge2']}) agrees on these counts." if P['models'].get('judge2') and ex['not_met_covers']['after2'] == ex['not_met_covers']['after'] else '.'))
    if SP:  # the change starts in the specification: the packet gains a permission or a requirement
        SR = {rid: x for rid, x in SP['results'].items() if rid.startswith('CR V')}
        for kind in ('exception', 'requirement'):
            sets['spec-' + kind] = {'label': f"The specification gains {'an exception' if kind == 'exception' else 'a requirement'} ({len(SR)} rules)", 'checks': CHECKS[kind],
                'note': "The change starts in the rule's packet: lens-packet.nlir turns it into rule-model edits, each quoting the new passage it rests on; routing and the patch are as for an author's edit, and every field starts as the authors wrote it.",
                'rules': {rid: {'title': x.get('title', ''), 'edit': f"The specification now says: “{e['passage']}”", 'before': e['before'], 'after': e['after'],
                                'changed': e['routing']['changed'], 'route': e['routing']['route'], 'warnings': [],
                                'sources': [{'group': m.get('group'), 'text': m.get('text', ''), 'source': m.get('source', '')} for m in e['model_edits'] if m.get('op') in ('add', 'edit')],
                                'fields': {l: {'before': x['authored'][l], 'after': tidy(l, e['patched'][l], x['authored'][l])} for l in x['authored']}}
                          for rid, x in SR.items() for e in [x['edits'][kind]]}}
        sx = SP['summary']
        note += (f" When the change starts in the specification instead, the new passage reaches the model as a node quoting it and the authored profile is patched the same way: "
                 f"an added permission reaches NOT MET {sx['exception']['not_met_covers']['after']} times and an added requirement gates MET {sx['requirement']['met_requires']['after']} times of {sx['exception']['rules']}.")
    doc['patches'] = {'note': note, 'sets': sets}
    traces_path.write_text(json.dumps(doc, ensure_ascii=False, separators=(',', ':')))
    print(json.dumps({'patched_rules': len(R), 'sets': list(sets), 'bytes': traces_path.stat().st_size}))


if __name__ == '__main__':
    main()
