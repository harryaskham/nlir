#!/usr/bin/env python3
"""Export recorded forward and edit passes for the explainer page (site/explain/traces.json).

Usage: export-explain-traces.py PROPAGATION_JSON DATASET12_JSON OUT_JSON [BACKWARD_JSON CHECK_JSON NEGATION_DIR]

PROPAGATION_JSON holds, per toy rule, sample 0 of three programs (flat, chained and concept-layer
B·clean), the rule model the concept layer extracted, one author exception, and each program's
profile after that edit, with a judge's verdicts. Every prompt is rebuilt exactly: the concept
program's own prompt expressions are evaluated in det mode with the model pinned, so no model call
is made. Prompts are stored as segments by provenance (program text, worked examples, packet, field
instruction, rule model, derivation); the examples and packet JSON are stored once per rule.
BACKWARD_JSON adds, per rule, the same exception made as a sentence edit to MET and pushed back to rule-model
edits (lens-concepts.nlir), the re-derived profile and the judge's verdict; CHECK_JSON the consistency check
(lens-check.nlir) after it; NEGATION_DIR one rule's MET reversed, pushed back, re-derived and checked.
Invented toy data only: refuses any rule outside `CR V`.
"""
import json
import os
import re
import subprocess
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
NLIR = os.environ.get('NLIR', 'nlir')
PARTS = ['APPLICABILITY', 'DECISION BOUNDARY', 'MET', 'NOT MET', 'UNCERTAIN']
NAMES = ['app', 'db', 'met', 'notmet', 'unc']
strip = lambda s: '\n'.join(l for l in s.split('\n') if not l.strip().startswith('--'))


def prompt_program(examples_path, packet_path):
    """The concept program with its final expression replaced by its prompts (model pinned via the packet)."""
    lib = strip((ROOT / 'site/spec-lab/profile.nlir').read_text()).strip().rstrip(';')
    src = strip((ROOT / 'site/spec-lab/program-b-concepts.nlir').read_text()).strip()
    head = src[:src.index('\nparts=')]
    exprs = {}
    for line in head.split('\n'):
        m = re.match(r'^(\w+)=\$if%\(\$has%\(\$pin, \'[^\']+\'\), \$get%\(\$pin, \'[^\']+\'\), \$parse%\(=>\((.*)\)\)\);$', line) \
            or re.match(r'^(\w+)=\$if%\(\$has%\(\$pin, \'[^\']+\'\), \$get%\(\$pin, \'[^\']+\'\), =>\((.*)\)\);$', line)
        if m:
            exprs[m.group(1)] = m.group(2)
    assert set(exprs) == {'model', *NAMES}, exprs.keys()
    body = ', '.join(f'{k}=({v})' for k, v in exprs.items())
    return lib + ';\n' + head + f'\n$json%{{{body}}}'


def prompts(packet, model, examples, work):
    work.mkdir(parents=True, exist_ok=True)
    (work / 'p.json').write_text(json.dumps(packet | {'_pin': {'model': model}}))
    (work / 'ex.json').write_text(json.dumps(examples))
    (work / 'prompts.nlir').write_text(prompt_program(work / 'ex.json', work / 'p.json'))
    p = subprocess.run([NLIR, '--config', str(ROOT / 'config.example.yaml'), '--mode', 'det', '--quiet', '--bind', f"p={work / 'p.json'}",
                        '--bind', f"examples={work / 'ex.json'}", '-f', str(work / 'prompts.nlir')], capture_output=True, text=True, timeout=120)
    if p.returncode:
        raise SystemExit(p.stderr[-400:])
    return json.loads(p.stdout)


def segments(prompt, shared):
    """Split a prompt into provenance segments; the examples and packet JSON become references."""
    out = []
    a = prompt.index('BOUND WORKED EXAMPLES:\n') + len('BOUND WORKED EXAMPLES:\n')
    b = prompt.index('\n\nRULE PACKET:\n')
    c = b + len('\n\nRULE PACKET:\n')
    d = prompt.index('\n\nFIELD:\n')
    e = d + len('\n\nFIELD:\n')
    assert prompt[a:b] == shared['examples'] and prompt[c:d] == shared['packet'], 'shared prompt parts differ'
    out += [{'kind': 'program', 'text': prompt[:a]}, {'kind': 'examples', 'ref': 'examples'}, {'kind': 'program', 'text': prompt[b:c]},
            {'kind': 'packet', 'ref': 'packet'}, {'kind': 'program', 'text': prompt[d:e]}]
    rest = prompt[e:]
    if '\n\nRULE MODEL' in rest:
        f = rest.index('\n\nRULE MODEL')
        g = rest.index(':\n', f) + 2
        h = rest.rindex('\n')
        out += [{'kind': 'field', 'text': rest[:f]}, {'kind': 'program', 'text': rest[f:g]}, {'kind': 'model', 'text': rest[g:h]}, {'kind': 'derive', 'text': rest[h:]}]
    else:
        out += [{'kind': 'field', 'text': rest}]
    return out


def main():
    prop_path, dataset_path, out_path = map(Path, sys.argv[1:4])
    back = json.loads(Path(sys.argv[4]).read_text()) if len(sys.argv) > 4 else None
    check = json.loads(Path(sys.argv[5]).read_text()) if len(sys.argv) > 5 else None
    neg_dir = Path(sys.argv[6]) if len(sys.argv) > 6 else None
    prop = json.loads(prop_path.read_text())
    data = {d['id']: d for d in json.loads(dataset_path.read_text())}
    examples = [{'packet': data[r]['packet'], 'profile': data[r]['gold']} for r in ('CR V 1.1', 'CR V 1.4')]
    work = ROOT / 'target/explain-export'
    rules = []
    for rid in prop['rules']:
        if not rid.startswith('CR V'):
            raise SystemExit(f'refusing non-toy rule {rid}')
        R = prop['results'][rid]
        packet = data[rid]['packet']
        base = prompts(packet, R['model'], examples, work / 'base')
        edited_model = json.loads(json.dumps(R['model']))
        edited_model.setdefault('permissions', []).append({'id': f"p{len(R['model'].get('permissions', [])) + 1}", 'text': R['exception'][0].upper() + R['exception'][1:] + '.', 'source': '(added by the author)'})
        edit = prompts(packet, edited_model, examples, work / 'edit')
        shared = {'examples': json.dumps(examples, ensure_ascii=False, separators=(',', ':')), 'packet': json.dumps(packet, ensure_ascii=False, separators=(',', ':'))}
        # nlir's $json is compact; take the shared parts from the prompt itself and check them.
        mp = base['model']
        shared = {'examples': mp[mp.index('BOUND WORKED EXAMPLES:\n') + 23:mp.index('\n\nRULE PACKET:\n')],
                  'packet': mp[mp.index('\n\nRULE PACKET:\n') + 15:mp.index('\n\nFIELD:\n')]}
        steps = lambda P, parts, model: [{'id': 'model', 'label': 'Extract the rule model', 'segments': segments(P['model'], shared), 'response': json.dumps(model, ensure_ascii=False, indent=1)}] + [
            {'id': part, 'label': part.title() if part != 'NOT MET' else 'NOT MET', 'segments': segments(P[n], shared), 'response': parts[part]} for part, n in zip(PARTS, NAMES)]
        rules.append({'id': rid, 'title': packet.get('title', ''), 'packet': packet, 'shared': shared, 'exception': R['exception'],
                      'concepts': {'model': R['model'], 'parts': R['base']['concepts'], 'steps': steps(base, R['base']['concepts'], R['model'])},
                      'concepts_edited': {'model': edited_model, 'parts': R['edited']['concepts'], 'steps': steps(edit, R['edited']['concepts'], edited_model)[1:],
                                          'verdict': R['verdicts']['concepts']},
                      'chained': {'parts': R['base']['chained'], 'edited': R['edited']['chained'], 'verdict': R['verdicts']['chained']},
                      'flat': {'parts': R['base']['clean'], 'edited': R['edited']['clean'], 'verdict': R['verdicts']['clean']}})
        if back:
            Bk = back['results'][rid]
            rules[-1]['sentence'] = {'old': Bk['edit']['old'], 'new': Bk['edit']['new'], 'edits': Bk['back'].get('edits', []), 'why': Bk['back'].get('why', ''),
                                     'model': Bk['model'], 'parts': Bk['profile'], 'verdict': Bk['verdict'],
                                     'check': (check or {}).get('results', {}).get(f'exception {rid}')}
        if neg_dir and rid == 'CR V 1.3':
            import re as _re
            md = (neg_dir / 'forward.md').read_text()
            def _parts(md):
                out = {}
                a = _re.search(r'#### `applicability`\n\n((?:> .*\n?)+)', md); out['APPLICABILITY'] = _re.sub(r'^> ?', '', a.group(1), flags=_re.M).strip() if a else ''
                for l in ('Decision boundary', 'MET', 'NOT MET', 'UNCERTAIN'):
                    m = _re.search(r'> ' + l + r':\n((?:> .*\n?)+)', md); out[l.upper()] = _re.sub(r'^> ?', '', m.group(1), flags=_re.M).strip() if m else ''
                return out
            nb = json.loads((neg_dir / 'back.json').read_text())
            pin = json.loads((neg_dir / 'p-pin.json').read_text())['_pin']['model']
            rules[-1]['negation'] = {'old': json.loads((neg_dir / 'old.json').read_text()), 'new': json.loads((neg_dir / 'new.json').read_text()),
                                     'edits': nb.get('edits', []), 'why': nb.get('why', ''), 'model': pin, 'parts': _parts(md),
                                     'check': (check or {}).get('results', {}).get('negation CR V 1.3')}
    doc = {'method': 'Every prompt is rebuilt exactly from the program and the recorded rule model; the parts, node edits and checks are recorded outputs, not re-run here.', 'models': {'writer': 'gpt-6-luna', 'exceptions and judge': 'gpt-6.1-sol'},
           'summary': prop['summary'], 'rules': rules}
    out_path.write_text(json.dumps(doc, ensure_ascii=False, separators=(',', ':')))
    print(json.dumps({'rules': len(rules), 'bytes': out_path.stat().st_size}))


if __name__ == '__main__':
    main()
