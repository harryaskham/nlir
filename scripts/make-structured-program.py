#!/usr/bin/env python3
"""Make program-b-structured.nlir from program-b-clean.nlir (deterministic; verify-spec-lab.py re-runs it).

B·structured is B·clean with one shared node: a model call that lists the rule's distinct cases, one
per line, each assigned to exactly one verdict (MET, NOT MET or UNCERTAIN). Deterministic forms read
that list: `of` gives a verdict's own cases, `notof` the other verdicts' cases. Each verdict part is
told its own cases and, as an exclusion set, the others'; the decision-boundary part is told all three
groups. The parts' own instructions and every other call are unchanged. It puts the verdicts' mutual
exclusivity into the program graph.

Usage: make-structured-program.py [--check]
"""
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1] / 'site/spec-lab'
NODE = '''-- B·structured: one shared case list partitioned among MET, NOT MET and UNCERTAIN (each case in
-- exactly one); every verdict part is written from its own cases with the others' as an exclusion set.
cases = =>($context ++ "case list. Do not write a paragraph for this field. List the distinct kinds of response or situation that decide this rule's verdict, at most eight, each a short noun phrase, and assign each to exactly one verdict; no case may belong to two verdicts. Reply with one case per line, each line starting with its verdict and a colon (MET: ..., NOT MET: ..., UNCERTAIN: ...), and nothing else.");
caselines=$filter%({#($trim%$0) > 0}, $cases // "\\n");
of={$join%({$trim%($sub%($0, '^\\s*' ++ $$0 ++ ':\\s*', ''))} ↦ ($filter%({$trim%($sub%($trim%$0, '^' ++ $$0 ++ ':.*$', '')) == ''}, $caselines)), '; ')};
notof={$join%($filter%({#$0 > 0}, {$of%$0} ↦ ($filter%({$0 != $$0}, ['MET', 'NOT MET', 'UNCERTAIN']))), '; ')};

'''
VERDICTS = ['MET', 'NOT MET', 'UNCERTAIN']


def make(clean):
    head, rest = clean.split('\nparts=[', 1)
    body, tail = rest.split('\n];', 1)
    entries = body.split('\n  =>(')[1:]
    if len(entries) != 5:
        raise SystemExit(f'expected five parts, found {len(entries)}')
    out = []
    for i, e in enumerate(entries):
        e = e.rstrip().rstrip(',')
        if not e.endswith('")'):
            raise SystemExit(f'part {i} does not end with a string literal')
        if i == 1:
            e = e[:-1] + ' ++ "\\n\\nMET CASES: " ++ $of%\'MET\' ++ "\\nNOT MET CASES: " ++ $of%\'NOT MET\' ++ "\\nUNCERTAIN CASES: " ++ $of%\'UNCERTAIN\')'
        elif i >= 2:
            v = VERDICTS[i - 2]
            e = e[:-1] + f' ++ "\\n\\nCASES THIS FIELD COVERS: " ++ $of%\'{v}\' ++ "\\nCASES THAT BELONG TO THE OTHER VERDICTS (do not state them, or anything implying them, in this field): " ++ $notof%\'{v}\')'
        out.append('  =>(' + e)
    head = head.replace('-- B·clean: learned program B (r03)', '-- B·structured, made by scripts/make-structured-program.py from B·clean: learned program B (r03)', 1)
    return head + '\n' + NODE + 'parts=[\n' + ',\n'.join(out) + '\n];' + tail


def main():
    made = make((ROOT / 'program-b-clean.nlir').read_text())
    target = ROOT / 'program-b-structured.nlir'
    if '--check' in sys.argv:
        if not target.exists() or target.read_text() != made:
            raise SystemExit('program-b-structured.nlir is not make-structured-program.py applied to program-b-clean.nlir')
        print('program-b-structured.nlir: B·clean plus the shared case partition, nothing else changed')
        return
    target.write_text(made)
    print('wrote', target)


if __name__ == '__main__':
    main()
