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
    loaded = [json.loads(r.read_text()) for r in runs]
    P = next(x for x in loaded if not x.get('sequence') and x.get('source', 'author') == 'author')
    SP = next((x for x in loaded if x.get('source') == 'packet'), None)
    SQ = next((x for x in loaded if x.get('sequence')), None)
    RP = next((x for x in loaded if x.get('repair')), None)
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
    if SQ:  # three edits in turn on the same profile: the authors' text against the final profile
        QR = {rid: x for rid, x in SQ['results'].items() if rid.startswith('CR V')}
        sets['sequence'] = {'label': f"Three edits in turn ({len(QR)} rules)", 'checks': [{'key': 'exc', 'label': 'exception still covered'}, {'key': 'req', 'label': 'requirement still gates MET'}, {'key': 'fact', 'label': 'fact still in UNCERTAIN'}],
            'note': "An exception, then a requirement, then a deciding fact, each applied to the previous step's patched profile and model; the diff is against the profile as the authors wrote it, and the checks read the final profile.",
            'rules': {rid: {'title': x.get('title', ''), 'edit': ' → '.join(f"{st['kind']}: “{st['text']}”" for st in x['steps']),
                            'before': {'exc': bool(x['final']['exception']['before'].get('not_met_covers')), 'req': bool(x['final']['requirement']['before'].get('met_requires')), 'fact': bool(x['final']['fact']['before'].get('uncertain_names'))},
                            'after': {'exc': bool(x['final']['exception']['after'].get('not_met_covers')), 'req': bool(x['final']['requirement']['after'].get('met_requires')), 'fact': bool(x['final']['fact']['after'].get('uncertain_names'))},
                            'changed': sorted({g for st in x['steps'] for g in st['routing']['changed']}), 'route': sorted({f for st in x['steps'] for f in st['routing']['route']}),
                            'warnings': [w | {'part': st['part']} for st in x['steps'] for w in st['warnings']], 'part': 'the edited field',
                            'fields': {l: {'before': x['authored'][l], 'after': tidy(l, x['final_profile'][l], x['authored'][l])} for l in x['authored']}}
                      for rid, x in QR.items()}}
        sq = SQ['summary']
        note += (f" Three edits in turn on the same profile compose: at the end every exception is still covered ({sq['exception']['not_met_covers']['final']} of {len(QR)}), every requirement still gates MET "
                 f"({sq['requirement']['met_requires']['final']}), every fact is still in UNCERTAIN ({sq['fact']['uncertain_names']['final']}), and the final profile keeps {round(100 * sq['final_profile']['similarity'])}% of the authors' words.")
    if RP:  # repairs of the authors' own inconsistencies, offered as proposals with the adjacent cases they would also move
        RR = {rid: x for rid, x in RP['results'].items() if rid.startswith('CR V') and x.get('repaired')}
        sets['repair'] = {'label': f"Repair proposals ({len(RR)} rules)", 'checks': [{'key': 'overlap', 'label': 'no overlap', 'bad': True}, {'key': 'gap', 'label': 'no gap', 'bad': True}],
            'note': "A consistency check reads the authors' profile; where MET and NOT MET overlap or leave a gap, patch-repair.nlir proposes the smallest edit that places the case. A proposal, not an edit: an independent judge often finds it also moves an adjacent case, shown below it.",
            'rules': {rid: {'title': x.get('title', ''), 'edit': 'The check found: ' + (x['check_before'].get('overlap_case') or x['check_before'].get('gap_case') or ''),
                            'before': x['check_before'], 'after': x['check_after'], 'collateral': (x.get('collateral') or {}).get('example', '') if (x.get('collateral') or {}).get('collateral') else '',
                            'fields': {l: {'before': x['authored'][l], 'after': x['profile'][l]} for l in x['authored']}} for rid, x in RR.items()}}
        rs = RP['summary']
        note += (f" Repairs of the authors' own inconsistencies are offered as proposals: the check's overlaps fall from {rs['check']['overlap']['before']} to {rs['check']['overlap']['after']} and its gaps from "
                 f"{rs['check']['gap']['before']} to {rs['check']['gap']['after']} at about {round(rs['words_added_per_repair'])} words a repair, but an independent judge reads {rs['collateral']} of {rs['flagged']} repairs as also moving an adjacent case.")
    doc['patches'] = {'note': note, 'sets': sets}
    traces_path.write_text(json.dumps(doc, ensure_ascii=False, separators=(',', ':')))
    print(json.dumps({'patched_rules': len(R), 'sets': list(sets), 'bytes': traces_path.stat().st_size}))


if __name__ == '__main__':
    main()
