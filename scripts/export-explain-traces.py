#!/usr/bin/env python3
"""Export recorded forward and edit passes for the explainer page (site/explain/traces.json).

Usage: export-explain-traces.py PROPAGATION_JSON DATASET12_JSON OUT_JSON

PROPAGATION_JSON holds, per toy rule, sample 0 of three programs (flat, chained and concept-layer
B·clean), the rule model the concept layer extracted, one author exception, and each program's
profile after that edit, with a judge's verdicts. Every prompt is rebuilt exactly: the concept
program's own prompt expressions are evaluated in det mode with the model pinned, so no model call
is made. Prompts are stored as segments by provenance (program text, worked examples, packet, field
instruction, rule model, derivation); the examples and packet JSON are stored once per rule.
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
    doc = {'method': __doc__.split('\n\n')[1].replace('\n', ' '), 'models': {'writer': 'gpt-6-luna', 'exceptions and judge': 'gpt-6.1-sol'},
           'summary': prop['summary'], 'rules': rules}
    out_path.write_text(json.dumps(doc, ensure_ascii=False, separators=(',', ':')))
    print(json.dumps({'rules': len(rules), 'bytes': out_path.stat().st_size}))


if __name__ == '__main__':
    main()
