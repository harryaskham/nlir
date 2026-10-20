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

    def judge(self, model, kind, text, prof, tag):
        return self.ask(model, JUDGES[kind] + f"\n\n{NAME[kind]}: {text}\n\nMET: {prof['MET']}\n\nNOT MET: {prof['NOT MET']}\n\nUNCERTAIN: {prof['UNCERTAIN']}", tag)

    def rule(self, item, base_model):
        a, rid = self.a, item['id']
        auth = {l: part(item['gold'], l) for l in LABELS}
        rt = json.loads(self.nl(a.editor, {'model': base_model, 'p': item['packet'], 'profile': auth}, [LAB / 'lens-profile.nlir'], tag=f'{rid} rt'))
        m0 = apply(base_model, rt.get('edits', []))
        prop = self.ask(a.editor, PROPOSE + '\n\nPACKET:\n' + json.dumps(item['packet'], ensure_ascii=False) + '\n\nPROFILE:\n' + json.dumps(auth, ensure_ascii=False), f'{rid} propose')
        out = {'title': item['packet'].get('title', ''), 'authored': auth, 'm0': m0, 'proposals': prop, 'edits': {}}
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
            kept, dropped = back.get('edits', []), []
            if a.typed:
                t = json.loads(self.nl(a.editor, {'model': m0, 'after': m0, 'edits': back.get('edits', []), 'part': fld}, [LAB / 'patch-route.nlir', LAB / 'lens-typed.nlir'],
                                       expr='$json%{kept=$kept, dropped=$dropped}', tag=f'{rid} {kind} typed'))
                kept, dropped = t['kept'], t['dropped']
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
        res = dict(ex.map(lambda r: (R.convention if a.convention else R.repair if a.repair else R.undo if a.undo else R.sequence if a.sequence else R.rule)(data[r], M[r]), rules))
    S = summary_repair(res) if (a.repair or a.convention) else summary_undo(res, a.judge2) if a.undo else summary_sequence(res, a.judge2) if a.sequence else summary(res, a.judge2)
    Path(a.out).write_text(json.dumps({'summary': S, 'results': res, 'models': {'editor': a.editor, 'judge': a.judge, 'judge2': a.judge2}, 'typed': a.typed, 'source': a.source, 'sequence': a.sequence, 'undo': a.undo, 'repair': a.repair, 'narrow': a.narrow, 'seed_base': a.seed_base, 'convention': a.convention}, indent=1, ensure_ascii=False) + '\n')
    print(json.dumps(S, indent=1))


if __name__ == '__main__':
    main()
