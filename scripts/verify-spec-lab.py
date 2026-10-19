#!/usr/bin/env python3
"""Check recorded public toy experiments: metric labels, splits, numeric values and SVGs."""
import json
import math
from pathlib import Path
import xml.etree.ElementTree as ET

ROOT=Path(__file__).resolve().parents[1]/'site/spec-lab'


def check(name, mode, profiles=None):
    trace=json.loads((ROOT/name).read_text())
    actual=trace.get('judge_mode','similarity')
    if actual!=mode:raise ValueError(f'{name}: unexpected judge mode {actual}')
    if mode=='strict':
        if trace.get('metric')!='reference-clause F1':raise ValueError('strict trace has wrong metric')
        if trace.get('writer_profiles')!=profiles:raise ValueError('wrong writer-profile condition')
        if trace.get('ceiling'):raise ValueError('do not label an unrelated paraphrase baseline a strict ceiling')
        pair=trace.get('comparison',{})
        if not pair.get('complete'):raise ValueError('missing complete A/B comparison')
        rows=pair['per_rule'];delta=pair['B_minus_A']
        if len(rows)!=4 or delta['rules']!=4:raise ValueError('wrong comparison cohort')
        if abs(sum(r['B']-r['A'] for r in rows)/len(rows)-delta['mean'])>1e-12:raise ValueError('comparison mean mismatch')
        if not delta['lower']<=delta['mean']<=delta['upper']:raise ValueError('bad comparison interval')
        if trace['models'].get('generation_version')!='gpt-6-luna':raise ValueError('do not relabel archived model versions')
    ids=trace['train_ids']+trace['test_ids']
    if not all(i.startswith('CR ') for i in ids):raise ValueError('public lab must contain invented CR rule IDs only')
    if set(trace['train_ids']) & set(trace['test_ids']):raise ValueError('overlapping splits')
    if not trace['rounds']:raise ValueError('no replay rounds')
    for r in trace['rounds']:
        if not r['program']:raise ValueError('missing program')
        if not math.isfinite(r['score']):raise ValueError('invalid selection score')
        for k in ('train','val','quality'):
            if r.get(k) is not None and not 0<=r[k]<=1:raise ValueError(f'invalid {k}')
        if r.get('graph'):
            tree=ET.fromstring(r['graph'])
            if any(n.tag.rsplit('}',1)[-1]=='script' for n in tree.iter()):raise ValueError('active script in graph')
    for group in trace['held_out'].values():
        if not 0<=group['mean']<=1:raise ValueError('invalid held-out score')
    print(f"{name}: {mode}, {len(trace['rounds'])-1} proposals, held-out {trace['held_out']['best']['mean']:.3f}")


VERDICTS={'determined','partly determined','witnessed open','open, witness rejected','derivation rejected','unverifiable'}


def check_gapfill(name='gapfill.json'):
    """The recorded gap-filled run: toy rules only, summary consistent with the per-rule means."""
    import statistics
    doc=json.loads((ROOT/name).read_text())
    rules=doc['rules']
    assert rules and all(r['id'].startswith('CR V') for r in rules), 'gapfill.json: non-toy rule'
    for k in ('spec','gapfill')+(('selected',) if 'selected' in doc['summary'] else ()):
        m=statistics.fmean(r[k]['f1'] for r in rules)
        assert abs(m-doc['summary'][k])<1e-9, f'gapfill.json: {k} summary {doc["summary"][k]} != {m}'
    assert doc['summary']['better']==sum(r['gapfill']['f1']>r['spec']['f1'] for r in rules), 'gapfill.json: better count'
    if 'roundtrip' in doc['summary']:
        for k in ('floor','trip','spec'):
            m=statistics.fmean(r['roundtrip'][k] for r in rules)
            assert abs(m-doc['summary']['roundtrip'][k])<1e-9, f'gapfill.json: round-trip {k} summary'
    text=(ROOT/name).read_text()
    for bad in ('ts.net','helsinki','sk-','Bearer ','HI V'):
        assert bad not in text, f'gapfill.json: forbidden string {bad!r}'
    print(f"gapfill.json: {len(rules)} toy rules; strict F1 {doc['summary']['spec']:.3f} from the spec alone, {doc['summary']['gapfill']:.3f} gap-filled")


def check_witness(name='witness.json'):
    """Recorded counterexample test on the invented spec: toy IDs only, complete rules,
    citations quote the toy spec verbatim, open clauses carry a counter-choice."""
    doc=json.loads((ROOT/name).read_text())
    spec=json.loads((ROOT/'toy-spec.json').read_text())
    def strings(v):
        if isinstance(v,dict):
            for x in v.values():yield from strings(x)
        elif isinstance(v,list):
            for x in v:yield from strings(x)
        elif isinstance(v,str):yield v
    corpus='\n'.join(strings(spec))
    ids=[r['id'] for r in doc['rules']]
    if len(ids)!=12 or len(set(ids))!=12 or not all(i.startswith('CR V') for i in ids):raise ValueError('witness: expected the 12 invented CR rules')
    table={}
    for r in doc['rules']:
        for c in r['clauses']:
            if c['final'] not in VERDICTS:raise ValueError(f"witness: unknown verdict {c['final']}")
            if c['final']=='witnessed open' and not (c.get('counter_choice') or '').strip():raise ValueError('witness: open clause without counter-choice')
            for q in c.get('citations') or []:
                if q['quote'] not in corpus:raise ValueError(f"witness: quote not in toy spec: {q['quote'][:60]}")
            table.setdefault(c['origin'],{}).setdefault(c['final'],0)
            table[c['origin']][c['final']]+=1
    if table!=doc['by_origin']:raise ValueError('witness: summary table differs from rows')
    total=sum(len(r['clauses']) for r in doc['rules']);opened=sum(c['final']=='witnessed open' for r in doc['rules'] for c in r['clauses'])
    print(f"{name}: 12 rules, {total} clauses, {opened} confirmed open; citations quote the toy spec")


PARTS=['APPLICABILITY','DECISION BOUNDARY','MET','NOT MET','UNCERTAIN']


def check_run_assets():
    """Run tab: the toy clauses the browser judge scores against, the judge program itself, and
    no endpoint or key baked into the page (readers bring their own)."""
    clauses=json.loads((ROOT/'clauses.json').read_text())
    if sorted(clauses)!=sorted(f'CR V {a}.{b}' for a,b in [(1,1),(1,2),(1,3),(1,4),(2,1),(2,2),(2,3),(3,1),(3,2),(3,3),(4,1),(4,2)]):
        raise ValueError('clauses.json: expected exactly the 12 invented CR rules')
    for rule,parts in clauses.items():
        if sorted(parts)!=sorted(PARTS):raise ValueError(f'clauses.json: {rule} parts {sorted(parts)}')
        if not all(isinstance(c,str) and c.strip() for v in parts.values() for c in v) or not all(parts.values()):
            raise ValueError(f'clauses.json: {rule} has an empty part or clause')
    judge=(ROOT/'judge.nlir').read_text()
    for need in ('recall=($0.present + 0.5 * $0.weakened) / $0.n','precision=$if%($0.statements > 0, $0.supported / $0.statements, 0)','score=$fold%({$0 + $1.f1}, $out, 0) / #$out'):
        if need not in judge:raise ValueError(f'judge.nlir no longer computes the published metric: {need}')
    import re
    for f in ROOT.glob('*.js'):
        text=f.read_text()
        if re.search(r'ts\.net|helsinki|sk-[A-Za-z0-9]{8,}|Bearer [A-Za-z0-9]{8,}',text):raise ValueError(f'{f.name}: hardcoded endpoint or key')
    n=sum(len(v) for parts in clauses.values() for v in parts.values())
    print(f'run assets: 12 rules, {n} authored clauses; judge formula intact; no endpoint or key in page scripts')


def check_b_clean():
    """program-b-clean.nlir must be exactly learned B (the accepted strict-B round) plus the
    clean-up forms wrapped around its five part texts — nothing else may change."""
    trace = json.loads((ROOT / 'trace-strict-b.json').read_text())
    accepted = [r for r in trace['rounds'] if r['accepted']]
    src = accepted[-1]['program']
    clean = (ROOT / 'program-b-clean.nlir').read_text()
    body = clean.split('\n\n', 1)[1] if '\n\n' in clean else clean
    expected = src
    for i in range(5):
        expected = expected.replace(f'$trim%$parts.{i}', f'$cap%($clean%($trim%$parts.{i}))')
    if body.strip() != expected.strip():
        raise ValueError('program-b-clean.nlir is not learned B plus the clean-up')
    if 'clean={' not in clean or 'cap={' not in clean:
        raise ValueError('program-b-clean.nlir lacks the clean-up forms')
    print('program-b-clean.nlir: learned B r0%d plus the clean-up, nothing else changed' % accepted[-1]['round'])


def check_explain_traces():
    """The explainer's recorded passes: toy rules only, no endpoint or private-domain strings."""
    import re
    f=ROOT.parent/'explain'/'traces.json'
    doc=json.loads(f.read_text())
    assert doc['rules'] and all(r['id'].startswith('CR V') for r in doc['rules']), 'explain/traces.json: non-toy rule'
    text=f.read_text()
    for pat in (r'ts\.net', r'helsinki', r'\bsk-[A-Za-z0-9]', r'Bearer ', r'health\s+polic', r'clinician', r'\bHI V\b', r'Copilot Health'):
        assert not re.search(pat,text,re.I), f'explain/traces.json: forbidden pattern {pat!r}'
    for r in doc['rules']:
        assert [s['id'] for s in r['concepts']['steps']]==['model','APPLICABILITY','DECISION BOUNDARY','MET','NOT MET','UNCERTAIN'], r['id']
    print(f"explain/traces.json: {len(doc['rules'])} toy rules; every pass has the model step and five parts")


def check_no_private_domain():
    """Results from representative data may be quoted as aggregates; the domain, its authors and its cases may not."""
    import re
    for name in ('EXPERIMENTS.md','run.js','spec-lab.js','index.html'):
        f=ROOT/name
        if not f.exists():
            continue
        text=f.read_text()
        for pat in (r'health\s+polic', r'clinician', r'\bHI V\b', r'Copilot Health'):
            m=re.search(pat,text,re.I)
            assert not m, f'{name}: names the private domain ({m.group(0)!r})'
    print('no private-domain names in the notes or page scripts')


if __name__=='__main__':
    check('trace.json','similarity')
    check('trace-strict-a.json','strict',0)
    check('trace-strict-b.json','strict',2)
    if (ROOT/'witness.json').exists():check_witness()
    if (ROOT/'gapfill.json').exists():check_gapfill()
    check_run_assets()
    check_no_private_domain()
    if (ROOT.parent/'explain'/'traces.json').exists():check_explain_traces()
    check_b_clean()
