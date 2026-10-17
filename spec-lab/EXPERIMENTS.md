# Recorded toy learning experiments

All rule data in this lab is invented code-review guidance, not health experiment data.

- `trace.json`: historical twelve-proposal v2 run, Sol holistic-similarity judge.
  Held-out similarity 0.673. Its archived 0.975 paraphrase baseline used Sonnet;
  that baseline is not a certified ceiling or a matched-judge comparison.
- `trace-strict-a.json`: four proposals, writer receives no worked profiles.
  Validation-selected r04; mean held-out reference-clause F1 0.312551.
- `trace-strict-b.json`: four proposals, writer receives two worked profiles.
  Validation-selected r03; mean held-out reference-clause F1 0.361081.

Both strict searches used the configured `gpt-6-luna` writer and Sol editor/judges.
They retain that model label; these recordings were not regenerated for a later model.
Both editors saw training references, and rule packets retained their own policy examples.
The train/validation/test split was 4/4/4 rules, with two final sample slots per test rule.
Both complete final cohorts have zero execution failures.

A/B are separately learned programs, not a fixed-program causal ablation. Averaging
samples within each rule gives B−A = 0.048529, with descriptive 95% rule-bootstrap
interval [−0.024081, 0.101768] (four rules, 10,000 resamples, seed 3271). This interval
does not include uncertainty over independent searches, providers or judges.

The generic seed scored zero because its output did not satisfy the required layout;
this is not evidence that it contained no relevant meaning. Strict clause F1 and
holistic similarity are different metrics and must not be compared as interchangeable
scores. Historical sample slots also lack complete successful-retry seed receipts.

The JSON contains replayed programs, reviewer readings, graphs and measurements; the
browser does not invoke a model to reproduce them. `scripts/verify-spec-lab.py` checks
recording labels and basic consistency; `scripts/check-spec-lab-ui.js` tests the UI in
an isolated Playwright CLI session, including the stale-fetch race guard.

## Spec limits — the counterexample test (`witness.json`)

For every clause of the 12 invented authored profiles (101 clauses), gpt-6.1-sol, given only
that rule's spec packet and blind to earlier labels, either quoted spec text that determines
the clause or wrote a counter-choice: a different requirement for the same part that
contradicts no spec text and would change some verdict. claude-opus-5.5 checked each quote
and counter-choice. 52 of 101 clauses have a confirmed counter-choice, so the spec leaves
them open; 39 are determined by quoted spec text. As a control, 0 of the 18 clauses earlier
labelled "stated" and 4 of 25 labelled "implied" were shown open, against 48 of 58 labelled
convention or rule-specific. These are model judgements, not formal proofs; failing to find
a counter-choice does not prove a clause is implied. `scripts/export-toy-witness.py` builds
the file from recorded results; `scripts/verify-spec-lab.py` checks that every quotation
appears verbatim in `toy-spec.json`. The same method applied to the private health policy
found 155 of 681 clauses open.
