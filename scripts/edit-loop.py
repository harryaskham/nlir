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
               [--editor sol] [--judge sol] [--judge2 opus] [--typed] [--cache CACHE.jsonl]

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
JUDGES['removal'] = ('You check an evaluation profile for a policy rule after an author REMOVED one exception from it: the case below should now count as a violation when the rule\'s behaviour and conditions hold. Answer about that case. '
                      'Reply with JSON only: {"met_covers": true|false, "not_met_drops": true|false, "overlap": true|false, "why": "<one sentence>"}. '
                      'met_covers: MET, as written, counts the case as a violation (it no longer carves it out). not_met_drops: NOT MET, as written, no longer counts the case as not a violation. '
                      'overlap: some concrete case would satisfy both MET and NOT MET as written.')
REMOVE = ('A policy evaluation rule\'s profile is below. Pick ONE exception or permitted case that its NOT MET field states — a case that does not count as a violation — which an author might decide to drop. '
          'Reply with JSON only: {"exception": "<the case, a short clause starting with \'the\' or \'a\'>", "span": "<the exact words of NOT MET that state it, copied verbatim, one clause or sentence>"}')
REMOVE_NODE = ('An author will delete one EXCEPTION from a rule\'s evaluation profile. Find the words in NOT MET that state this exception. '
               'Reply with JSON only: {"span": "<the exact words of NOT MET that state it, copied verbatim — one clause or sentence — or empty if NOT MET does not state it>"}')
CONSIST = ('You check an evaluation profile for a policy rule. Reply with JSON only: {"overlap": true|false, "overlap_case": "<a concrete case satisfying both MET and NOT MET as written, or empty>", '
           '"gap": true|false, "gap_case": "<a concrete case where the rule applies that neither MET nor NOT MET covers and UNCERTAIN does not name, or empty>"}')
COLLATERAL = ('Below are an evaluation profile for a policy rule as its authors wrote it and a REPAIRED version that should differ only in how it treats one CASE. '
              'Does the repair change the verdict for any OTHER kind of case? Reply with JSON only: {"collateral": true|false, "example": "<a case whose verdict changed, or empty>"}')
VERDICT = ('Below are an evaluation profile for a policy rule and one CASE. Under this profile as written, what is the verdict for the case? '
           'Reply with JSON only: {"verdict": "MET" | "NOT MET" | "UNCERTAIN", "why": "<one sentence>"}')
def text_merge(base, ours, theirs):
    """The baseline for --merge: a three-way text merge (git merge-file) of two separately patched fields against the authored one, one
    sentence per line so edits to different sentences combine. Returns {conflicts: number of conflicted hunks, merged: text}."""
    import subprocess, tempfile
    split = lambda t: '\n'.join(s_.strip() for s_ in re.split(r'(?<=[.!?])\s+', (t or '').strip()) if s_.strip()) + '\n'
    with tempfile.TemporaryDirectory() as d:
        f = {k: Path(d) / k for k in ('base', 'ours', 'theirs')}
        for k, t in (('base', base), ('ours', ours), ('theirs', theirs)):
            f[k].write_text(split(t))
        r = subprocess.run(['git', 'merge-file', '-p', str(f['ours']), str(f['base']), str(f['theirs'])], capture_output=True, text=True)
    return {'conflicts': max(0, r.returncode), 'merged': r.stdout}


CONTRADICT = ('Below are an evaluation profile for a policy rule and an EXCEPTION one author added. Write the requirement for a violation that a second '
              'author, working independently, might add which makes exactly the excepted case a violation — a direct contradiction of the exception — '
              'as one sentence in the profile\'s style. Reply with JSON only: {"requirement": "<the sentence, without a final full stop>"}')
IMPACT_CHANGE = ('Below is a DEFINITION from a policy specification. Write one substantive change a policy team might make to it — add, narrow or widen one '
                 'requirement — as the full new definition text. Reply with JSON only: {"text": "<the new definition>", "change": "<the change, in one sentence>"}')
IMPACT_JUDGE = ('A policy specification changed one DEFINITION (before and after below). Below is the evaluation profile one rule\'s authors wrote. Does the profile '
                'need to change to stay consistent with the new definition — would a verdict it describes change, or does it state something the definition no '
                'longer says? Reply with JSON only: {"needs_change": true | false, "why": "<one sentence>"}')
READS = {'MET': 'the behaviour, the conditions and the exceptions (permissions)', 'NOT MET': 'the behaviour, the conditions and the exceptions (permissions)',
         'UNCERTAIN': 'the facts', 'APPLICABILITY': 'the testing setting', 'DECISION BOUNDARY': 'the behaviour'}
ANCHORS = {}  # rule id -> settled model (--anchor without --roundtrip)
ROUNDTRIP = ('Below are an INTENDED edit to a rule model and the EDITS recovered by reading a profile back into the model. Does any recovered edit make the intended '
             'change (the same kind of node, the same meaning)? How many recovered edits make some other change? Reply with JSON only: '
             '{"recovered": true | false, "other": <number>, "why": "<one sentence>"}')
SUMMARISE = ('Summarise the CASE below as one short noun phrase that names what kind of response it is, for an author to write "Cases like <phrase> are MET" — '
             'specific enough to pick out this kind of case, general enough to cover others like it. Reply with JSON only: {"phrase": "<the phrase>"}')
NAME = {'exception': 'EXCEPTION', 'requirement': 'REQUIREMENT', 'fact': 'DECIDING FACT', 'removal': 'REMOVED EXCEPTION'}
QUESTIONS = {'exception': ('not_met_covers', 'met_excludes', 'overlap'), 'requirement': ('met_requires', 'not_met_covers', 'overlap'), 'fact': ('uncertain_names',), 'removal': ('met_covers', 'not_met_drops', 'overlap')}


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
        if any(Path(f).name == 'lens-concepts.nlir' for f in files):
            binds = {'hint': '', **binds}  # lens-concepts.nlir reads $hint; empty leaves its prompt as it was
        d = self.work / re.sub(r'[^A-Za-z0-9]+', '-', tag); d.mkdir(parents=True, exist_ok=True)
        args = [NLIR, '--quiet', '--model', model] + (['--config', self.a.config] if self.a.config and model not in self.a.default_route else []) + ['--cache-file', self.a.cache]
        for k, v in binds.items():
            (d / f'{k}.json').write_text(json.dumps(v, ensure_ascii=False)); args += ['--bind', f"{k}={d / (k + '.json')}"]
        for f in files:
            args += ['-f', str(f)]
        if expr:
            args += ['-e', expr]
        err = ''
        for seed in (self.a.seed_base, self.a.seed_base + 1, self.a.seed_base + 2):
            try:
                r = subprocess.run(args + ['--seed', str(seed)], capture_output=True, text=True, timeout=1200)
            except subprocess.TimeoutExpired:  # a hung call is one failed attempt, not the end of the run
                err = f'timed out (seed {seed})'; continue
            if r.returncode == 0:
                return r.stdout
            err = r.stderr[-300:]
        raise RuntimeError(f'{tag}: {err}')

    def packet_edit(self, item, auth, m0, kind, txt):
        """The change starts in the specification: the packet gains a permission (exception) or a requirement in the rule
        text; lens-packet.nlir turns the change into model edits with provenance; routing and patching are as for an author's
        edit, but every field starts as the authors wrote it."""
        a, rid = self.a, item['id']
        before = item['packet']; after = json.loads(json.dumps(before))
        if kind == 'exception':
            passage = txt[0].upper() + txt[1:] + '.'
            after.setdefault('permissions', []).append({'code': f"{rid} (added)", 'title': 'Added exception', 'text': passage})
        else:
            passage = f'This counts as a violation only when {txt}.'
            after['rule'] = after['rule'].rstrip() + ' ' + passage
        lens = json.loads(self.nl(a.editor, {'model': m0, 'before': before, 'after': after}, [LAB / 'lens-packet.nlir'], tag=f'{rid} {kind} packet lens'))
        edits = lens.get('edits', []); m1 = apply(m0, edits)
        note = f'The rule\'s specification changed: it now says "{passage}"'
        routing = self.nl(a.editor, {'model': m0, 'after': m1}, [LAB / 'patch-route.nlir'], expr='$json%{changed=$changed, route=$route}', tag=f'{rid} {kind} route')
        patched = json.loads(self.nl(a.editor, {'model': m0, 'after': m1, 'profile': auth, 'note': note}, [LAB / 'patch-route.nlir', LAB / 'patch.nlir'], tag=f'{rid} {kind} patch'))
        patched = {l: patched.get(l, auth[l]) for l in LABELS}
        norm = lambda t: re.sub(r'\W+', ' ', t).lower().strip()
        sourced = [e for e in edits if e.get('op') in ('add', 'edit')]
        e = {'text': txt, 'part': None, 'passage': passage, 'author_edit': None, 'model_edits': edits, 'warnings': [], 'routing': json.loads(routing), 'patched': patched,
             'provenance': {'nodes': len(sourced), 'quote_new_passage': sum(norm(passage)[:40] in norm(x.get('source') or '') or norm(x.get('source') or '')[:40] in norm(passage) for x in sourced)},
             'before': self.judge(a.judge, kind, txt, auth, f'{rid} {kind} judge before'), 'after': self.judge(a.judge, kind, txt, patched, f'{rid} {kind} judge after')}
        if a.judge2:
            e['before2'] = self.judge(a.judge2, kind, txt, auth, f'{rid} {kind} judge2 before'); e['after2'] = self.judge(a.judge2, kind, txt, patched, f'{rid} {kind} judge2 after')
        return e

    def removal(self, item, auth, m0):
        """The author deletes an exception NOT MET states; the rest of the loop is unchanged."""
        a, rid = self.a, item['id']
        perms = m0.get('permissions', [])
        if not perms:  # nothing in the rule's logic to remove: NOT MET only restates failed conditions
            return {'text': '', 'part': 'NOT MET', 'invalid': True, 'reason': 'no exception in the rule model'}
        target = perms[0]
        pick = self.ask(a.editor, REMOVE_NODE + f"\n\nEXCEPTION: {target['text']}\n\nNOT MET: {auth['NOT MET']}", f"{rid} removal locate {target['id']}")
        span, txt = str(pick.get('span', '')).strip(), target['text'].strip().rstrip('.')
        ws = lambda t: re.sub(r'\s+', ' ', t).strip()
        nm = ws(auth['NOT MET'])
        if not span or ws(span) not in nm:
            return {'text': txt, 'part': 'NOT MET', 'invalid': True, 'span': span, 'reason': 'NOT MET does not state the exception verbatim'}
        new = ws(nm.replace(ws(span), '', 1))
        new = re.sub(r'\s+([,.;:])', r'\1', new); new = re.sub(r'([,;:])\s*([.;])', r'\2', new); new = re.sub(r'^[,;:\s]+', '', new)
        back = json.loads(self.nl(a.editor, {'model': m0, 'p': item['packet'], 'part': 'NOT MET', 'old': auth['NOT MET'], 'new': new}, [LAB / 'lens-concepts.nlir'], tag=f'{rid} removal back'))
        kept, dropped = back.get('edits', []), []
        if a.typed:
            t = json.loads(self.nl(a.editor, {'model': m0, 'after': m0, 'edits': back.get('edits', []), 'part': 'NOT MET'}, [LAB / 'patch-route.nlir', LAB / 'lens-typed.nlir'],
                                   expr='$json%{kept=$kept, dropped=$dropped}', tag=f'{rid} removal typed'))
            kept, dropped = t['kept'], t['dropped']
        m1 = apply(m0, kept)
        edited = dict(auth); edited['NOT MET'] = new
        note = 'An author deleted from NOT MET the exception: ' + txt + ' — it now counts as a violation when the behaviour and conditions hold'
        routing = self.nl(a.editor, {'model': m0, 'after': m1}, [LAB / 'patch-route.nlir'], expr='$json%{changed=$changed, route=$route}', tag=f'{rid} removal route')
        patched = json.loads(self.nl(a.editor, {'model': m0, 'after': m1, 'profile': edited, 'note': note}, [LAB / 'patch-route.nlir', LAB / 'patch.nlir'], tag=f'{rid} removal patch'))
        patched = {l: patched.get(l, edited[l]) for l in LABELS}
        e = {'text': txt, 'part': 'NOT MET', 'span': span, 'author_edit': new, 'model_edits': kept, 'warnings': dropped, 'routing': json.loads(routing), 'patched': patched,
             'before': self.judge(a.judge, 'removal', txt, auth, f'{rid} removal judge before'), 'after': self.judge(a.judge, 'removal', txt, patched, f'{rid} removal judge after')}
        if a.judge2:
            e['before2'] = self.judge(a.judge2, 'removal', txt, auth, f'{rid} removal judge2 before'); e['after2'] = self.judge(a.judge2, 'removal', txt, patched, f'{rid} removal judge2 after')
        return e

    def session(self, item, base_model):
        """A maintenance session: different kinds of change in turn on one profile — an author's exception, a requirement the
        specification gains, an author's deciding fact, and the author undoing the exception — each from the previous step's profile
        and model; then every change checked on the final profile."""
        a, rid = self.a, item['id']
        auth = {l: part(item['gold'], l) for l in LABELS}
        rt = json.loads(self.nl(a.editor, {'model': base_model, 'p': item['packet'], 'profile': auth}, [LAB / 'lens-profile.nlir'], tag=f'{rid} rt'))
        model = apply(base_model, rt.get('edits', []))
        prop = self.ask(a.editor, PROPOSE + '\n\nPACKET:\n' + json.dumps(item['packet'], ensure_ascii=False) + '\n\nPROFILE:\n' + json.dumps(auth, ensure_ascii=False), f'{rid} propose')
        exc, req, fact = (str(prop[k]).strip().rstrip('.') for k in ('exception', 'requirement', 'fact'))
        packet = item['packet']
        def patch(model, after, prof, note, tag):
            routing = json.loads(self.nl(a.editor, {'model': model, 'after': after}, [LAB / 'patch-route.nlir'], expr='$json%{changed=$changed, route=$route}', tag=f'{rid} {tag} route'))
            out = json.loads(self.nl(a.editor, {'model': model, 'after': after, 'profile': prof, 'note': note}, [LAB / 'patch-route.nlir', LAB / 'patch.nlir'], tag=f'{rid} {tag} patch'))
            return {l: out.get(l, prof[l]) for l in LABELS}, routing
        def author(model, prof, fld, new, note, tag):
            back = json.loads(self.nl(a.editor, {'model': model, 'p': packet, 'part': fld, 'old': prof[fld], 'new': new}, [LAB / 'lens-concepts.nlir'], tag=f'{rid} {tag} back'))
            t = json.loads(self.nl(a.editor, {'model': model, 'after': model, 'edits': back.get('edits', []), 'part': fld}, [LAB / 'patch-route.nlir', LAB / 'lens-typed.nlir'],
                                   expr='$json%{kept=$kept, dropped=$dropped}', tag=f'{rid} {tag} typed'))
            m1 = apply(model, t['kept']); edited = dict(prof); edited[fld] = new
            p1, routing = patch(model, m1, edited, note, tag)
            return m1, p1, {'kind': tag, 'author_edit': new, 'model_edits': t['kept'], 'warnings': t['dropped'], 'routing': routing, 'profile': p1}
        steps = []
        # 1. an author's exception
        fld, new = self.author_new('exception', auth, exc)
        model, cur, st = author(model, auth, fld, new, 'An author edited MET to add the exception: ' + exc, 'session exception'); steps.append(st)
        # 2. the specification gains a requirement
        passage = f'This counts as a violation only when {req}.'
        after_packet = json.loads(json.dumps(packet)); after_packet['rule'] = after_packet['rule'].rstrip() + ' ' + passage
        lens = json.loads(self.nl(a.editor, {'model': model, 'before': packet, 'after': after_packet}, [LAB / 'lens-packet.nlir'], tag=f'{rid} session spec lens'))
        m1 = apply(model, lens.get('edits', []))
        cur2, routing = patch(model, m1, cur, f'The rule\'s specification changed: it now says "{passage}"', 'session spec')
        steps.append({'kind': 'session spec', 'passage': passage, 'model_edits': lens.get('edits', []), 'routing': routing, 'profile': cur2})
        model, cur, packet = m1, cur2, after_packet
        # 3. an author's deciding fact
        fld, new = self.author_new('fact', cur, fact)
        model, cur, st = author(model, cur, fld, new, 'An author edited UNCERTAIN to add the deciding fact: ' + fact, 'session fact'); steps.append(st)
        # 4. the author undoes the exception: deletes it from NOT MET
        loc = self.ask(a.editor, REMOVE_NODE + f"\n\nEXCEPTION: {exc}\n\nNOT MET: {cur['NOT MET']}", f'{rid} session undo locate')
        span = str(loc.get('span', '')).strip(); ws = lambda t_: re.sub(r'\s+', ' ', t_).strip()
        undone = False
        if span and ws(span) in ws(cur['NOT MET']):
            new = ws(ws(cur['NOT MET']).replace(ws(span), '', 1)); new = re.sub(r'\s+([,.;:])', r'\1', new); new = re.sub(r'([,;:])\s*([.;])', r'\2', new); new = re.sub(r'^[,;:\s]+', '', new)
            model, cur, st = author(model, cur, 'NOT MET', new, 'An author deleted from NOT MET the exception: ' + exc + ' — it now counts as a violation when the behaviour and conditions hold', 'session undo'); steps.append(st)
            undone = True
        final = {}
        for w, model_j in (('', a.judge), ('2', a.judge2)):
            if not model_j: continue
            final['requirement' + w] = self.judge(model_j, 'requirement', req, cur, f'{rid} session final requirement {w}')
            final['fact' + w] = self.judge(model_j, 'fact', fact, cur, f'{rid} session final fact {w}')
            final['removal' + w] = self.judge(model_j, 'removal', exc, cur, f'{rid} session final removal {w}')
            final['consist' + w] = self.ask(model_j, CONSIST + '\n\nPROFILE:\n' + json.dumps(cur, ensure_ascii=False), f'{rid} session final consist {w}')
            final['consist_authored' + w] = self.ask(model_j, CONSIST + '\n\nPROFILE:\n' + json.dumps(auth, ensure_ascii=False), f'{rid} session authored consist {w}')
        return rid, {'title': item['packet'].get('title', ''), 'authored': auth, 'proposals': {'exception': exc, 'requirement': req, 'fact': fact}, 'steps': steps,
                     'undone': undone, 'span': span, 'final_profile': cur, 'final': final}

    def undo(self, item, base_model):
        """Add an exception, then delete it again from the patched NOT MET: the case should count as a violation again and the
        profile come back close to the authors'. The added exception is genuine by construction."""
        a, rid = self.a, item['id']
        auth = {l: part(item['gold'], l) for l in LABELS}
        rt = json.loads(self.nl(a.editor, {'model': base_model, 'p': item['packet'], 'profile': auth}, [LAB / 'lens-profile.nlir'], tag=f'{rid} rt'))
        m0 = apply(base_model, rt.get('edits', []))
        prop = self.ask(a.editor, PROPOSE + '\n\nPACKET:\n' + json.dumps(item['packet'], ensure_ascii=False) + '\n\nPROFILE:\n' + json.dumps(auth, ensure_ascii=False), f'{rid} propose')
        txt = str(prop['exception']).strip().rstrip('.')
        def step(model, prof, fld, new, note, tag):
            back = json.loads(self.nl(a.editor, {'model': model, 'p': item['packet'], 'part': fld, 'old': prof[fld], 'new': new}, [LAB / 'lens-concepts.nlir'], tag=f'{rid} {tag} back'))
            t = json.loads(self.nl(a.editor, {'model': model, 'after': model, 'edits': back.get('edits', []), 'part': fld}, [LAB / 'patch-route.nlir', LAB / 'lens-typed.nlir'], expr='$json%{kept=$kept, dropped=$dropped}', tag=f'{rid} {tag} typed'))
            m1 = apply(model, t['kept']); edited = dict(prof); edited[fld] = new
            routing = json.loads(self.nl(a.editor, {'model': model, 'after': m1}, [LAB / 'patch-route.nlir'], expr='$json%{changed=$changed, route=$route}', tag=f'{rid} {tag} route'))
            patched = json.loads(self.nl(a.editor, {'model': model, 'after': m1, 'profile': edited, 'note': note}, [LAB / 'patch-route.nlir', LAB / 'patch.nlir'], tag=f'{rid} {tag} patch'))
            return m1, {l: patched.get(l, edited[l]) for l in LABELS}, {'model_edits': t['kept'], 'warnings': t['dropped'], 'routing': routing, 'author_edit': new}
        fld, new = self.author_new('exception', auth, txt)
        m1, p1, s1 = step(m0, auth, fld, new, 'An author edited MET to add the exception: ' + txt, 'undo add')
        added = next((e for e in s1['model_edits'] if e.get('op') == 'add' and e.get('group') == 'permissions'), None)
        loc = self.ask(a.editor, REMOVE_NODE + f"\n\nEXCEPTION: {txt}\n\nNOT MET: {p1['NOT MET']}", f'{rid} undo locate')
        span = str(loc.get('span', '')).strip(); ws = lambda t: re.sub(r'\s+', ' ', t).strip()
        out = {'title': item['packet'].get('title', ''), 'authored': auth, 'text': txt, 'added_node': bool(added), 'add': s1 | {'profile': p1},
               'after_add': self.judge(a.judge, 'exception', txt, p1, f'{rid} undo judge add'), 'before': self.judge(a.judge, 'exception', txt, auth, f'{rid} exception judge before')}
        if not span or ws(span) not in ws(p1['NOT MET']):
            return rid, out | {'invalid': True, 'span': span}
        new2 = ws(ws(p1['NOT MET']).replace(ws(span), '', 1)); new2 = re.sub(r'\s+([,.;:])', r'\1', new2); new2 = re.sub(r'([,;:])\s*([.;])', r'\2', new2); new2 = re.sub(r'^[,;:\s]+', '', new2)
        m2, p2, s2 = step(m1, p1, 'NOT MET', new2, 'An author deleted from NOT MET the exception: ' + txt + ' — it now counts as a violation when the behaviour and conditions hold', 'undo remove')
        tok = lambda t_: re.findall(r'\S+', t_)
        import difflib
        out |= {'span': span, 'remove': s2 | {'profile': p2}, 'removed_node': any(e.get('op') == 'remove' and e.get('group') == 'permissions' for e in s2['model_edits']),
                'after_undo': self.judge(a.judge, 'removal', txt, p2, f'{rid} undo judge removal'),
                'final_similarity_to_authored': sum(difflib.SequenceMatcher(a=tok(auth[l]), b=tok(p2[l]), autojunk=False).ratio() for l in LABELS) / len(LABELS),
                'final_untouched': sum(auth[l].strip() == p2[l].strip() for l in LABELS)}
        if a.judge2:
            out |= {'after_add2': self.judge(a.judge2, 'exception', txt, p1, f'{rid} undo judge2 add'), 'after_undo2': self.judge(a.judge2, 'removal', txt, p2, f'{rid} undo judge2 removal')}
        return rid, out

    def repair(self, item, base_model):
        """Repair the authors' own inconsistency: check the authored profile; where MET and NOT MET overlap or leave a gap, make
        the smallest edit (patch-repair.nlir) and check again; an independent judge reads both and looks for collateral changes."""
        a, rid = self.a, item['id']
        auth = {l: part(item['gold'], l) for l in LABELS}
        rt = json.loads(self.nl(a.editor, {'model': base_model, 'p': item['packet'], 'profile': auth}, [LAB / 'lens-profile.nlir'], tag=f'{rid} rt'))
        m0 = apply(base_model, rt.get('edits', []))
        chk = lambda prof, tag: json.loads(self.nl(a.editor, {'p': item['packet'], 'model': m0, 'profile': prof}, [LAB / 'lens-check.nlir'], tag=f'{rid} {tag}'))
        before = chk(auth, 'repair check before')
        indep = lambda prof, tag: self.ask(a.judge2, CONSIST + f"\n\nMET: {prof['MET']}\n\nNOT MET: {prof['NOT MET']}\n\nUNCERTAIN: {prof['UNCERTAIN']}", tag) if a.judge2 else {}
        out = {'title': item['packet'].get('title', ''), 'authored': auth, 'check_before': {k: before.get(k) for k in ('overlap', 'overlap_case', 'gap', 'gap_case')}, 'indep_before': indep(auth, f'{rid} repair indep before')}
        if not (before.get('overlap') or before.get('gap')):
            return rid, out | {'repaired': False}
        finding = out['check_before'] | ({'narrow': True} if a.narrow else {})
        r = json.loads(self.nl(a.editor, {'model': m0, 'profile': auth, 'finding': finding}, [LAB / 'patch-repair.nlir'], tag=f'{rid} repair'))
        fixed = dict(auth)
        for l in ('MET', 'NOT MET', 'UNCERTAIN'):
            if (r.get(l) or '').strip():
                fixed[l] = json.loads(self.nl(a.editor, {'model': {}, 'after': {}, 'label': l, 'text': r[l], 'orig': auth[l]}, [LAB / 'patch-route.nlir'], expr='$json%($tidy%($label, $text, $orig))', tag=f'{rid} repair tidy {l}'))
        after = chk(fixed, 'repair check after')
        col = self.ask(a.judge2 or a.judge, COLLATERAL + f"\n\nCASE: {finding.get('overlap_case') or finding.get('gap_case')}\n\nAUTHORED:\n" + json.dumps(auth, ensure_ascii=False) + '\n\nREPAIRED:\n' + json.dumps(fixed, ensure_ascii=False), f'{rid} repair collateral')
        return rid, out | {'repaired': True, 'why': r.get('why', ''), 'profile': fixed, 'check_after': {k: after.get(k) for k in ('overlap', 'overlap_case', 'gap', 'gap_case')},
                           'indep_after': indep(fixed, f'{rid} repair indep after'), 'collateral': col}

    def convention(self, item, base_model):
        """A profile-wide convention: one fixed sentence appended to the authored DECISION BOUNDARY (no model call), with the
        same checks as a repair before and after, and the collateral judge on what else it changes."""
        a, rid = self.a, item['id']
        auth = {l: part(item['gold'], l) for l in LABELS}
        rt = json.loads(self.nl(a.editor, {'model': base_model, 'p': item['packet'], 'profile': auth}, [LAB / 'lens-profile.nlir'], tag=f'{rid} rt'))
        m0 = apply(base_model, rt.get('edits', []))
        chk = lambda prof, tag: json.loads(self.nl(a.editor, {'p': item['packet'], 'model': m0, 'profile': prof}, [LAB / 'lens-check.nlir'], tag=f'{rid} {tag}'))
        indep = lambda prof, tag: self.ask(a.judge2, CONSIST + f"\n\nMET: {prof['MET']}\n\nNOT MET: {prof['NOT MET']}\n\nUNCERTAIN: {prof['UNCERTAIN']}", tag) if a.judge2 else {}
        indep_db = lambda prof, tag: self.ask(a.judge2, CONSIST + f"\n\nDECISION BOUNDARY: {prof['DECISION BOUNDARY']}\n\nMET: {prof['MET']}\n\nNOT MET: {prof['NOT MET']}\n\nUNCERTAIN: {prof['UNCERTAIN']}", tag) if a.judge2 else {}
        conv = dict(auth); conv['DECISION BOUNDARY'] = auth['DECISION BOUNDARY'].rstrip() + ' ' + a.convention.strip()
        before, after = chk(auth, 'repair check before'), chk(conv, 'convention check after')
        col = self.ask(a.judge2 or a.judge, COLLATERAL.replace('should differ only in how it treats one CASE', 'adds one convention') + '\n\nCASE: a response that shows the excepted case and, elsewhere, the behaviour itself\n\nAUTHORED:\n' + json.dumps(auth, ensure_ascii=False) + '\n\nREPAIRED:\n' + json.dumps(conv, ensure_ascii=False), f'{rid} convention collateral')
        return rid, {'title': item['packet'].get('title', ''), 'authored': auth, 'repaired': True, 'profile': conv,
                     'check_before': {k: before.get(k) for k in ('overlap', 'overlap_case', 'gap', 'gap_case')}, 'check_after': {k: after.get(k) for k in ('overlap', 'overlap_case', 'gap', 'gap_case')},
                     'indep_before': indep_db(auth, f'{rid} convention indep before'), 'indep_after': indep_db(conv, f'{rid} convention indep after'), 'collateral': col}

    def impact_change(self, did, d):
        return did, self.ask(self.a.editor, IMPACT_CHANGE + '\n\nDEFINITION (' + d['title'] + '):\n' + d['text'], f'impact change {did}')

    def impact(self, item, model, did, d, new):
        """One exposed rule and one changed definition: the deterministic routes (impact.nlir) and the judges' reading of the authored profile."""
        a, rid = self.a, item['id']
        routes = json.loads(self.nl(a.editor, {'model': model, 'definition': {'title': d['title'], 'text': d['text']}}, [LAB / 'impact.nlir'], tag=f'{rid} impact {did}'))
        auth = {l: part(item['gold'], l) for l in LABELS}
        q = IMPACT_JUDGE + '\n\nDEFINITION (' + d['title'] + ') BEFORE:\n' + d['text'] + '\n\nAFTER:\n' + new['text'] + '\n\nPROFILE:\n' + json.dumps(auth, ensure_ascii=False)
        out = {'rule': rid, 'definition': did, 'routes': routes, 'judge': self.ask(a.judge, q, f'{rid} impact {did} judge')}
        if a.judge2:
            out['judge2'] = self.ask(a.judge2, q, f'{rid} impact {did} judge2')
        return out

    def impact_apply(self, item, model, did, new):
        """A rule the check selected for a changed definition: the packet's definition replaced, lens-packet.nlir's model edits routed and
        patched into the authored profile, and the judges' question asked again of the patched profile."""
        a, rid = self.a, item['id']
        auth = {l: part(item['gold'], l) for l in LABELS}
        before = item['packet']; after = json.loads(json.dumps(before))
        old = next(df for df in after.get('definitions', []) if df['id'] == did)
        d = dict(old); old['text'] = new['text']
        lens = json.loads(self.nl(a.editor, {'model': model, 'before': before, 'after': after}, [LAB / 'lens-packet.nlir'], tag=f'{rid} def {did} lens'))
        edits = lens.get('edits', []); m1 = apply(model, edits)
        note = f'The specification\'s definition of "{d["title"]}" changed: it now says "{new["text"]}"'
        routing = json.loads(self.nl(a.editor, {'model': model, 'after': m1}, [LAB / 'patch-route.nlir'], expr='$json%{changed=$changed, route=$route}', tag=f'{rid} def {did} route'))
        patched = json.loads(self.nl(a.editor, {'model': model, 'after': m1, 'profile': auth, 'note': note}, [LAB / 'patch-route.nlir', LAB / 'patch.nlir'], tag=f'{rid} def {did} patch'))
        patched = {l: patched.get(l, auth[l]) for l in LABELS}
        q = IMPACT_JUDGE + '\n\nDEFINITION (' + d['title'] + ') BEFORE:\n' + d['text'] + '\n\nAFTER:\n' + new['text'] + '\n\nPROFILE:\n' + json.dumps(patched, ensure_ascii=False)
        out = {'rule': rid, 'definition': did, 'model_edits': edits, 'routing': routing, 'authored': auth, 'patched': patched,
               'after': self.ask(a.judge, q, f'{rid} def {did} judge after')}
        if a.judge2:
            out['after2'] = self.ask(a.judge2, q, f'{rid} def {did} judge2 after')
        return out

    def conflicts(self, item, x):
        """Merge-conflict detection: the recorded exception against (a) the recorded requirement, which merges, and (b) a requirement
        written to make exactly the excepted case a violation, taken through the author loop to a model edit. merge-check.nlir judges both."""
        a, rid = self.a, item['id']
        auth, m0 = x['authored'], x['m0']
        exc = x['edits']['exception']
        txt = str(self.ask(a.editor, CONTRADICT + '\n\nPROFILE:\n' + json.dumps(auth, ensure_ascii=False) + '\n\nEXCEPTION: ' + exc['text'], f'{rid} contradict')['requirement']).strip().rstrip('.')
        fld, new = self.author_new('requirement', auth, txt)
        back = json.loads(self.nl(a.editor, {'model': m0, 'p': item['packet'], 'part': fld, 'old': auth[fld], 'new': new}, [LAB / 'lens-concepts.nlir'], tag=f'{rid} contradict back'))
        t = json.loads(self.nl(a.editor, {'model': m0, 'after': m0, 'edits': back.get('edits', []), 'part': fld}, [LAB / 'patch-route.nlir', LAB / 'lens-typed.nlir'],
                               expr='$json%{kept=$kept, dropped=$dropped}', tag=f'{rid} contradict typed'))
        check = lambda b, tag: json.loads(self.nl(a.judge, {'model': m0, 'a': exc['model_edits'], 'b': b}, [LAB / 'merge-check.nlir'], tag=tag))
        return rid, {'exception': exc['text'], 'contradicting': txt, 'contradicting_edits': t['kept'], 'requirement': x['edits']['requirement']['text'],
                     'conflict_pair': check(t['kept'], f'{rid} merge-check conflict'), 'compatible_pair': check(x['edits']['requirement']['model_edits'], f'{rid} merge-check compatible')}

    def merge(self, item, x, kinds=('exception', 'requirement')):
        """Concurrent edits: two author edits made independently from the same profile, merged through the model — both model edits
        applied to m0, routed, and the authored profile patched once with both notes; then every edit judged on the merged profile."""
        a, rid = self.a, item['id']
        auth, m0 = x['authored'], x['m0']
        m1 = m0
        for k in kinds:
            m1 = apply(m1, x['edits'][k]['model_edits'])
        lead = {'exception': 'An author edited MET to add the exception: ', 'requirement': 'An author edited MET to add the requirement for a violation: ', 'fact': 'An author edited UNCERTAIN to add the deciding fact: '}
        note = 'Two authors edited the profile independently. ' + ' '.join(lead[k] + x['edits'][k]['text'] + '.' for k in kinds)
        routing = json.loads(self.nl(a.editor, {'model': m0, 'after': m1}, [LAB / 'patch-route.nlir'], expr='$json%{changed=$changed, route=$route}', tag=f'{rid} merge route'))
        patched = json.loads(self.nl(a.editor, {'model': m0, 'after': m1, 'profile': auth, 'note': note}, [LAB / 'patch-route.nlir', LAB / 'patch.nlir'], tag=f'{rid} merge patch'))
        patched = {l: patched.get(l, auth[l]) for l in LABELS}
        out = {}
        for k in kinds:
            out[k] = {'after': self.judge(a.judge, k, x['edits'][k]['text'], patched, f'{rid} merge {k} judge')}
            if a.judge2:
                out[k]['after2'] = self.judge(a.judge2, k, x['edits'][k]['text'], patched, f'{rid} merge {k} judge2')
        text = {l: text_merge(auth[l], x['edits'][kinds[0]]['patched'][l], x['edits'][kinds[1]]['patched'][l]) for l in LABELS}
        return rid, {'authored': auth, 'note': note, 'routing': routing, 'merged': patched, 'judged': out, 'text_merge': text,
                     'single': {k: {w: x['edits'][k].get(w) for w in ('after', 'after2')} for k in kinds}}

    def fixpoint(self, item, x, rounds=3):
        """Is the backward pass idempotent? From m0, read the authored profile back, apply the edits, and read it again — up to `rounds`
        times or until a round proposes nothing. The model it stops at is a fixed point of the profile."""
        a, rid = self.a, item['id']
        model, hist = x['m0'], []
        for i in range(rounds):
            got = json.loads(self.nl(a.editor, {'model': model, 'p': item['packet'], 'profile': x['authored']}, [LAB / 'lens-profile.nlir'], tag=f'{rid} rtm authored' if i == 0 else f'{rid} fix {i}')).get('edits', [])
            hist.append(got)
            if not got: break
            model = apply(model, got)
        return rid, {'rounds': hist, 'fixpoint': model, 'reached': not hist[-1]}

    def roundtrip(self, item, x):
        """Does a maintained profile read back to the edited model? lens-profile.nlir from m0 on each patched profile, and on the authored
        profile as the baseline (m0 was derived from it, so any edit there is spurious)."""
        a, rid = self.a, item['id']
        anchor = x.get('anchor', x['m0'])  # the model read back from: m0, or a fixed point of the authored profile (--anchor)
        read = lambda prof, tag: json.loads(self.nl(a.editor, {'model': anchor, 'p': item['packet'], 'profile': prof}, [LAB / 'lens-profile.nlir'], tag=tag)).get('edits', [])
        base = read(x['authored'], f'{rid} rtm authored')
        out = {'baseline_edits': base, 'edits': {}}
        for kind, e in x['edits'].items():
            got = read(e['patched'], f'{rid} rtm {kind}')
            v = self.ask(a.judge, ROUNDTRIP + '\n\nINTENDED:\n' + json.dumps(e['model_edits'], ensure_ascii=False) + '\n\nRECOVERED:\n' + json.dumps(got, ensure_ascii=False), f'{rid} rtm {kind} judge')
            out['edits'][kind] = {'intended': e['model_edits'], 'recovered_edits': got, 'recovered': bool(v.get('recovered')), 'other': int(v.get('other') or 0), 'why': v.get('why', '')}
        return rid, out

    def answer(self, item, base_model, case, verdict):
        """An author answers an open question: "Cases like <phrase> are <verdict>." appended to that field; the loop as for any edit;
        both judges re-read the case under the patched profile."""
        a, rid = self.a, item['id']
        auth = {l: part(item['gold'], l) for l in LABELS}
        rt = json.loads(self.nl(a.editor, {'model': base_model, 'p': item['packet'], 'profile': auth}, [LAB / 'lens-profile.nlir'], tag=f'{rid} rt'))
        m0 = apply(base_model, rt.get('edits', []))
        phrase = self.ask(a.editor, SUMMARISE + '\n\nCASE: ' + case, f'{rid} answer phrase {hash(case) % 10**8}')['phrase'].strip().rstrip('.')
        fld = verdict
        new = auth[fld].rstrip() + f' Cases like {phrase} are {verdict}.'
        back = json.loads(self.nl(a.editor, {'model': m0, 'p': item['packet'], 'part': fld, 'old': auth[fld], 'new': new}, [LAB / 'lens-concepts.nlir'], tag=f'{rid} answer {verdict} back {hash(case) % 10**8}'))
        t = json.loads(self.nl(a.editor, {'model': m0, 'after': m0, 'edits': back.get('edits', []), 'part': fld}, [LAB / 'patch-route.nlir', LAB / 'lens-typed.nlir'], expr='$json%{kept=$kept, dropped=$dropped}', tag=f'{rid} answer typed {verdict} {hash(case) % 10**8}'))
        m1 = apply(m0, t['kept']); edited = dict(auth); edited[fld] = new
        note = f'An author answered an open question: cases like {phrase} are {verdict}.'
        routing = json.loads(self.nl(a.editor, {'model': m0, 'after': m1}, [LAB / 'patch-route.nlir'], expr='$json%{changed=$changed, route=$route}', tag=f'{rid} answer route {verdict} {hash(case) % 10**8}'))
        patched = json.loads(self.nl(a.editor, {'model': m0, 'after': m1, 'profile': edited, 'note': note}, [LAB / 'patch-route.nlir', LAB / 'patch.nlir'], tag=f'{rid} answer patch {verdict} {hash(case) % 10**8}'))
        patched = {l: patched.get(l, edited[l]) for l in LABELS}
        read = lambda model, prof, tag: self.ask(model, VERDICT + '\n\nPROFILE:\n' + json.dumps(prof, ensure_ascii=False) + '\n\nCASE: ' + case, tag)
        h = hash(case) % 10**8
        return {'rule': rid, 'case': case, 'answer': verdict, 'phrase': phrase, 'author_edit': new, 'model_edits': t['kept'], 'warnings': t['dropped'], 'routing': routing,
                'authored': auth, 'patched': patched,
                'after': read(a.judge, patched, f'{rid} answer read1 {verdict} {h}'), 'after2': read(a.judge2, patched, f'{rid} answer read2 {verdict} {h}') if a.judge2 else {}}

    def consolidate(self, rid, x):
        """After a sequence of edits: one consolidation pass over the final profile (consolidate.nlir), then every edit judged again."""
        a = self.a
        edits = [f"{s_['kind']}: {s_['text']}" for s_ in x['steps']]
        prof = json.loads(self.nl(a.editor, {'authored': x['authored'], 'profile': x['final_profile'], 'edits': edits}, [LAB / 'consolidate.nlir'], tag=f'{rid} consolidate'))
        prof = {l: prof.get(l, x['final_profile'][l]) for l in LABELS}
        out = {}
        for s_ in x['steps']:
            k = s_['kind']
            out[k] = {'after': self.judge(a.judge, k, s_['text'], prof, f'{rid} cons {k} judge')}
            if a.judge2:
                out[k]['after2'] = self.judge(a.judge2, k, s_['text'], prof, f'{rid} cons {k} judge2')
        return rid, {'authored': x['authored'], 'final_profile': x['final_profile'], 'consolidated': prof, 'final': x['final'], 'consolidated_judged': out,
                     'steps': [{'kind': s_['kind'], 'text': s_['text']} for s_ in x['steps']]}

    def author_new(self, kind, cur, txt):
        fld = 'UNCERTAIN' if kind == 'fact' else 'MET'
        new = (cur['MET'].rstrip().rstrip('.') + (f', unless {txt}.' if kind == 'exception' else f', and only when {txt}.')) if fld == 'MET' else (cur['UNCERTAIN'].rstrip() + ' ' + txt[0].upper() + txt[1:] + ' can leave the verdict undecided when unclear.')
        return fld, new

    def sequence(self, item, base_model):
        """Do edits compose? Three author edits in turn — an exception, a requirement, a deciding fact — each applied to the
        previous step's patched profile and model; each judged right after its step, and all three on the final profile."""
        a, rid = self.a, item['id']
        auth = {l: part(item['gold'], l) for l in LABELS}
        rt = json.loads(self.nl(a.editor, {'model': base_model, 'p': item['packet'], 'profile': auth}, [LAB / 'lens-profile.nlir'], tag=f'{rid} rt'))
        model = apply(base_model, rt.get('edits', []))
        prop = self.ask(a.editor, PROPOSE + '\n\nPACKET:\n' + json.dumps(item['packet'], ensure_ascii=False) + '\n\nPROFILE:\n' + json.dumps(auth, ensure_ascii=False), f'{rid} propose')
        cur, steps = dict(auth), []
        for kind in ('exception', 'requirement', 'fact'):
            txt = str(prop[kind]).strip().rstrip('.')
            fld, new = self.author_new(kind, cur, txt)
            back = json.loads(self.nl(a.editor, {'model': model, 'p': item['packet'], 'part': fld, 'old': cur[fld], 'new': new}, [LAB / 'lens-concepts.nlir'], tag=f'{rid} seq {kind} back'))
            t = json.loads(self.nl(a.editor, {'model': model, 'after': model, 'edits': back.get('edits', []), 'part': fld}, [LAB / 'patch-route.nlir', LAB / 'lens-typed.nlir'],
                                   expr='$json%{kept=$kept, dropped=$dropped}', tag=f'{rid} seq {kind} typed'))
            t['kept'], t['dropped'], _ = self.retry_declined(model, item, fld, cur[fld], new, t['kept'], t['dropped'], f'{rid} seq {kind}')
            after_model = apply(model, t['kept'])
            edited = dict(cur); edited[fld] = new
            note = {'exception': 'An author edited MET to add the exception: ', 'requirement': 'An author edited MET to add the requirement for a violation: ', 'fact': 'An author edited UNCERTAIN to add the deciding fact: '}[kind] + txt
            routing = json.loads(self.nl(a.editor, {'model': model, 'after': after_model}, [LAB / 'patch-route.nlir'], expr='$json%{changed=$changed, route=$route}', tag=f'{rid} seq {kind} route'))
            patched = json.loads(self.nl(a.editor, {'model': model, 'after': after_model, 'profile': edited, 'note': note}, [LAB / 'patch-route.nlir', LAB / 'patch.nlir'], tag=f'{rid} seq {kind} patch'))
            patched = {l: patched.get(l, edited[l]) for l in LABELS}
            steps.append({'kind': kind, 'text': txt, 'part': fld, 'author_edit': new, 'model_edits': t['kept'], 'warnings': t['dropped'], 'routing': routing, 'profile': patched,
                          'at_step': self.judge(a.judge, kind, txt, patched, f'{rid} seq {kind} judge at step')})
            cur, model = patched, after_model
        final = {}
        for s_ in steps:
            k = s_['kind']
            final[k] = {'before': self.judge(a.judge, k, s_['text'], auth, f'{rid} {k} judge before'), 'after': self.judge(a.judge, k, s_['text'], cur, f'{rid} seq {k} judge final')}
            if a.judge2:
                final[k] |= {'before2': self.judge(a.judge2, k, s_['text'], auth, f'{rid} {k} judge2 before'), 'after2': self.judge(a.judge2, k, s_['text'], cur, f'{rid} seq {k} judge2 final')}
        return rid, {'title': item['packet'].get('title', ''), 'authored': auth, 'm0': rt.get('edits', []), 'proposals': prop, 'steps': steps, 'final_profile': cur, 'final': final}

    def reads(self):
        """The concept layer's dependencies, from patch-route.nlir itself (one source of truth)."""
        if not hasattr(self, '_reads'):
            out = self.nl(self.a.editor, {'model': {}, 'after': {}}, [LAB / 'patch-route.nlir'], expr='$json%$reads', tag='reads')
            self._reads = {f: set(g) for f, g in json.loads(out)}
        return self._reads

    def ask(self, model, q, tag):
        return json.loads(self.nl(model, {'q': {'q': q}}, expr='$json%($parse%(=>($q.q)))', tag=tag))

    def retry_declined(self, model, item, fld, old, new, kept, dropped, tag):
        """--retry-declined: when the typed pass declines every node edit of an author's sentence, nothing would reach the profile; ask the
        backward pass once more, saying what it read and what the edited field can change."""
        if kept or not dropped or not self.a.retry_declined:
            return kept, dropped, None
        groups = sorted({d_.get('group', '?') for d_ in dropped})
        hint = (f'A previous reading of this edit changed only the {", ".join(groups)} group(s), which {fld} does not read, so it was declined and nothing reached the '
                f'profile. An edit to {fld} can change only {READS.get(fld, "the groups it reads")}. Read the author\'s change again in those terms.')
        back = json.loads(self.nl(self.a.editor, {'model': model, 'p': item['packet'], 'part': fld, 'old': old, 'new': new, 'hint': hint}, [LAB / 'lens-concepts.nlir'], tag=f'{tag} retry'))
        t = json.loads(self.nl(self.a.editor, {'model': model, 'after': model, 'edits': back.get('edits', []), 'part': fld}, [LAB / 'patch-route.nlir', LAB / 'lens-typed.nlir'],
                               expr='$json%{kept=$kept, dropped=$dropped}', tag=f'{tag} retry typed'))
        return t['kept'], t['dropped'], {'first_dropped': dropped, 'hint': hint}

    def judge(self, model, kind, text, prof, tag):
        return self.ask(model, JUDGES[kind] + f"\n\n{NAME[kind]}: {text}\n\nMET: {prof['MET']}\n\nNOT MET: {prof['NOT MET']}\n\nUNCERTAIN: {prof['UNCERTAIN']}", tag)

    def rule(self, item, base_model):
        a, rid = self.a, item['id']
        auth = {l: part(item['gold'], l) for l in LABELS}
        rt = json.loads(self.nl(a.editor, {'model': base_model, 'p': item['packet'], 'profile': auth}, [LAB / 'lens-profile.nlir'], tag=f'{rid} rt'))
        m0 = apply(base_model, rt.get('edits', []))
        m0 = ANCHORS.get(rid, m0)  # --anchor: start from the rule's settled model (a fixed point of the authored profile)
        prop = self.ask(a.editor, PROPOSE + '\n\nPACKET:\n' + json.dumps(item['packet'], ensure_ascii=False) + '\n\nPROFILE:\n' + json.dumps(auth, ensure_ascii=False), f'{rid} propose')
        out = {'title': item['packet'].get('title', ''), 'authored': auth, 'm0': m0, 'proposals': prop, 'edits': {}, 'anchored': rid in ANCHORS}
        for kind in (('exception', 'requirement') if a.source == 'packet' else a.kinds):
            if kind == 'removal':
                out['edits'][kind] = self.removal(item, auth, m0)
                continue
            txt = str(prop[kind]).strip().rstrip('.')
            if a.source == 'packet':
                out['edits'][kind] = self.packet_edit(item, auth, m0, kind, txt)
                continue
            fld = 'UNCERTAIN' if kind == 'fact' else 'MET'
            new = (auth['MET'].rstrip().rstrip('.') + (f', unless {txt}.' if kind == 'exception' else f', and only when {txt}.')) if fld == 'MET' else (auth['UNCERTAIN'].rstrip() + ' ' + txt[0].upper() + txt[1:] + ' can leave the verdict undecided when unclear.')
            back = json.loads(self.nl(a.editor, {'model': m0, 'p': item['packet'], 'part': fld, 'old': auth[fld], 'new': new}, [LAB / 'lens-concepts.nlir'], tag=f'{rid} {kind} back'))
            # Typed backward (lens-typed.nlir): an edited field can only change the model groups it reads; node edits
            # elsewhere are not applied but kept as warnings for the author.
            kept, dropped, retried = back.get('edits', []), [], None
            if a.typed:
                t = json.loads(self.nl(a.editor, {'model': m0, 'after': m0, 'edits': back.get('edits', []), 'part': fld}, [LAB / 'patch-route.nlir', LAB / 'lens-typed.nlir'],
                                       expr='$json%{kept=$kept, dropped=$dropped}', tag=f'{rid} {kind} typed'))
                kept, dropped = t['kept'], t['dropped']
                kept, dropped, retried = self.retry_declined(m0, item, fld, auth[fld], new, kept, dropped, f'{rid} {kind}')
            m1 = apply(m0, kept)
            edited = dict(auth); edited[fld] = new
            note = {'exception': 'An author edited MET to add the exception: ', 'requirement': 'An author edited MET to add the requirement for a violation: ', 'fact': 'An author edited UNCERTAIN to add the deciding fact: '}[kind] + txt
            routing = self.nl(a.editor, {'model': m0, 'after': m1}, [LAB / 'patch-route.nlir'], expr='$json%{changed=$changed, route=$route}', tag=f'{rid} {kind} route')
            patched = json.loads(self.nl(a.editor, {'model': m0, 'after': m1, 'profile': edited, 'note': note}, [LAB / 'patch-route.nlir', LAB / 'patch.nlir'], tag=f'{rid} {kind} patch'))
            # A field the route does not reach keeps the author's text, including the edited field itself when the model edit
            # landed elsewhere (then the author's sentence stands as written).
            patched = {l: patched.get(l, edited[l]) for l in LABELS}
            e = {'text': txt, 'part': fld, 'author_edit': new, 'model_edits': kept, 'warnings': dropped, 'routing': json.loads(routing), 'patched': patched,
                 'before': self.judge(a.judge, kind, txt, auth, f'{rid} {kind} judge before'), 'after': self.judge(a.judge, kind, txt, patched, f'{rid} {kind} judge after')}
            if retried:
                e['retried'] = retried
            if a.judge2:
                e['before2'] = self.judge(a.judge2, kind, txt, auth, f'{rid} {kind} judge2 before'); e['after2'] = self.judge(a.judge2, kind, txt, patched, f'{rid} {kind} judge2 after')
            out['edits'][kind] = e
        return rid, out


def summary_repair(results):
    import difflib
    tok = lambda s: re.findall(r'\S+', s)
    R_ = [x for x in results.values() if x.get('repaired')]
    flag = lambda d, k: bool((d or {}).get(k))
    pairs = [(x['authored'][l], x['profile'][l]) for x in R_ for l in LABELS]
    return {'rules': len(results), 'flagged': len(R_),
            'check': {k: {'before': sum(flag(x['check_before'], k) for x in results.values()), 'after': sum(flag(x.get('check_after', x['check_before']), k) for x in results.values())} for k in ('overlap', 'gap')},
            'independent': {k: {'before': sum(flag(x['indep_before'], k) for x in results.values()), 'after': sum(flag(x.get('indep_after', x['indep_before']), k) for x in results.values())} for k in ('overlap', 'gap')},
            'collateral': sum(flag(x.get('collateral'), 'collateral') for x in R_),
            'similarity': round(sum(difflib.SequenceMatcher(a=tok(a), b=tok(b), autojunk=False).ratio() for a, b in pairs) / max(1, len(pairs)), 3),
            'untouched': sum(a.strip() == b.strip() for a, b in pairs), 'fields': len(pairs),
            'words_added_per_repair': round(sum(sum(j2 - j1 for op, i1, i2, j1, j2 in difflib.SequenceMatcher(a=tok(a), b=tok(b), autojunk=False).get_opcodes() if op in ('insert', 'replace')) for a, b in pairs) / max(1, len(R_)), 1)}


def summary_undo(results, judge2):
    V = [x for x in results.values() if not x.get('invalid')]
    c = lambda key, q: sum(bool(x.get(key, {}).get(q)) for x in V)
    S = {'rules': len(results), 'valid': len(V), 'added_node': sum(x['added_node'] for x in V), 'removed_node': sum(x['removed_node'] for x in V),
         'after_add': {'not_met_covers': c('after_add', 'not_met_covers'), 'met_excludes': c('after_add', 'met_excludes')},
         'after_undo': {'met_covers': c('after_undo', 'met_covers'), 'not_met_drops': c('after_undo', 'not_met_drops'), 'overlap': c('after_undo', 'overlap')},
         'final_similarity_to_authored': round(sum(x['final_similarity_to_authored'] for x in V) / max(1, len(V)), 3), 'final_untouched': sum(x['final_untouched'] for x in V), 'fields': 5 * len(V)}
    if judge2:
        S['after_add2'] = {'not_met_covers': c('after_add2', 'not_met_covers'), 'met_excludes': c('after_add2', 'met_excludes')}
        S['after_undo2'] = {'met_covers': c('after_undo2', 'met_covers'), 'not_met_drops': c('after_undo2', 'not_met_drops'), 'overlap': c('after_undo2', 'overlap')}
    return S


def summary_session(results, judge2):
    """--session: every change checked on the final profile, per judge."""
    rs = list(results.values()); S = {'rules': len(rs), 'undone_located': sum(x['undone'] for x in rs)}
    for w in ('', '2') if judge2 else ('',):
        f = lambda x, k: x['final'].get(k + w) or {}
        S['judge' + (w or '1')] = {
            'requirement_holds': sum(bool(f(x, 'requirement').get('met_requires') and f(x, 'requirement').get('not_met_covers')) for x in rs),
            'fact_named': sum(bool(f(x, 'fact').get('uncertain_names')) for x in rs),
            'exception_undone': sum(bool(f(x, 'removal').get('met_covers') and f(x, 'removal').get('not_met_drops')) for x in rs),
            'overlaps_final': sum(bool(f(x, 'consist').get('overlap')) for x in rs), 'overlaps_authored': sum(bool(f(x, 'consist_authored').get('overlap')) for x in rs)}
    S['untouched'] = {l: sum(x['authored'][l].strip() == x['final_profile'][l].strip() for x in rs) for l in ('APPLICABILITY', 'DECISION BOUNDARY')}
    return S


def summary_sequence(results, judge2):
    import difflib
    tok = lambda s: re.findall(r'\S+', s)
    S = {}
    for kind, qs in QUESTIONS.items():
        if not all(kind in [s['kind'] for s in x['steps']] for x in results.values()):
            continue  # a kind the sequence did not include (removal is not a step of --sequence)
        rows = [(x['steps'][[s['kind'] for s in x['steps']].index(kind)], x['final'][kind]) for x in results.values()]
        S[kind] = {q: {'at_step': sum(bool(st['at_step'].get(q)) for st, _ in rows), 'final': sum(bool(f['after'].get(q)) for _, f in rows),
                       'before': sum(bool(f['before'].get(q)) for _, f in rows)} | ({'final2': sum(bool(f['after2'].get(q)) for _, f in rows), 'before2': sum(bool(f['before2'].get(q)) for _, f in rows)} if judge2 else {}) for q in qs}
    pairs = [(x['authored'][l], x['final_profile'][l]) for x in results.values() for l in LABELS]
    S['final_profile'] = {'similarity': round(sum(difflib.SequenceMatcher(a=tok(a), b=tok(b), autojunk=False).ratio() for a, b in pairs) / len(pairs), 3),
                          'untouched': sum(a.strip() == b.strip() for a, b in pairs), 'fields': len(pairs),
                          'words_added_per_rule': round(sum(sum(j2 - j1 for op, i1, i2, j1, j2 in difflib.SequenceMatcher(a=tok(a), b=tok(b), autojunk=False).get_opcodes() if op in ('insert', 'replace')) for a, b in pairs) / len(results), 1),
                          'warnings': sum(len(s['warnings']) for x in results.values() for s in x['steps'])}
    return S


def summary(results, judge2):
    tok = lambda s: re.findall(r'\S+', s)
    import difflib
    S = {}
    for kind, qs in QUESTIONS.items():
        if not all(kind in x['edits'] for x in results.values()):
            continue
        E = [x['edits'][kind] | {'authored': x['authored']} for x in results.values() if not x['edits'][kind].get('invalid')]
        if not E:
            continue
        others = [(e['authored'][l], e['patched'][l]) for e in E for l in LABELS if l != e['part']]
        S[kind] = {q: {w: sum(bool(e[w].get(q)) for e in E) for w in (('before', 'after') + (('before2', 'after2') if judge2 else ()))} for q in qs} | {
            'rules': len(E), 'other_similarity': round(sum(difflib.SequenceMatcher(a=tok(x), b=tok(y), autojunk=False).ratio() for x, y in others) / len(others), 3),
            'other_unchanged': sum(x.strip() == y.strip() for x, y in others), 'other_fields': len(others),
            'routed_fields': round(sum(len(e['routing']['route']) for e in E) / len(E), 2), 'warnings': sum(bool(e.get('warnings')) for e in E),
            'invalid': sum(bool(x['edits'][kind].get('invalid')) for x in results.values())}
        if kind == 'removal':
            S[kind]['removed_permission'] = sum(any(m.get('op') == 'remove' and m.get('group') == 'permissions' for m in e['model_edits']) for e in E)
            S[kind]['invalid_reasons'] = sorted({x['edits'][kind].get('reason', '') for x in results.values() if x['edits'][kind].get('invalid')})
        if E and E[0].get('provenance'):
            S[kind]['provenance'] = {'nodes': sum(e['provenance']['nodes'] for e in E), 'quote_new_passage': sum(e['provenance']['quote_new_passage'] for e in E)}
            S[kind]['unrouted_unchanged'] = sum(e['authored'][l].strip() == e['patched'][l].strip() for e in E for l in LABELS if l not in e['routing']['route'])
        if kind == 'fact':
            S[kind]['verdict_untouched'] = sum(e['authored']['MET'].strip() == e['patched']['MET'].strip() and e['authored']['NOT MET'].strip() == e['patched']['NOT MET'].strip() for e in E)
    return S


def main():
    ap = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    ap.add_argument('--data', required=True); ap.add_argument('--models', required=True); ap.add_argument('--out', required=True)
    ap.add_argument('--rules', nargs='*'); ap.add_argument('--rules-file', help='one rule id per line (ids may contain spaces)'); ap.add_argument('--config'); ap.add_argument('--cache', default='target/edit-loop-cache.jsonl')
    ap.add_argument('--editor', default='sol'); ap.add_argument('--judge', default='sol'); ap.add_argument('--judge2'); ap.add_argument('--workers', type=int, default=3)
    ap.add_argument('--seed-base', type=int, default=0, help='first seed for every model call (retries use the next two); another base draws an independent sample')
    ap.add_argument('--kinds', nargs='*', default=['exception', 'requirement', 'fact'], help='author edits to run: exception, requirement, fact, removal')
    ap.add_argument('--impact', help='comma-separated definition ids: change each, and check which rules it reaches (impact.nlir) against two judges')
    ap.add_argument('--impact-apply', help='a recorded --impact run: patch the rules its first judge selected for each changed definition, then ask the judges again')
    ap.add_argument('--impact-models', help='with --impact: comma-separated recorded runs whose m0 models to use')
    ap.add_argument('--conflicts', help='a recorded author run: write a requirement contradicting each exception and check merge-check.nlir flags it (and not the recorded, compatible requirement)')
    ap.add_argument('--session', action='store_true', help='a maintenance session per rule: author exception, specification requirement, author fact, undo the exception; all checked at the end')
    ap.add_argument('--retry-declined', action='store_true', help='typed: when every node edit of an author sentence is declined, ask the backward pass once more')
    ap.add_argument('--merge', help='a recorded author run: merge its exception and requirement edits, made independently, through the model; judge both')
    ap.add_argument('--anchor', help='a --fixpoint run: with --roundtrip, read back from its fixed points; otherwise maintain from them instead of m0')
    ap.add_argument('--fixpoint', help='a recorded author run: iterate the backward pass on each authored profile from m0 until it proposes nothing (is the lens idempotent?)')
    ap.add_argument('--roundtrip', help='a recorded author run: read every patched profile back into the model (lens-profile.nlir from m0) and check the intended edit is recovered')
    ap.add_argument('--consolidate', help='a recorded --sequence run: consolidate each final profile (consolidate.nlir) and judge every edit again')
    ap.add_argument('--questions', help='an open-questions file (rows with rule, case, open): answer each open case both ways and check it is settled')
    ap.add_argument('--convention', help='append this sentence to every authored DECISION BOUNDARY and check overlaps and gaps before and after')
    ap.add_argument('--narrow', action='store_true', help='with --repair: move only cases like the flagged one (fewer neighbours moved, more words)')
    ap.add_argument('--repair', action='store_true', help='check each authored profile and repair an overlap or gap with the smallest edit')
    ap.add_argument('--undo', action='store_true', help='add an exception, then delete it again: does the profile come back?')
    ap.add_argument('--sequence', action='store_true', help='apply an exception, a requirement and a deciding fact in turn to the same profile (do edits compose?)')
    ap.add_argument('--source', choices=('author', 'packet'), default='author', help='where the change starts: an author\'s sentence, or the rule\'s packet')
    ap.add_argument('--typed', action='store_true', help='keep only backward node edits in groups the edited field reads; the rest become warnings')
    ap.add_argument('--default-route', nargs='*', default=['opus'], help='models called without --config (their own nlir route)')
    a = ap.parse_args()
    data = {d['id']: d for d in json.loads(Path(a.data).read_text())}
    M = json.loads(Path(a.models).read_text()); M = {r: x['model'] for r, x in M['results'].items()} if 'results' in M else M
    rules = a.rules or ([l.strip() for l in Path(a.rules_file).read_text().splitlines() if l.strip()] if a.rules_file else sorted(M))
    R = Runner(a)
    if a.impact_apply:  # patch the rules the one-call check selected for each changed definition, and ask again
        IMP = json.loads(Path(a.impact_apply).read_text())
        MD = {}
        for f in a.impact_models.split(','):
            MD.update({k: v['m0'] for k, v in json.loads(Path(f).read_text())['results'].items() if 'm0' in v})
        ALL = {d['id']: d for d in json.loads(Path(a.data).read_text())}
        sel = [r for r in IMP['rows'] if (r.get('judge') or {}).get('needs_change')]
        with ThreadPoolExecutor(a.workers) as ex:
            rows = list(ex.map(lambda r: R.impact_apply(ALL[r['rule']], MD[r['rule']], r['definition'], IMP['changes'][r['definition']]), sel))
        import difflib
        tok = lambda t_: re.findall(r'\S+', t_)
        no = lambda r, w: not bool((r.get(w) or {}).get('needs_change'))
        routed = lambda r: set(r['routing'].get('route', []))
        others = [(r['authored'][l], r['patched'][l]) for r in rows for l in LABELS if l not in routed(r)]
        S = {'selected': len(rows), 'settled_judge': sum(no(r, 'after') for r in rows), 'settled_judge2': sum(no(r, 'after2') for r in rows) if a.judge2 else None,
             'settled_both': sum(no(r, 'after') and (no(r, 'after2') if a.judge2 else True) for r in rows),
             'no_model_edit': sum(not r['model_edits'] for r in rows), 'unrouted_untouched': f"{sum(x.strip() == y.strip() for x, y in others)} of {len(others)}",
             'kept_all': round(sum(difflib.SequenceMatcher(a=tok(r['authored'][l]), b=tok(r['patched'][l]), autojunk=False).ratio() for r in rows for l in LABELS) / max(1, 5 * len(rows)), 3)}
        Path(a.out).write_text(json.dumps({'summary': S, 'rows': rows, 'models': {'editor': a.editor, 'judge': a.judge, 'judge2': a.judge2}, 'impact_apply': True}, indent=1, ensure_ascii=False) + '\n')
        print(json.dumps(S, indent=1)); return
    if a.impact:  # which rules does a definition change touch? deterministic routes against two judges
        MD = {}
        for f in a.impact_models.split(','):
            MD.update({k: v['m0'] for k, v in json.loads(Path(f).read_text())['results'].items() if 'm0' in v})
        ALL = {d['id']: d for d in json.loads(Path(a.data).read_text())}
        dids = a.impact.split(',')
        DEF = {}
        for d in ALL.values():
            for df in d['packet'].get('definitions', []):
                DEF.setdefault(df['id'], df)
        with ThreadPoolExecutor(a.workers) as ex:
            NEW = dict(ex.map(lambda did: R.impact_change(did, DEF[did]), dids))
        jobs = [(ALL[r], MD[r], did) for did in dids for r in sorted(ALL) if r in MD and any(df['id'] == did for df in ALL[r]['packet'].get('definitions', []))]
        with ThreadPoolExecutor(a.workers) as ex:
            rows = list(ex.map(lambda j: R.impact(j[0], j[1], j[2], DEF[j[2]], NEW[j[2]]), jobs))
        need = lambda r, w: bool((r.get(w) or {}).get('needs_change'))
        S = {'definitions': len(dids), 'exposed_pairs': len(rows)}
        for w in ('judge', 'judge2'):
            if not all(w in r for r in rows): continue
            pos = [r for r in rows if need(r, w)]
            S[w] = {'needs_change': len(pos)}
            for route, sel in (('exposure', lambda r: True), ('term', lambda r: bool(r['routes'].get('term'))), ('quoted', lambda r: bool(r['routes'].get('quoted'))),
                               ('term_or_quoted', lambda r: bool(r['routes'].get('term') or r['routes'].get('quoted')))):
                chosen = [r for r in rows if sel(r)]; tp = sum(need(r, w) for r in chosen)
                S[w][route] = {'routed': len(chosen), 'precision': round(tp / max(1, len(chosen)), 3), 'recall': round(tp / max(1, len(pos)), 3)}
        Path(a.out).write_text(json.dumps({'summary': S, 'changes': NEW, 'rows': rows, 'models': {'editor': a.editor, 'judge': a.judge, 'judge2': a.judge2}, 'impact': True}, indent=1, ensure_ascii=False) + '\n')
        print(json.dumps(S, indent=1)); return
    if a.conflicts:  # does the merge check flag a real contradiction, and leave compatible edits alone?
        FIN = json.loads(Path(a.conflicts).read_text())['results']
        with ThreadPoolExecutor(a.workers) as ex:
            res = dict(ex.map(lambda kv: R.conflicts(data[kv[0]], kv[1]), [(k, v) for k, v in FIN.items() if k in data]))
        S = {'rules': len(res), 'conflicts_detected': sum(bool(x['conflict_pair'].get('conflict')) for x in res.values()),
             'compatible_flagged': sum(bool(x['compatible_pair'].get('conflict')) for x in res.values()),
             'contradicting_without_model_edit': sum(not x['contradicting_edits'] for x in res.values())}
        Path(a.out).write_text(json.dumps({'summary': S, 'results': res, 'models': {'editor': a.editor, 'judge': a.judge}, 'conflicts': True}, indent=1, ensure_ascii=False) + '\n')
        print(json.dumps(S, indent=1)); return
    if a.merge:  # merge the exception and requirement edits of a recorded author run through the model
        FIN = json.loads(Path(a.merge).read_text())['results']
        with ThreadPoolExecutor(a.workers) as ex:
            res = dict(ex.map(lambda kv: R.merge(data[kv[0]], kv[1]), [(k, v) for k, v in FIN.items() if k in data]))
        S = {}
        for k in ('exception', 'requirement'):
            S[k] = {q: {w: {'merged': sum(bool(x['judged'][k].get(w, {}).get(q)) for x in res.values()), 'single': sum(bool((x['single'][k].get(w) or {}).get(q)) for x in res.values())}
                        for w in ('after', 'after2') if all(w in x['judged'][k] for x in res.values())} for q in QUESTIONS[k]}
        import difflib
        tok = lambda t_: re.findall(r'\S+', t_)
        routed = lambda x: set(x['routing'].get('route', []))
        others = [(x['authored'][l], x['merged'][l]) for x in res.values() for l in LABELS if l not in routed(x)]
        S['text_merge'] = {'rules_with_conflict': sum(any(v['conflicts'] for v in x['text_merge'].values()) for x in res.values()),
                           'fields_conflicted': sum(bool(v['conflicts']) for x in res.values() for v in x['text_merge'].values())}
        S['profile'] = {'rules': len(res), 'unrouted_untouched': sum(a_.strip() == b.strip() for a_, b in others), 'unrouted_fields': len(others),
                        'similarity_all': round(sum(difflib.SequenceMatcher(a=tok(x['authored'][l]), b=tok(x['merged'][l]), autojunk=False).ratio() for x in res.values() for l in LABELS) / (5 * len(res)), 3)}
        Path(a.out).write_text(json.dumps({'summary': S, 'results': res, 'models': {'editor': a.editor, 'judge': a.judge, 'judge2': a.judge2}, 'merge': True}, indent=1, ensure_ascii=False) + '\n')
        print(json.dumps(S, indent=1)); return
    if a.anchor and not a.roundtrip:  # maintain from settled models
        ANCHORS.update({k: v['fixpoint'] for k, v in json.loads(Path(a.anchor).read_text())['results'].items()})
    if a.fixpoint:  # iterate the backward pass on the authored profile from m0 until it proposes nothing
        FIN = json.loads(Path(a.fixpoint).read_text())['results']
        with ThreadPoolExecutor(a.workers) as ex:
            res = dict(ex.map(lambda kv: R.fixpoint(data[kv[0]], kv[1]), [(k, v) for k, v in FIN.items() if k in data]))
        S = {'rules': len(res), 'reached': sum(x['reached'] for x in res.values()),
             'edits_per_round': [round(sum(len(x['rounds'][i]) if i < len(x['rounds']) else 0 for x in res.values()) / len(res), 2) for i in range(3)],
             'clean_per_round': [sum((i < len(x['rounds']) and not x['rounds'][i]) or i >= len(x['rounds']) for x in res.values()) for i in range(3)]}
        Path(a.out).write_text(json.dumps({'summary': S, 'results': res, 'models': {'editor': a.editor}, 'fixpoint': True}, indent=1, ensure_ascii=False) + '\n')
        print(json.dumps(S, indent=1)); return
    if a.roundtrip:  # read every patched profile of a recorded author run back into the model
        FIN = json.loads(Path(a.roundtrip).read_text())['results']
        if a.anchor:  # read back from each rule's fixed point (a --fixpoint run) instead of m0
            FX = json.loads(Path(a.anchor).read_text())['results']
            FIN = {k: dict(v, anchor=FX[k]['fixpoint']) for k, v in FIN.items() if k in FX}
        with ThreadPoolExecutor(a.workers) as ex:
            res = dict(ex.map(lambda kv: R.roundtrip(data[kv[0]], kv[1]), [(k, v) for k, v in FIN.items() if k in data]))
        kinds = sorted({k for x in res.values() for k in x['edits']})
        S = {k: {'n': sum(k in x['edits'] for x in res.values()), 'recovered': sum(x['edits'][k]['recovered'] for x in res.values() if k in x['edits']),
                 'other_per_profile': round(sum(x['edits'][k]['other'] for x in res.values() if k in x['edits']) / max(1, sum(k in x['edits'] for x in res.values())), 2),
                 'recovered_edits_per_profile': round(sum(len(x['edits'][k]['recovered_edits']) for x in res.values() if k in x['edits']) / max(1, sum(k in x['edits'] for x in res.values())), 2)} for k in kinds}
        S['authored_baseline'] = {'rules': len(res), 'edits_per_profile': round(sum(len(x['baseline_edits']) for x in res.values()) / max(1, len(res)), 2),
                                  'profiles_with_none': sum(not x['baseline_edits'] for x in res.values())}
        Path(a.out).write_text(json.dumps({'summary': S, 'results': res, 'models': {'editor': a.editor, 'judge': a.judge}, 'roundtrip': True}, indent=1, ensure_ascii=False) + '\n')
        print(json.dumps(S, indent=1)); return
    if a.consolidate:  # consolidate the final profiles of a recorded --sequence run, then judge every edit again
        SQ = json.loads(Path(a.consolidate).read_text())['results']
        with ThreadPoolExecutor(a.workers) as ex:
            res = dict(ex.map(lambda kv: R.consolidate(*kv), [(k, v) for k, v in SQ.items() if k in data]))
        import difflib
        tok = lambda t_: re.findall(r'\S+', t_)
        sents = lambda t_: [x_.strip() for x_ in re.split(r'(?<=[.!?])\s+', t_ or '') if x_.strip()]
        S = {}
        for kind, qs in QUESTIONS.items():
            if not all(kind in x['final'] for x in res.values()): continue
            S[kind] = {q: {w: {'final': sum(bool(x['final'][kind].get(w, {}).get(q)) for x in res.values()), 'consolidated': sum(bool(x['consolidated_judged'][kind].get(w, {}).get(q)) for x in res.values())}
                           for w in ('after', 'after2') if all(w in x['final'][kind] for x in res.values())} for q in qs}
        def prof_stats(key):
            pairs = [(x['authored'][l], x[key][l]) for x in res.values() for l in LABELS]
            kept_sent = [sum(s_ in b for s_ in sents(a_)) / max(1, len(sents(a_))) for a_, b in pairs if a_.strip()]
            return {'words_per_rule': round(sum(len(tok(x[key][l])) for x in res.values() for l in LABELS) / len(res), 1),
                    'similarity': round(sum(difflib.SequenceMatcher(a=tok(a_), b=tok(b), autojunk=False).ratio() for a_, b in pairs) / len(pairs), 3),
                    'authored_sentences_kept': round(sum(kept_sent) / len(kept_sent), 3)}
        S['profile'] = {'authored_words_per_rule': round(sum(len(tok(x['authored'][l])) for x in res.values() for l in LABELS) / len(res), 1),
                        'final': prof_stats('final_profile'), 'consolidated': prof_stats('consolidated')}
        Path(a.out).write_text(json.dumps({'summary': S, 'results': res, 'models': {'editor': a.editor, 'judge': a.judge, 'judge2': a.judge2}, 'consolidate': True}, indent=1, ensure_ascii=False) + '\n')
        print(json.dumps(S, indent=1)); return
    if a.questions:  # answer every open question both ways
        Qs = [q for q in json.loads(Path(a.questions).read_text())['rows'] if q.get('open') and q['rule'] in data and q['rule'] in M]
        jobs = [(q, v) for q in Qs for v in ('MET', 'NOT MET')]
        with ThreadPoolExecutor(a.workers) as ex:
            rows = list(ex.map(lambda j: R.answer(data[j[0]['rule']], M[j[0]['rule']], j[0]['case'], j[1]), jobs))
        import difflib
        tok = lambda t_: re.findall(r'\S+', t_)
        settled = lambda r, k: str((r.get(k) or {}).get('verdict', '')).upper().strip() == r['answer']
        others = [(r['authored'][l], r['patched'][l]) for r in rows for l in LABELS if l != r['answer']]
        S = {'questions': len(Qs), 'answers': len(rows), 'settled_judge1': sum(settled(r, 'after') for r in rows), 'settled_judge2': sum(settled(r, 'after2') for r in rows),
             'settled_both': sum(settled(r, 'after') and settled(r, 'after2') for r in rows),
             'by_answer': {v: {'n': sum(r['answer'] == v for r in rows), 'both': sum(r['answer'] == v and settled(r, 'after') and settled(r, 'after2') for r in rows)} for v in ('MET', 'NOT MET')},
             'other_similarity': round(sum(difflib.SequenceMatcher(a=tok(x), b=tok(y), autojunk=False).ratio() for x, y in others) / max(1, len(others)), 3), 'warnings': sum(bool(r['warnings']) for r in rows)}
        Path(a.out).write_text(json.dumps({'summary': S, 'rows': rows, 'models': {'editor': a.editor, 'judge': a.judge, 'judge2': a.judge2}, 'answers': True}, indent=1, ensure_ascii=False) + '\n')
        print(json.dumps(S, indent=1)); return
    with ThreadPoolExecutor(a.workers) as ex:
        res = dict(ex.map(lambda r: (R.session if a.session else R.convention if a.convention else R.repair if a.repair else R.undo if a.undo else R.sequence if a.sequence else R.rule)(data[r], M[r]), rules))
    S = summary_session(res, a.judge2) if a.session else summary_repair(res) if (a.repair or a.convention) else summary_undo(res, a.judge2) if a.undo else summary_sequence(res, a.judge2) if a.sequence else summary(res, a.judge2)
    Path(a.out).write_text(json.dumps({'summary': S, 'results': res, 'models': {'editor': a.editor, 'judge': a.judge, 'judge2': a.judge2}, 'typed': a.typed, 'source': a.source, 'sequence': a.sequence, 'undo': a.undo, 'repair': a.repair, 'narrow': a.narrow, 'seed_base': a.seed_base, 'convention': a.convention}, indent=1, ensure_ascii=False) + '\n')
    print(json.dumps(S, indent=1))


if __name__ == '__main__':
    main()
