#!/usr/bin/env python3
"""Hermetic tests for the editing loop's deterministic parts (scripts/edit-loop.py, export-explain-patches.py): no model calls."""
import importlib.util, json, subprocess, sys, tempfile, unittest
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]


def load(name, file):
    spec = importlib.util.spec_from_file_location(name, ROOT / 'scripts' / file); m = importlib.util.module_from_spec(spec); spec.loader.exec_module(m); return m


EL = load('edit_loop', 'edit-loop.py')
EX = load('export_patches', 'export-explain-patches.py')
MODEL = {'action': 'approving a pull request', 'conditions': [{'id': 'c1', 'text': 'Not every file was opened.'}],
         'permissions': [{'id': 'p1', 'text': 'A generated lockfile.'}], 'facts': [{'id': 'f1', 'text': 'Whether every file was opened.'}]}
GOLD = {'applicability': ['Reviews of pull requests.'], 'decision_boundary': ['Decision boundary: Did the reviewer read it?', 'MET: Approves unread files.', 'NOT MET: Reads every file.', 'UNCERTAIN: Whether files were read.']}


class Apply(unittest.TestCase):
    def test_add_edit_remove(self):
        m = EL.apply(MODEL, [{'op': 'add', 'group': 'permissions', 'text': 'A senior reviewer approved.', 'source': ''},
                             {'op': 'edit', 'group': 'conditions', 'id': 'c1', 'text': 'Not every source file was opened.', 'source': 'the rule'},
                             {'op': 'remove', 'group': 'facts', 'id': 'f1'}])
        self.assertEqual([p['id'] for p in m['permissions']], ['p1', 'p2'])
        self.assertEqual(m['permissions'][1]['source'], '(not in the packet)')
        self.assertEqual(m['conditions'][0]['text'], 'Not every source file was opened.')
        self.assertEqual(m['facts'], [])
        self.assertEqual(MODEL['facts'][0]['id'], 'f1', 'apply must not mutate its input')

    def test_action_and_new_group(self):
        m = EL.apply(MODEL, [{'op': 'edit', 'group': 'action', 'text': 'merging a pull request'}, {'op': 'add', 'group': 'setting', 'text': 'Multi-file reviews.'}])
        self.assertEqual(m['action'], 'merging a pull request'); self.assertEqual(m['setting'][0]['id'], 's1')


class Fields(unittest.TestCase):
    def test_part(self):
        self.assertEqual(EL.part(GOLD, 'APPLICABILITY'), 'Reviews of pull requests.')
        self.assertEqual(EL.part(GOLD, 'NOT MET'), 'Reads every file.')
        self.assertEqual(EL.part(GOLD, 'MISSING'), '')

    def test_author_edits_compose(self):
        r = EL.Runner.__new__(EL.Runner)
        prof = {l: EL.part(GOLD, l) for l in EL.LABELS}
        f1, met1 = r.author_new('exception', prof, 'the files are generated')
        self.assertEqual((f1, met1), ('MET', 'Approves unread files, unless the files are generated.'))
        prof['MET'] = met1
        f2, met2 = r.author_new('requirement', prof, 'the change alters behaviour')
        self.assertTrue(met2.startswith(met1.rstrip('.')) and met2.endswith(', and only when the change alters behaviour.'))
        f3, unc = r.author_new('fact', prof, 'whether the diff was collapsed')
        self.assertEqual(f3, 'UNCERTAIN'); self.assertTrue(unc.endswith('can leave the verdict undecided when unclear.'))


def run(kind_after, part='MET'):
    auth = {l: EL.part(GOLD, l) for l in EL.LABELS}
    patched = dict(auth); patched[part] = auth[part] + ' Patched.'
    return {'text': 't', 'part': part, 'author_edit': auth[part] + ' x', 'model_edits': [], 'warnings': [], 'routing': {'changed': ['permissions'], 'route': ['MET', 'NOT MET']},
            'patched': patched, 'before': {}, 'after': kind_after, 'before2': {}, 'after2': kind_after}


class Summaries(unittest.TestCase):
    def results(self):
        auth = {l: EL.part(GOLD, l) for l in EL.LABELS}
        return {'CR V 9.1': {'title': 't', 'authored': auth, 'edits': {'exception': run({'not_met_covers': True, 'met_excludes': True, 'overlap': False}),
                                                                       'requirement': run({'met_requires': True, 'not_met_covers': True, 'overlap': True}),
                                                                       'fact': run({'uncertain_names': True}, 'UNCERTAIN')}}}

    def test_summary(self):
        S = EL.summary(self.results(), 'opus')
        self.assertEqual(S['exception']['not_met_covers'], {'before': 0, 'after': 1, 'before2': 0, 'after2': 1})
        self.assertEqual(S['fact']['verdict_untouched'], 1)
        self.assertEqual(S['exception']['other_unchanged'], 4)

    def test_export(self):
        P = {'summary': EL.summary(self.results(), 'opus'), 'results': self.results(), 'models': {'editor': 'e', 'judge': 'j', 'judge2': 'k'}, 'typed': True}
        with tempfile.TemporaryDirectory() as d:
            run_f, tr = Path(d) / 'run.json', Path(d) / 'traces.json'
            run_f.write_text(json.dumps(P)); tr.write_text(json.dumps({'rules': []}))
            subprocess.run([sys.executable, str(ROOT / 'scripts/export-explain-patches.py'), str(run_f), str(tr)], check=True, capture_output=True)
            doc = json.loads(tr.read_text())
        self.assertEqual(set(doc['patches']['sets']), {'exception', 'requirement', 'fact'})
        r = doc['patches']['sets']['exception']['rules']['CR V 9.1']
        self.assertEqual(r['route'], ['MET', 'NOT MET']); self.assertEqual(r['fields']['MET']['after'], 'Approves unread files. Patched.')

    def test_tidy(self):
        self.assertEqual(EX.tidy('MET', 'MET: Approves unread files.)', 'Approves unread files.'), 'Approves unread files.')
        self.assertEqual(EX.tidy('MET', 'Approves (after a skim) files.', 'Approves files.'), 'Approves (after a skim) files.')


class MoreSummaries(unittest.TestCase):
    def prof(self, **over):
        auth = {l: EL.part(GOLD, l) for l in EL.LABELS}; auth.update(over); return auth

    def test_sequence(self):
        auth = self.prof()
        step = lambda k, ok: {'kind': k, 'text': 't', 'part': 'MET', 'model_edits': [], 'warnings': [], 'routing': {'changed': [], 'route': []}, 'profile': auth,
                              'at_step': {q: ok for q in EL.QUESTIONS[k]}}
        fin = lambda k, ok: {'before': {}, 'after': {q: ok for q in EL.QUESTIONS[k]}, 'before2': {}, 'after2': {q: ok for q in EL.QUESTIONS[k]}}
        R = {'CR V 9.1': {'authored': auth, 'final_profile': auth, 'steps': [step(k, True) for k in ('exception', 'requirement', 'fact')],
                          'final': {'exception': fin('exception', False), 'requirement': fin('requirement', True), 'fact': fin('fact', True)}}}
        S = EL.summary_sequence(R, 'opus')
        self.assertEqual(S['exception']['not_met_covers'], {'at_step': 1, 'final': 0, 'before': 0, 'final2': 0, 'before2': 0})
        self.assertEqual(S['final_profile']['untouched'], 5); self.assertEqual(S['final_profile']['similarity'], 1.0)

    def test_undo_and_invalid(self):
        auth = self.prof()
        R = {'CR V 9.1': {'authored': auth, 'added_node': True, 'removed_node': True, 'after_add': {'not_met_covers': True, 'met_excludes': True}, 'after_undo': {'met_covers': True},
                          'after_add2': {'not_met_covers': True}, 'after_undo2': {}, 'final_similarity_to_authored': 1.0, 'final_untouched': 5},
             'CR V 9.2': {'authored': auth, 'added_node': True, 'invalid': True}}
        S = EL.summary_undo(R, 'opus')
        self.assertEqual((S['rules'], S['valid'], S['removed_node'], S['final_untouched']), (2, 1, 1, 5))

    def test_repair(self):
        a = self.prof(); b = self.prof(MET='Approves unread files outside generated code.')
        R = {'CR V 9.1': {'authored': a, 'repaired': True, 'profile': b, 'check_before': {'overlap': True}, 'check_after': {'overlap': False}, 'indep_before': {'gap': True}, 'indep_after': {'gap': True}, 'collateral': {'collateral': True}},
             'CR V 9.2': {'authored': a, 'repaired': False, 'check_before': {}, 'indep_before': {}}}
        S = EL.summary_repair(R)
        self.assertEqual((S['flagged'], S['collateral'], S['untouched']), (1, 1, 4))
        self.assertEqual(S['check']['overlap'], {'before': 1, 'after': 0}); self.assertEqual(S['independent']['gap'], {'before': 1, 'after': 1})


class TextMerge(unittest.TestCase):
    def test_edits_to_different_sentences_combine_and_same_sentence_conflicts(self):
        base = 'One thing. Two things. Three things.'
        ok = EL.text_merge(base, 'One thing, unless x. Two things. Three things.', 'One thing. Two things. Three things, only if y.')
        self.assertEqual(ok['conflicts'], 0)
        self.assertIn('unless x', ok['merged']); self.assertIn('only if y', ok['merged'])
        bad = EL.text_merge(base, 'One thing, unless x. Two things. Three things.', 'One thing only if y. Two things. Three things.')
        self.assertGreater(bad['conflicts'], 0)


FAKE_NLIR = "#!/usr/bin/env python3\n# A fake nlir for scripts/test_edit_loop.py: answers each program or prompt the editing loop sends with canned JSON\n# that is consistent with itself (a patch marks the fields it touches; judges read those marks), so every harness mode\n# runs end to end without a model.\nimport json, sys\nargs = sys.argv[1:]; binds = {}; files = []; expr = None; i = 0\nwhile i < len(args):\n    if args[i] == '--bind': k, v = args[i + 1].split('=', 1); binds[k] = json.loads(open(v).read()); i += 2\n    elif args[i] == '-f': files.append(args[i + 1].rsplit('/', 1)[-1]); i += 2\n    elif args[i] == '-e': expr = args[i + 1]; i += 2\n    elif args[i] in ('--model', '--config', '--cache-file', '--seed'): i += 2\n    else: i += 1\nout = lambda x: print(json.dumps(x))\nif files == ['lens-profile.nlir']: out({'edits': []})\nelif files == ['lens-concepts.nlir']:\n    new, part = binds['new'], binds['part']\n    group = 'facts' if part == 'UNCERTAIN' else 'permissions' if 'unless' in new.rsplit(',', 1)[-1] else 'conditions'\n    out({'edits': [{'op': 'add', 'group': group, 'text': new[-80:], 'source': ''}]})\nelif 'lens-typed.nlir' in files: out({'kept': binds['edits'], 'dropped': []})\nelif 'patch.nlir' in files:\n    p = dict(binds['profile']); p['MET'] += ' (patched)'; p['NOT MET'] += ' (patched)'; out(p)\nelif files == ['patch-route.nlir']: out({'changed': ['permissions'], 'route': ['MET', 'NOT MET']})\nelif files == ['lens-packet.nlir']: out({'edits': [{'op': 'edit', 'group': 'conditions', 'id': 'c1', 'text': 'Not every file was opened, as now defined.', 'source': 'x'}]})\nelif files == ['merge-check.nlir']: out({'conflict': 'even when' in json.dumps(binds['b']).lower(), 'case': 'c', 'why': 'w'})\nelif files == ['impact.nlir']: out({'term': True, 'quoted': False})\nelif files == ['consolidate.nlir']: out(binds['profile'])\nelif files == ['spec-propose.nlir']: out({'passages': [{'where': 'permissions' if any(e.get('group') == 'permissions' for e in binds['edits']) else 'rule', 'title': 't', 'text': 'Proposed passage.'}]})\nelif expr and 'q' in binds:\n    q = binds['q']['q']\n    if q.startswith('A policy evaluation rule'): out({'exception': 'the files are generated', 'requirement': 'the change alters behaviour', 'fact': 'whether the diff was collapsed'})\n    elif q.startswith('You check an evaluation profile for a policy rule after'): out({k: True for k in ('not_met_covers', 'met_excludes', 'met_requires', 'uncertain_names', 'met_covers', 'not_met_drops')} | {'overlap': False})\n    elif q.startswith('Below are an evaluation profile for a policy rule and one CASE'): out({'verdict': 'NOT MET' if 'are NOT MET.' in q else 'MET' if 'are MET.' in q else 'UNCERTAIN'})\n    elif q.startswith('Below are an evaluation profile for a policy rule and an EXCEPTION'): out({'requirement': 'even when the excepted case applies'})\n    elif q.startswith('Below is a DEFINITION'): out({'text': 'A file produced by a tool, including lockfiles.', 'change': 'widened to lockfiles'})\n    elif q.startswith('A policy specification changed one DEFINITION'): out({'needs_change': '(patched)' not in q})\n    elif q.startswith('Below are an INTENDED edit'): out({'recovered': True, 'other': 0})\n    elif q.startswith('Summarise the CASE'): out({'phrase': 'a lockfile-only change'})\n    elif q.startswith('An author will delete one EXCEPTION'): out({'span': q.rsplit('NOT MET: ', 1)[-1].strip().split('. ')[-1].strip()})\n    else: out({})\nelse: out({})\n"


class Modes(unittest.TestCase):
    """Every harness mode end to end against a fake nlir (canned, self-consistent answers): the plumbing, not the models."""
    @classmethod
    def setUpClass(cls):
        cls.tmp = tempfile.TemporaryDirectory(); d = Path(cls.tmp.name)
        fake = d / 'nlir'; fake.write_text(FAKE_NLIR); fake.chmod(0o755)
        item = {'id': 'CR V 9.1', 'gold': GOLD, 'packet': {'id': 'CR V 9.1', 'title': 'Approving unread changes', 'rule': 'Approving without reading every file.',
                'definitions': [{'id': 'D-9', 'title': 'Generated file', 'text': 'A file produced by a tool.'}]}}
        (d / 'data.json').write_text(json.dumps([item])); (d / 'models.json').write_text(json.dumps({'CR V 9.1': MODEL}))
        cls.d, cls.env = d, dict(__import__('os').environ, NLIR=str(fake))

    @classmethod
    def tearDownClass(cls):
        cls.tmp.cleanup()

    def run_mode(self, name, *extra):
        out = self.d / f'{name}.json'
        r = subprocess.run([sys.executable, str(ROOT / 'scripts/edit-loop.py'), '--data', str(self.d / 'data.json'), '--models', str(self.d / 'models.json'),
                            '--cache', str(self.d / 'cache.jsonl'), '--judge', 'sol', '--judge2', 'opus', '--out', str(out), *extra], capture_output=True, text=True, env=self.env, timeout=300)
        self.assertEqual(r.returncode, 0, r.stderr[-600:])
        return json.loads(out.read_text())

    def test_all_modes(self):
        A = self.run_mode('author', '--typed')
        self.assertEqual(A['summary']['exception']['not_met_covers']['after'], 1)
        author = str(self.d / 'author.json')
        M = self.run_mode('merge', '--merge', author)['summary']
        self.assertEqual(M['exception']['not_met_covers']['after']['merged'], 1); self.assertIn('rules_with_conflict', M['text_merge'])
        C = self.run_mode('conflicts', '--conflicts', author)['summary']
        self.assertEqual((C['conflicts_detected'], C['compatible_flagged']), (1, 0))
        F = self.run_mode('fixpoint', '--fixpoint', author)['summary']
        self.assertEqual(F['reached'], 1)
        T = self.run_mode('roundtrip', '--roundtrip', author, '--anchor', str(self.d / 'fixpoint.json'))['summary']
        self.assertEqual(T['exception']['recovered'], 1)
        I = self.run_mode('impact', '--impact', 'D-9', '--impact-models', author)['summary']
        self.assertEqual((I['exposed_pairs'], I['judge']['needs_change']), (1, 1))
        P = self.run_mode('impact-apply', '--impact-apply', str(self.d / 'impact.json'), '--impact-models', author)['summary']
        self.assertEqual((P['selected'], P['settled_both']), (1, 1))
        (self.d / 'open.json').write_text(json.dumps({'rows': [{'rule': 'CR V 9.1', 'case': 'A lockfile-only change approved unread.', 'open': True}]}))
        Q = self.run_mode('questions', '--questions', str(self.d / 'open.json'))['summary']
        self.assertEqual((Q['answers'], Q['settled_both']), (2, 2))
        B = self.run_mode('specback', '--specback', author)['summary']
        self.assertEqual((B['exception']['recovered'], B['requirement']['recovered'], B['exception']['no_passage']), (1, 1, 0))
        S = self.run_mode('session', '--typed', '--session')['summary']
        self.assertEqual((S['undone_located'], S['judge1']['requirement_holds'], S['judge1']['fact_named']), (1, 1, 1))
        self.assertEqual(S['untouched'], {'APPLICABILITY': 1, 'DECISION BOUNDARY': 1})
        self.run_mode('sequence', '--typed', '--sequence')
        K = self.run_mode('consolidate', '--consolidate', str(self.d / 'sequence.json'))['summary']
        self.assertEqual(K['exception']['not_met_covers']['after']['consolidated'], 1)


if __name__ == '__main__':
    unittest.main(verbosity=1)
