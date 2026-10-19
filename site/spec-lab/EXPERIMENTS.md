# Recorded toy learning experiments

All rule data in this lab is invented code-review guidance. Results quoted from representative data are aggregates only; no case from it appears here.

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
appears verbatim in `toy-spec.json`. The same method applied to representative data
found 155 of 681 clauses open.

## Run program — learned programs, live, with your own endpoint

The Run program tab executes a recorded program (learned B r03, learned A r04 or the seed) on
the selected rule in the browser, through any OpenAI-compatible endpoint the reader enters
(base URL, optional key, writer and judge model; defaults `gpt-6-luna` and `gpt-6.1-sol`).
The URL and key are kept in this browser's `localStorage` (`nlir.endpoint.v1`; the key only
when "Remember" is ticked) and sent only to that endpoint, which must allow cross-origin
requests. Nothing is hardcoded; `verify-spec-lab.py` rejects page scripts containing one.

- Same program, packet and seed replay every model call from the evaluator's cache; "New
  sample" takes the next seed, so its change against seed 0 is the sampling noise.
- Packet edits (remove permissions, spec examples, definitions or scope, or free editing) re-run
  only the calls whose prompts changed; the summary compares their effect with the re-samples.
- "Step through" streams each reduction; every model call is logged with prompt and reply.
- "Judge" runs `judge.nlir` — the same strict clause judge as the recorded experiments, one call
  per part — against `clauses.json` (the authored clauses of the 12 invented rules), and shows
  each clause as present, weakened, missing or contradicted and each written statement as
  supported or extra.
- Word counts, sentence counts and rule-code counts per part are surface statistics, not scores.

`scripts/check-spec-lab-run.js` exercises the whole tab against a mocked endpoint (no network).

### Backward through model steps

Each run card has a Backward panel: edit the run's output and ask which input change would
produce it. This is nlir's lens (`put`) in llm mode: every model step is asked for the
smallest find/replace edit to its own inputs that would give the edited text, those edits
are pushed back through the program's deterministic structure (`++`, `$json`, field access)
to the bound packet, the worked examples or the program's own wording, conflicting edits and
edits that contradict each other are reported, and the program is re-run on the edited
inputs (PutGet, judged for meaning because model steps are not exact inverses). In the
browser this runs as a resumable pass (`putAsync`): the lens runs over the page's cache,
stops where it needs a call, the page makes it, and the lens runs again; calls already made
replay. Example (CR V 1.3, learned B): adding "made by a human reviewer" to the generated
MET text proposed adding "The blocking feedback must have been made by a human reviewer" to
the rule, flagged that this contradicts the rule's "including the assistant's own earlier
comments", and the re-run kept 0.90 of the edited meaning.

### Which instructions matter (program anatomy)

"Instruction sentences" lists every sentence inside the program's long string literals,
grouped by the statement that holds it (the shared context, each field's instruction).
Switch any off and Run; "Sweep sentences" / "Sweep groups" switch each sentence, or each
statement's whole instruction, off in turn (seed 0, spec packet; untouched calls replay) and
rank them by how much the affected parts change in wording and in length, against how much a
plain re-sample changes the same parts. With k re-samples and no real effect, a run exceeds
all k by chance one time in k+1; the table states that expected count. On CR V 1.3 with
learned B and four re-samples: no single sentence of 31 changed wording beyond re-sample
noise (2 changed length; about 6 expected by chance), while whole instructions did (the
decision-boundary instruction: 20 -> 60 words without it; 3 of 6 groups beyond noise, about
1 expected). Concepts sit in whole instructions, and mostly constrain form and length.

### Style: is a run shaped like the authored profile?

Every run shows a style score next to strict F1: per part, length match (min/max words) ×
sentence-count match × 1/(1 + leaks), geometric mean, averaged over the authored parts.
Leaks are things the authored profiles never do: repeating the part's own label, a quote
marker, a rule code, a heading. Once a run is judged, combined = √(strict F1 × style). Style
is deterministic (no model calls) and mirrors the private harness's `style.py`.

### B·clean: fixing shape without touching meaning

`program-b-clean.nlir` is learned B plus a deterministic clean-up of things no authored profile
does — a leading quote marker, the part's own label repeated at its start, rule-code references —
re-capitalised (`verify-spec-lab.py` checks nothing else changed). Its prompts are identical to
B's, so in the Run tab it replays B's model calls and only the final text differs. On representative data the same clean-up improved style by 0.047 [0.039, 0.056] on 20 untouched rules with
no measurable change in meaning (strict F1 −0.002 [−0.008, +0.004]).

### Sweep packet fields

"Sweep packet fields" removes each packet field in turn — the rule text first, as a positive
control that should change a lot, then permissions, definitions, examples and scope — after a
baseline and three re-samples, and adds each to the same influence table, so packet fields and
instructions are read against one noise floor (with three re-samples, a run with no real effect
exceeds all of them one time in four). On representative data the same design found that
the rule text, scope and permissions (for NOT MET) matter while definitions, examples and policy
stay within re-sample noise.

### The selection lottery

Judge three or more samples of one program on the spec packet (after a sweep, or with "New
sample") and the Run tab adds two tables. "Spread across samples" gives strict F1 per part for an
average sample, the most typical sample of each part (`$medoid`) and the best one — an upper
bound that also picks the judge's luck. "Which authored clauses each sample states" lays the
authored clauses against the samples: clauses that every sample states, clauses that only some
state, and clauses none state.

On representative data, with eight drafts per rule on twenty untouched rules, half of the
authored clauses the specification determines were stated by every draft, about two in five by
some drafts and not others, and about one in ten by none; clauses the specification leaves open
were missed by every draft more often. The program can reach most of what the authors wrote, but
which implied points a draft states is close to chance. Picking among drafts (the most typical,
a feature model, a model shown everything the writer saw), merging them by majority, more worked
examples, and even telling the writer which passages the authors built on all failed to change
that: the authors choose among the implications of a passage, not among passages.

### Gap-filled specifications

The Run tab's "Gap-filled specification" panel is the method the private study ended with, on the
invented toy spec. **Extract gap lists** has the judge model read the rule's spec packet and its
authored profile and list, per field, the points the profile makes that the packet implies (named,
not stated) and the requirements it states that the packet does not imply (additions). **Write from
the lists** runs B·clean on the packet plus those lists and then keeps, in each part, only what
states a listed point or addition. **Round trip** extracts the lists again from that written
profile and writes once more. Judge the runs to compare them with the authored profile and with
B·clean from the spec alone.

On representative data, profiles written this way scored 0.581 strict F1 against the
authors' on twenty untouched rules, against 0.386 from the spec alone, at about the authors'
length; the round trip reproduced a written profile as closely as re-running its spec did; and an
independent judge gave the same gain. Lists proposed by a model without the authored profile did
not: the additions — the decisions a spec leaves open — have to come from its authors.

The same method, applied unchanged to this invented spec, generalises. On the 8 rules not used to
train program B (four samples each; writer Luna, lists and strict judge Sol), profiles written from
the spec plus the lists and trimmed score 0.504 strict F1 against the authored profiles, against
0.346 from the spec alone (+0.157 [+0.076, +0.251], higher on 7 of the 8 rules); the combined score
rises by 0.097 [+0.036, +0.165], with a small cost in shape on these very short profiles. The panel
shows this recorded run for each of those rules without an endpoint: the lists and the gap-filled
profile.

Two checks on that result. An independent judge (Opus, re-judging two samples of both arms with the
same judge and clauses) agrees: 0.434 against 0.572, +0.139 [+0.047, +0.223], higher on 7 of 8 rules,
per-profile correlation with Sol 0.83. And it round-trips: against each gap-filled profile's own
clauses, lists read back from it and written again score 0.638, the same spec and lists re-sampled
0.613 (+0.025 [−0.034, +0.104], within the noise), and the spec alone 0.305. The panel shows the
round trip for each rule.

Which half of the lists does the work? The two kinds of item do different jobs. Given only the
additions (requirements the spec cannot imply), the untrimmed writer recalls more of the clauses
the spec leaves open (0.46 against 0.39 from the spec alone) and no more of those it determines;
given only the named points (points the spec implies, singled out), it recalls more of the
determined clauses (0.62 against 0.52) and barely more of the open ones. In F1 the named points
carry most of the gain (0.404 against 0.346, 74% of the full lists' +0.078), while the additions
alone, or written into each rule's text as accepted addenda, gain nothing here: on these very
short profiles their extra recall costs as much precision. On representative data the same split holds, with the additions worth more there (44% of the gain; named points 63%).

Drafts of the same rule still differ, and with the lists in hand a judge can pick among them
without seeing the authored profile: per part, take the draft that states the most listed items
(stated, or half for a weakened one) with the fewest other clauses. Over the four gap-filled drafts
of each rule this raises strict F1 from 0.504 to 0.558 (+0.054 [+0.013, +0.093], higher on 6 of 8
rules; combined +0.043 [+0.010, +0.072]) at slightly fewer words. The panel shows the picked
profile for each rule. With your own endpoint, **Write 3 and pick** runs the same picker live: three gap-filled
drafts, one coverage check per draft by the judge model, and a picked run you can judge like any other. On representative data, picking from four drafts
raised strict F1 from 0.586 to 0.619 on twenty untouched rules, about +0.02 of it confirmed by an independent judge
that also did the picking; picking from eight drafts did no better than from four.
