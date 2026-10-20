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


if __name__ == '__main__':
    unittest.main(verbosity=1)
