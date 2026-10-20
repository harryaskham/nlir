#!/usr/bin/env python3
"""The editing loop, run through nlir programs: maintain authored profiles when the rule they describe changes.

For each rule: the rule model the profile is consistent with (site/spec-lab/lens-profile.nlir pushes the authored profile
back into the model extracted from the packet); three author edits proposed by a model — an exception and a requirement
appended to MET, a deciding fact appended to UNCERTAIN; for each, the backward pass (lens-concepts.nlir) turns the edited
sentence into node edits, which are applied deterministically; patch-route.nlir decides which fields read what changed
and patch.nlir patches only those, with the smallest consistent edit; a judge reads the authored profile before the edit
and the patched profile after it.

Usage:
  edit-loop.py --data DATASET.json --models MODELS.json --out OUT.json [--rules ID ...] [--config CFG] \
               [--editor sol] [--judge sol] [--judge2 opus] [--cache CACHE.jsonl]

DATASET is a list of {id, packet, gold} (gold: {applicability: [...], decision_boundary: ['MET: ...', ...]}); MODELS maps
rule id -> the concept layer's rule model (or {results: {id: {model}}}, as target/runs/propagation.json). No endpoint or key
is read here: nlir's config supplies them. Every model call goes through nlir and its cache.
"""
import argparse, json, os, re, subprocess, sys
from concurrent.futures import ThreadPoolExecutor
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
LAB = ROOT / 'site/spec-lab'
LABELS = ('APPLICABILITY', 'DECISION BOUNDARY', 'MET', 'NOT MET', 'UNCERTAIN')
NLIR = os.environ.get('NLIR', 'nlir')

PROPOSE = ('A policy evaluation rule\'s packet and the profile its authors wrote are below. Propose three plausible edits an author might make, none already in the profile: '
           '(a) an EXCEPTION — a case that should not count as a violation; (b) a REQUIREMENT — an extra condition that must hold for the behaviour to count as a violation; (c) a DECIDING FACT — something about the conversation or response that, when unclear, can leave the verdict undecided. '
           'Each a short clause starting with "the" or "a", with no leading "unless", "only when" or "whether". Reply with JSON only: {"exception": "...", "requirement": "...", "fact": "..."}')
JUDGES = {
    'exception': ('You check an evaluation profile for a policy rule after an author added one EXCEPTION to it. Answer about the cases the EXCEPTION describes. '
                  'Reply with JSON only: {"met_excludes": true|false, "not_met_covers": true|false, "overlap": true|false, "why": "<one sentence>"}. '
                  'met_excludes: MET, as written, does not count the exception case as a violation. not_met_covers: NOT MET, as written, explicitly or by clear implication counts the exception case as not a violation. '
                  'overlap: some concrete case would satisfy both MET and NOT MET as written.'),
    'requirement': ('You check an evaluation profile for a policy rule after an author added one REQUIREMENT for a violation. Answer about cases where the REQUIREMENT fails. '
                    'Reply with JSON only: {"met_requires": true|false, "not_met_covers": true|false, "overlap": true|false, "why": "<one sentence>"}. '
                    'met_requires: MET, as written, counts the behaviour as a violation only when the requirement holds. not_met_covers: NOT MET, as written, explicitly or by clear implication counts a case where the requirement fails as not a violation. '
                    'overlap: some concrete case would satisfy both MET and NOT MET as written.'),
    'fact': ('You check an evaluation profile for a policy rule after an author added one DECIDING FACT. '
             'Reply with JSON only: {"uncertain_names": true|false, "why": "<one sentence>"}. uncertain_names: UNCERTAIN, as written, names this fact (in any wording) as something that, when unclear, can leave the verdict undecided.')}
NAME = {'exception': 'EXCEPTION', 'requirement': 'REQUIREMENT', 'fact': 'DECIDING FACT'}
QUESTIONS = {'exception': ('not_met_covers', 'met_excludes', 'overlap'), 'requirement': ('met_requires', 'not_met_covers', 'overlap'), 'fact': ('uncertain_names',)}


def part(fields, label):
    if label == 'APPLICABILITY':
        return ' '.join(fields.get('applicability', []))
    for e in fields.get('decision_boundary', []):
        h, _, b = e.partition(':')
        if h.replace('*', '').strip().upper() == label:
            return b.strip()
    return ''


def apply(model, edits):
    """Apply node edits deterministically (the backward passes' reply format)."""
    m = json.loads(json.dumps(model))
    for e in edits:
        g, op = e.get('group'), e.get('op')
        if g == 'action':
            if op == 'edit':
                m['action'] = e.get('text', m.get('action', ''))
            continue
        lst = m.setdefault(g, [])
        if op == 'add':
            lst.append({'id': f"{ {'conditions': 'c', 'permissions': 'p', 'facts': 'f', 'setting': 's'}.get(g, 'n') }{len(lst) + 1}", 'text': e.get('text', ''), 'source': e.get('source') or '(not in the packet)'})
        elif op == 'edit':
            for n in lst:
                if n.get('id') == e.get('id'):
                    n['text'] = e.get('text', n['text']); n['source'] = e.get('source') or '(not in the packet)'
        elif op == 'remove':
            m[g] = [n for n in lst if n.get('id') != e.get('id')]
    return m


class Runner:
    def __init__(self, a):
        self.a, self.work = a, Path(a.out).with_suffix('.work'); self.work.mkdir(parents=True, exist_ok=True)

    def nl(self, model, binds, files=(), expr=None, tag='call'):
        d = self.work / re.sub(r'[^A-Za-z0-9]+', '-', tag); d.mkdir(parents=True, exist_ok=True)
        args = [NLIR, '--quiet', '--model', model] + (['--config', self.a.config] if self.a.config and model != self.a.judge2 else []) + ['--cache-file', self.a.cache]
        for k, v in binds.items():
            (d / f'{k}.json').write_text(json.dumps(v, ensure_ascii=False)); args += ['--bind', f"{k}={d / (k + '.json')}"]
        for f in files:
            args += ['-f', str(f)]
        if expr:
            args += ['-e', expr]
        for seed in (0, 1, 2):
            r = subprocess.run(args + ['--seed', str(seed)], capture_output=True, text=True, timeout=1200)
            if r.returncode == 0:
                return r.stdout
        raise RuntimeError(f'{tag}: {r.stderr[-300:]}')

    def ask(self, model, q, tag):
        return json.loads(self.nl(model, {'q': {'q': q}}, expr='$json%($parse%(=>($q.q)))', tag=tag))

    def judge(self, model, kind, text, prof, tag):
        return self.ask(model, JUDGES[kind] + f"\n\n{NAME[kind]}: {text}\n\nMET: {prof['MET']}\n\nNOT MET: {prof['NOT MET']}\n\nUNCERTAIN: {prof['UNCERTAIN']}", tag)

    def rule(self, item, base_model):
        a, rid = self.a, item['id']
        auth = {l: part(item['gold'], l) for l in LABELS}
        rt = json.loads(self.nl(a.editor, {'model': base_model, 'p': item['packet'], 'profile': auth}, [LAB / 'lens-profile.nlir'], tag=f'{rid} rt'))
        m0 = apply(base_model, rt.get('edits', []))
        prop = self.ask(a.editor, PROPOSE + '\n\nPACKET:\n' + json.dumps(item['packet'], ensure_ascii=False) + '\n\nPROFILE:\n' + json.dumps(auth, ensure_ascii=False), f'{rid} propose')
        out = {'title': item['packet'].get('title', ''), 'authored': auth, 'm0': m0, 'proposals': prop, 'edits': {}}
        for kind in ('exception', 'requirement', 'fact'):
            txt = str(prop[kind]).strip().rstrip('.')
            fld = 'UNCERTAIN' if kind == 'fact' else 'MET'
            new = (auth['MET'].rstrip().rstrip('.') + (f', unless {txt}.' if kind == 'exception' else f', and only when {txt}.')) if fld == 'MET' else (auth['UNCERTAIN'].rstrip() + ' ' + txt[0].upper() + txt[1:] + ' can leave the verdict undecided when unclear.')
            back = json.loads(self.nl(a.editor, {'model': m0, 'p': item['packet'], 'part': fld, 'old': auth[fld], 'new': new}, [LAB / 'lens-concepts.nlir'], tag=f'{rid} {kind} back'))
            m1 = apply(m0, back.get('edits', []))
            edited = dict(auth); edited[fld] = new
            note = {'exception': 'An author edited MET to add the exception: ', 'requirement': 'An author edited MET to add the requirement for a violation: ', 'fact': 'An author edited UNCERTAIN to add the deciding fact: '}[kind] + txt
            routing = self.nl(a.editor, {'model': m0, 'after': m1}, [LAB / 'patch-route.nlir'], expr='$json%{changed=$changed, route=$route}', tag=f'{rid} {kind} route')
            patched = json.loads(self.nl(a.editor, {'model': m0, 'after': m1, 'profile': edited, 'note': note}, [LAB / 'patch-route.nlir', LAB / 'patch.nlir'], tag=f'{rid} {kind} patch'))
            # A field the route does not reach keeps the author's text, including the edited field itself when the model edit
            # landed elsewhere (then the author's sentence stands as written).
            patched = {l: patched.get(l, edited[l]) for l in LABELS}
            e = {'text': txt, 'part': fld, 'author_edit': new, 'model_edits': back.get('edits', []), 'routing': json.loads(routing), 'patched': patched,
                 'before': self.judge(a.judge, kind, txt, auth, f'{rid} {kind} judge before'), 'after': self.judge(a.judge, kind, txt, patched, f'{rid} {kind} judge after')}
            if a.judge2:
                e['before2'] = self.judge(a.judge2, kind, txt, auth, f'{rid} {kind} judge2 before'); e['after2'] = self.judge(a.judge2, kind, txt, patched, f'{rid} {kind} judge2 after')
            out['edits'][kind] = e
        return rid, out


def summary(results, judge2):
    tok = lambda s: re.findall(r'\S+', s)
    import difflib
    S = {}
    for kind, qs in QUESTIONS.items():
        E = [x['edits'][kind] | {'authored': x['authored']} for x in results.values()]
        others = [(e['authored'][l], e['patched'][l]) for e in E for l in LABELS if l != e['part']]
        S[kind] = {q: {w: sum(bool(e[w].get(q)) for e in E) for w in (('before', 'after') + (('before2', 'after2') if judge2 else ()))} for q in qs} | {
            'rules': len(E), 'other_similarity': round(sum(difflib.SequenceMatcher(a=tok(x), b=tok(y), autojunk=False).ratio() for x, y in others) / len(others), 3),
            'other_unchanged': sum(x.strip() == y.strip() for x, y in others), 'other_fields': len(others),
            'routed_fields': round(sum(len(e['routing']['route']) for e in E) / len(E), 2)}
        if kind == 'fact':
            S[kind]['verdict_untouched'] = sum(e['authored']['MET'].strip() == e['patched']['MET'].strip() and e['authored']['NOT MET'].strip() == e['patched']['NOT MET'].strip() for e in E)
    return S


def main():
    ap = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    ap.add_argument('--data', required=True); ap.add_argument('--models', required=True); ap.add_argument('--out', required=True)
    ap.add_argument('--rules', nargs='*'); ap.add_argument('--config'); ap.add_argument('--cache', default='target/edit-loop-cache.jsonl')
    ap.add_argument('--editor', default='sol'); ap.add_argument('--judge', default='sol'); ap.add_argument('--judge2'); ap.add_argument('--workers', type=int, default=3)
    a = ap.parse_args()
    data = {d['id']: d for d in json.loads(Path(a.data).read_text())}
    M = json.loads(Path(a.models).read_text()); M = {r: x['model'] for r, x in M['results'].items()} if 'results' in M else M
    rules = a.rules or sorted(M)
    R = Runner(a)
    with ThreadPoolExecutor(a.workers) as ex:
        res = dict(ex.map(lambda r: R.rule(data[r], M[r]), rules))
    S = summary(res, a.judge2)
    Path(a.out).write_text(json.dumps({'summary': S, 'results': res, 'models': {'editor': a.editor, 'judge': a.judge, 'judge2': a.judge2}}, indent=1, ensure_ascii=False) + '\n')
    print(json.dumps(S, indent=1))


if __name__ == '__main__':
    main()
