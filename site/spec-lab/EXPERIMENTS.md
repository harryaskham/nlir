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

## Maintaining authored profiles — the editing loop (`../explain/`, `scripts/edit-loop.py`)

Profiles that authors have already written should change only where a change to the rule reaches.
The loop keeps their prose and puts the decision in the rule model: the author edits their own
sentence; `lens-concepts.nlir` turns the edit into model edits; `patch-route.nlir` computes, from the
two models, which fields read what changed (MET and NOT MET read the behaviour, conditions and
exceptions; UNCERTAIN reads the facts; applicability the testing setting); `patch.nlir` gives only
those fields the smallest consistent edit, telling the patch that a changed condition or exception
governs every way MET can be met; every other field is returned exactly as written.

`scripts/edit-loop.py` runs the whole loop through these programs. On the 8 evaluation rules of the
invented spec, with three author edits per rule proposed by a model and two judges: an added
exception reaches NOT MET 8 times and is excluded from MET 8 times (in the authored profiles:
0 and 1); an added requirement gates MET 8 times and NOT MET covers its failure 8 times; an added deciding
fact reaches UNCERTAIN 8 times and leaves MET and NOT MET as written 6 times — the other two are edits
the backward pass also read as a new condition, which routing then follows. The fields an edit does
not reach keep 94% of the authors' words, and the second judge gives the same counts for coverage,
exclusion and gating. Overlaps between MET and NOT MET that remain are mixed responses (an exception
case beside a separate violation), most of them present before the edit. The explainer shows every
edit as a word diff with its routing drawn as the program's graph, and patches a rule's authored
profile live with your own exception.

The backward pass can over-read an edit: twice it took a sentence added to UNCERTAIN as also adding a
condition, which routing then carried into MET. Typing the backward pass (`lens-typed.nlir`) closes
this by construction — an edit to a field can change only the model groups that field reads, and
any other node edit becomes a warning for the author instead — and leaves MET and NOT MET as written
for all 8 deciding facts (untyped: 6), with the other results unchanged. With Opus writing the
backward passes and the patches instead of Sol, the typed loop gives the same counts under both
judges: every exception covered and excluded, every requirement gating MET, every deciding fact in
UNCERTAIN and nowhere else.
On representative data the same holds for requirements and deciding facts with Opus editing, but 3 of 20
added exceptions came out differently — each because Opus read the author's exception differently (as a
deciding fact, which the typed pass declined; as a narrowed condition; as a carve-out of one sentence), not
because of the routing or the patch. The programs depend little on the editor; the reading of an exception
does.
On fourteen further representative rules not used to design the loop, Opus editing held every edit under
both judges, so its misreadings are 3 of 34 added exceptions. Asking the backward pass once more when every
node edit is declined (`--retry-declined`) fired once: the edit then reached MET and NOT MET, but read as a
condition again, and one judge still found MET not excluding it — so it is offered, not the default.

The change can also start in the specification. `lens-packet.nlir` reads the rule model and the packet
before and after a change and returns the model edits it implies, each quoting the new passage it rests
on; routing and the patch then run as for an author's edit, starting from the profile exactly as the
authors wrote it (`edit-loop.py --source packet`). With the same exceptions and requirements added to
the packets instead — a new permission, or a sentence appended to the rule — every model edit quoted the
new passage (27 of 27), an added permission reached NOT MET 8 times and was excluded from MET
8 times, an added requirement gated MET 8 times, and every field the routing did not reach stayed as
written. A requirement in the specification also tends to bring a deciding fact (whether it holds), so
UNCERTAIN is patched more often than when an author edits MET.

Edits compose. Applied in turn to the same profile — an exception, then a requirement, then a
deciding fact, each starting from the previous step's patched profile and model
(`edit-loop.py --sequence`) — every one of the three still holds at the end under both judges (8 of 8
exceptions covered, 8 of 8 requirements gating MET, 8 of 8 facts in UNCERTAIN), and the final profile keeps
76% of the authors' words after three changes. On representative data an earlier version lapsed twice
in twenty rules: the backward pass read an added requirement as a narrower exception, which undid the
exception added before it. `lens-concepts.nlir` now says so outright — a requirement and an exception
work in opposite directions, so a new requirement is a new or narrowed condition, never an edit of an
exception — and with it every edit held at the end in all twenty rules under both judges, with no
change to single edits.

Removing an exception is not the inverse of adding one — unless the exception was a real one. Much of
what NOT MET lists restates where MET's own conditions already stop (on the invented spec, half the rule
models have no exception node at all); deleting such a sentence changes no verdict, and the backward
pass rightly makes no model edit. On representative data, both judges read only 2 of 20 exceptions in
the authored profiles as genuine carve-outs, and removing those worked. An exception an author has just
added is genuine by construction, so the clean test is undo (`edit-loop.py --undo`): add an exception,
then delete it again. The backward pass read every deletion as removing the node it had added (8 of
8), and the profile came back to the authors' text — 36 of 40 fields byte-identical; on representative
data, 98 of 100.

`lens-redundant.nlir` makes that check before an author edits: for each exception in a rule model it asks
whether the excepted case would count as a violation without it (a carve-out) or already fails one of the
conditions (a restatement of a boundary), and the explainer marks each exception accordingly. On the
invented spec, 4 of its 7 exceptions are carve-outs on both judges' reading. On representative data the picture is
the other way round: of 72 exceptions across 34 rules, both judges read only 6 as carve-outs — most exceptions
a profile states mark where the conditions already stop — and the check agreed with the judges'
earlier readings, made from the authored profile rather than the model, on 31–32 of 34.

The same machinery can propose repairs to the authors' own inconsistencies (`edit-loop.py --repair`,
`patch-repair.nlir`): a consistency check finds a case that meets both MET and NOT MET, or neither, and
the repair places it with the fewest words. On the invented spec it cut the check's overlaps from 6 to
2 and its gaps from 5 to 3 at about 7 words a repair — but a second judge, asked independently,
still found edge cases in nearly every profile and read 6 of 8 repairs as also moving an adjacent case. A
repair settles a class of cases, not one, and which way an adjacent case should go is the authors'
decision; the explainer shows each repair as a proposal with the adjacent case it moves. On
representative data the pattern is the same (15 of 24 repairs moved an adjacent case). Told to move only cases like the flagged one
(`--narrow`), a repair moves fewer neighbours (4 of 8 here) but leaves the class of cases open — the check's
gaps stay at 5 of 5 — and takes about twice the words; on representative data, 3 rather than 15 of 24 repairs moved a
neighbour, and 20 rather than 7 of 21 gaps remained. Settling the class or only the case is the authors'
choice, and the explainer offers both.

Mixed responses — the excepted case beside the behaviour itself, elsewhere in the same response — are one
kind of overlap the judges find, but not the main one. Neither a NOT MET wording nor a convention sentence in
the decision boundary (`--convention`: "judge each instance of the behaviour on its own…") settled them, and
putting the same rule in the judge's procedure instead, with the profiles unchanged, barely moved the
stricter judge (on the invented spec 8 overlaps without it and 7 with it). Classified one by one, half the
overlaps it offers here (4 of 8) — and on representative data most (19 of 27) — are not mixed responses but single
responses the authors' wording leaves open. Whether an exception covers a response or an instance belongs
in the evaluation procedure, settled once; the boundary cases are what any rule written in prose leaves,
and the place for them is a proposal the authors decide.

The consistency question overstates how open a profile is. Asked instead for one verdict under the
profile as written, two judges agree on most of the cases it offered (4 of 8 overlaps and 3 of 7 gaps on the
invented spec; on representative data 21 of 27 and 23 of 31): the profile decides those. The cases they
disagree on are the real questions, and the explainer lists them by rule with both readings — a short
review list for the authors rather than a defect in every profile.

Answering a question settles it (`edit-loop.py --questions`). Each open case was answered both ways — the
author adds "Cases like … are MET" (or NOT MET) to that field and the loop runs as for any edit — and both
judges then gave the author's answer for every one (16 of 16 on the invented spec; on representative data 28 of
28). The author's sentence does most of that by itself (14 of 16 without the loop); what the loop adds is the
other field: it patched the opposite one in 8 of 16 answers so that it no longer says otherwise.

The maintained profiles still read like the authors'. Scored with the series' style score — each part's
length, sentence count and anything no author writes, relative to the authored part (1 = the authors' own
shape) — the invented spec's profiles score 0.92 after an author's edit, 0.89 after a spec change, 0.79
after three edits in turn (each adds a clause) and 1.00 after an edit and its undo. On representative data,
for one definition edit on the same fifteen rules, the patched profile scores 0.89 while the profile
re-derived from the edited model scores 0.74 — and already 0.76 before the edit: re-deriving costs the
authors' shape whatever the edit.

Can a pass after the edits win the authors' shape back? Not without cost (`consolidate.nlir`,
`edit-loop.py --consolidate`; neither version carried). Rewriting whole fields restored the authors'
sentences beside the edited ones — on representative data the profiles grew (330 to 354 words a rule) and
new overlaps appeared. Freezing the authors' sentences and letting the model rewrite only the added ones,
applied by exact replacement, shortened the invented spec's profiles (188 to 170 words, style 0.79 to
0.81) and kept every edit covered, but the stricter judge found new overlaps (exceptions 0 to 3,
requirements 2 to 4). The words an edit adds are doing work: the shape lost after several edits is mostly
the price of what they say.

A maintained profile reads back to the edited model (`edit-loop.py --roundtrip`). Read back through
lens-profile.nlir from the model before the edit, the invented spec's patched profiles gave back the
intended edit in 20 of 24 (on representative data 49 of 60), with as many other edits as reading back the
authors' own, unedited profile (0.5–0.75 a profile against 0.62). The misses still recover a node for the
edit — the right kind with a different scope, or the same content as another kind — so the program and the
prose stay a pair through maintenance.

Most of the other edits are the backward pass finishing its first account, not noise from the patch: read
back from the model it produced, the authored profile gives 0.62 edits, then 0.25, then none
(`--fixpoint`; on representative data 0.50, then none). Settled to that fixed point first, the round trip
is close to exact — the other edits halve (0.67 to 0.38 a profile; on representative data 0.50 to 0.23,
about one recovered edit a profile, the intended one) and the authored profile reads back with none.
Settling is for the check, not the edit: maintaining from the settled model instead (`--anchor` without
`--roundtrip`) gave the same coverage (every edit 8 of 8 under both judges) and words kept (0.93), with one
more overlap in three of the six counts — so it was not carried. In the explainer, every patched profile now
shows what it reads back as: the model edits the prose implies, and whether the intended one is among them.

Two authors at once (`edit-loop.py --merge`). An exception and a requirement, each added by a different
author from the same profile, do not merge as prose: a three-way text merge of the two patched profiles,
sentence by sentence, conflicts in every one of the invented spec's rules (on representative data 18 of
20), because both rewrite MET and NOT MET. Their model edits do merge: applied together, routed, and patched
into the authored profile once, both held in all 8 rules under both judges (on representative data all 20),
with every unrouted field left as written; the stricter judges found a few more overlaps than after either
edit alone (11 against 8 across the four counts; on representative data 5 against 6).

A merge should also refuse edits that really clash (`merge-check.nlir`, `edit-loop.py --conflicts`). For
each rule a second requirement was written to make exactly the excepted case a violation, and the check saw
the base model and both authors' model edits. Its first wording flagged every clash but also many compatible
pairs (on representative data 9 of 20): it read a case that meets both an exception and an unrelated new
requirement as a conflict, though in the model a permission overrides. Stating that — and that only an edit
that explicitly treats the other's case the opposite way contradicts — flagged 7 of the invented spec's 8
clashes and none of its compatible pairs (on representative design rules not used to write it, 13 of 14 and
none of 14); the miss here is a clash the backward pass never turned into a model edit. In the explainer each
merged rule shows the contradicting requirement the check would have sent back to the authors.

Which rules does a specification change touch (`impact.nlir`, `edit-loop.py --impact`)? A definition sits
in the packet of every rule that uses the concept, so a changed definition reaches many rules on paper. On
representative data (six widely shared definitions, each changed once, 85 rule–definition pairs), two
judges who agreed on 81 of the 85 found that about one exposed rule in six needed its profile changed —
from none of 18 for one change to half of 16 for another. Neither deterministic route is enough: rules
whose model uses the defined term are nearly all of them (77, precision about 0.2), while rules whose model
quotes the definition are certain (7 of 7) but only half of those that need a change. Route a definition
change to every rule that includes it and spend one check per rule; patch only those it says need it. (The
invented spec shares too few definitions to show this; `examples/patch.sh` checks the routes offline.)

End to end (`edit-loop.py --impact-apply`): each rule the check selected had the definition replaced in its
packet, `lens-packet.nlir` turned the change into model edits, and only the fields that read them were
patched. At first a quarter of the selected rules on representative data were still out of date: the change
had been recorded as a deciding fact, which reaches UNCERTAIN only, though the term decides MET and NOT MET.
`lens-packet.nlir` now edits the conditions and permissions that use a changed term; on definitions not used
to make that change, 8 of 10 selected rules were brought up to date under both judges, with every field the
routing did not reach left as written.

A maintenance session (`edit-loop.py --session`): four different changes in turn on one profile — an
author's exception, a requirement the specification gains, an author's deciding fact, and the author
undoing the exception — each from the previous step. At the end, on the invented spec, the requirement held
in 8 of 8 rules and the fact in 8 under both judges, overlaps stayed within one of the authors' own, and
every applicability and decision boundary was left as written; on representative data the same, with every
requirement and fact held in all 20. The undo is harder to score: a judge asked whether the excepted case
counts as a violation again said no in about a quarter of the rules — but in nearly all of them because the
case fails a requirement the profile now states (often the one the specification added), so not counting it
is right. A removal check alone cannot score an undo inside a mixed session.
The fair test is counterfactual (`--session --counterfactual`): undoing an exception should leave the
profile as if it had never been added. Run again without the exception steps, the session's final verdict on
the excepted case matched the never-added one in all 8 of the invented spec's rules under both judges (the
two profiles 92% the same words). On representative data the session's verdict was among a judge's own
three readings of the never-added profile in 19 of 20 rules for one judge and 16 of 20 for the other,
whose readings agree with themselves 83% of the time — an undo is close to never having made the edit.

On representative data, the same loop on twenty rules never used to design it carried every added
exception and requirement into MET, every exception into NOT MET, and kept every added deciding fact
out of MET and NOT MET, keeping 95–100% of the other fields' words; patching every field instead,
and trusting the model to leave the rest alone, did worse on each, and an independent judge agreed
once the patch was told an exception governs every way MET can be met.
